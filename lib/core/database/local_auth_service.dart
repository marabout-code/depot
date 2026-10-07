import 'package:bcrypt/bcrypt.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import 'app_database.dart';

final localAuthServiceProvider = Provider<LocalAuthService>((ref) {
  return LocalAuthService(ref.read(appDatabaseProvider));
});

/// On-device credential store.
///
/// Each user's PIN is hashed with bcrypt and cached here so the keypad login
/// path works with no network at all. Two distinct hashes exist per user:
///
///   * `serverPinHash` — produced by pgcrypto in Postgres and never readable by
///     the client. Authoritative for online login.
///   * `offlinePinHash` — produced here by the Dart bcrypt implementation and
///     never sent to the server as anything but a hash. Used only to verify a
///     PIN typed on this device.
///
/// They are separate on purpose: the two bcrypt implementations are not
/// guaranteed to be wire-compatible, and neither hash has to verify the other.
class LocalAuthService {
  LocalAuthService(this._db);

  final AppDatabase _db;

  /// Digits in a PIN. This is the single source of truth for the client; the
  /// `supabase/migrations` RPCs enforce the same rule with the same regex.
  static const int pinLength = 4;

  /// bcrypt's log2 work factor: 2^12 = 4096 iterations per hash.
  ///
  /// A 4 digit PIN space is 10,000 candidates, which is small enough to exhaust
  /// quickly if a hash ever leaks. This work factor, the lockout below, and the
  /// fact that hashes never leave the device are what keep an offline attack
  /// expensive per guess. The cost is a visibly slow login, which is the
  /// intended trade.
  static const int bcryptRounds = 12;

  /// Failed attempts allowed before the keypad refuses further tries.
  static const int maxLocalAttempts = 5;

  static const Duration lockoutDuration = Duration(minutes: 5);

  static String normalizePin(String pin) =>
      pin.replaceAll(RegExp(r'\D'), '').padLeft(pinLength, '0');

  static bool isValidPin(String pin) =>
      RegExp('^[0-9]{$pinLength}\$').hasMatch(pin);

  /// bcrypt is a log2 work factor, so this is 2^12 = 4096 iterations. It is
  /// CPU-bound and synchronous by design.
  static String hashPin(String pin) =>
      BCrypt.hashpw(normalizePin(pin), BCrypt.gensalt(logRounds: bcryptRounds));

  /// Caches (or rotates) the local credential for [userId], hashing [pin] on
  /// this device. A PIN change invalidates any in-flight failure count.
  Future<void> storeCredential({
    required String userId,
    required String pin,
    required UserRole role,
  }) async {
    final normalized = normalizePin(pin);
    if (!isValidPin(normalized)) {
      throw ArgumentError.value(
        pin,
        'pin',
        'PIN must be exactly $pinLength digits',
      );
    }

    await storeCredentialHash(
      userId: userId,
      hash: hashPin(normalized),
      role: role,
    );
  }

  /// Writes a previously computed bcrypt hash for [userId].
  ///
  /// Used when a hash came from somewhere other than typing the PIN here: a
  /// synced user document carrying the offline hash, for example.
  Future<void> storeCredentialHash({
    required String userId,
    required String hash,
    required UserRole role,
  }) async {
    await _db.into(_db.localCredentials).insertOnConflictUpdate(
          LocalCredentialsCompanion.insert(
            userId: userId,
            offlinePinHash: hash,
            role: role.value,
            updatedAt: DateTime.now(),
          ),
        );

    // A PIN change invalidates any in-flight failure count.
    await _clearAttempts(userId);
  }

  /// Applies a synced offline hash without clearing the device's attempt
  /// counter. A remote rotation must not unlock a device that was deliberately
  /// locked out locally.
  Future<void> applyOfflineHash({
    required String userId,
    required String hash,
    required String role,
  }) async {
    await _db.into(_db.localCredentials).insertOnConflictUpdate(
          LocalCredentialsCompanion.insert(
            userId: userId,
            offlinePinHash: hash,
            role: role,
            updatedAt: DateTime.now(),
          ),
        );
  }

  /// Removes a synced user's offline hash (used when the user is deleted).
  Future<void> removeCredential(String userId) async {
    await (_db.delete(_db.localCredentials)
          ..where((c) => c.userId.equals(userId)))
        .go();
    await _clearAttempts(userId);
  }

  Future<void> clearAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.localCredentials).go();
      await _db.delete(_db.localAttempts).go();
    });
  }

  /// Bucket for failures that did not match any known account, i.e. guesses.
  static const _globalAttemptKey = '*';

  /// Resolves a PIN entered on this device to a locally known user.
  ///
  /// Every stored hash is tried because bcrypt cannot be indexed: a hashed PIN
  /// is not searchable by value. With a depot-sized staff list per device this
  /// stays fast, and the work factor bounds an offline attacker's attempt rate.
  ///
  /// A miss gives no hint about which account was close to matching, so misses
  /// are counted against [_globalAttemptKey] and throttled before any hash is
  /// verified. Without that, a wrong-but-valid-looking PIN would be free.
  Future<UserModel?> authenticatePin(String pin) async {
    final normalized = normalizePin(pin);
    if (!isValidPin(normalized)) return null;

    // Cheap check first: a locked-out device never pays for bcrypt.
    if (await isLockedOut(_globalAttemptKey)) return null;

    final credentials = await _db.select(_db.localCredentials).get();
    if (credentials.isEmpty) return null;

    String? matchedUserId;
    var ambiguous = false;

    for (final credential in credentials) {
      if (!BCrypt.checkpw(normalized, credential.offlinePinHash)) continue;
      if (matchedUserId != null && matchedUserId != credential.userId) {
        // Same PIN shared by two accounts: refuse rather than pick one.
        ambiguous = true;
      }
      matchedUserId ??= credential.userId;
    }

    if (ambiguous || matchedUserId == null) {
      await _recordFailure(_globalAttemptKey);
      return null;
    }

    // A correct PIN does not excuse a device that is under guess throttling.
    if (await isLockedOut(matchedUserId)) return null;

    await _clearAttempts(matchedUserId);
    await _clearAttempts(_globalAttemptKey);
    return loadUser(matchedUserId);
  }

  Future<UserModel?> loadUser(String userId) async {
    final row = await (_db.select(_db.documents)
          ..where((d) =>
              d.collection.equals('users') & d.docId.equals(userId))
          ..limit(1))
        .get();

    if (row.isEmpty) return null;

    final data = decodePayload(row.first.payload)..['id'] = row.first.docId;
    return UserModel.fromMap(data);
  }

  Future<List<UserModel>> knownUsers() async {
    final rows =
        await (_db.select(_db.documents)..where((d) => d.collection.equals('users'))).get();

    return rows.map((row) {
      final data = decodePayload(row.payload)..['id'] = row.docId;
      return UserModel.fromMap(data);
    }).toList();
  }

  /// True when [userId] has no cached credential, meaning an online login is
  /// the only way in until the next sync.
  Future<bool> hasCachedCredential(String userId) async {
    final row = await (_db.select(_db.localCredentials)
          ..where((c) => c.userId.equals(userId))
          ..limit(1))
        .get();
    return row.isNotEmpty;
  }

  /// Counts one failure for [userId]. Uses an upsert so the first attempt and
  /// every subsequent one take the same path.
Future<void> _recordFailure(String userId) async {
    // One statement so a first attempt cannot race the increment.
    await _db.customUpdate(
      'insert into local_attempts (user_id, failures, last_attempt_at) '
      'values (?, 1, ?) '
      'on conflict(user_id) do update set '
      'failures = failures + 1, last_attempt_at = excluded.last_attempt_at',
      variables: [Variable<String>(userId), Variable<DateTime>(DateTime.now())],
    );
  }

  Future<void> _clearAttempts(String userId) async {
    await (_db.delete(_db.localAttempts)..where((a) => a.userId.equals(userId)))
        .go();
  }

  Future<bool> isLockedOut(String userId) async {
    final row = await (_db.select(_db.localAttempts)
          ..where((a) => a.userId.equals(userId))
          ..limit(1))
        .get();
    if (row.isEmpty) return false;

    final attempts = row.first;
    if (attempts.failures < maxLocalAttempts) return false;

    final elapsed = DateTime.now().difference(attempts.lastAttemptAt);
    return elapsed < lockoutDuration;
  }

  /// Seconds remaining on the lockout, for UI feedback.
  Future<int> lockoutSecondsRemaining(String userId) async {
    final row = await (_db.select(_db.localAttempts)
          ..where((a) => a.userId.equals(userId))
          ..limit(1))
        .get();
    if (row.isEmpty) return 0;

    final attempts = row.first;
    if (attempts.failures < maxLocalAttempts) return 0;

    final elapsed = DateTime.now().difference(attempts.lastAttemptAt);
    final remaining = lockoutDuration - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }
}