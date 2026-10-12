import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/local_auth_service.dart';
import '../database/local_data_service.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../models/user_status.dart';
import 'secure_storage_service.dart';
import 'sync_service.dart';

final authServiceProvider = Provider<LocalFirstAuthService>((ref) {
  return LocalFirstAuthService(
    ref.read(localDataServiceProvider),
    ref.read(localAuthServiceProvider),
    ref.read(syncServiceProvider),
    ref.read(secureStorageServiceProvider),
  );
});

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

/// PIN-first authentication for an offline-first app.
///
/// Login resolves against the device database, so it works with the radio off.
/// When no local hash exists for the typed PIN (fresh install, wiped storage,
/// or a PIN rotated on another device) the login falls back to
/// `login_with_pin`, which verifies the PIN server side and mints a session.
/// When a session is needed for sync, the flow is:
///
///   1. [authenticatePin] verifies the PIN against a local bcrypt hash.
///   2. If a Supabase session already exists (or can be obtained online), reuse
///      it so the device can sync.
///   3. Otherwise the PIN is exchanged for a session via `login_with_pin`,
///      which compares it server side and returns a one-time secret for GoTrue's
///      normal password grant.
///
/// The plaintext PIN is never written to disk in either path.
class LocalFirstAuthService {
  LocalFirstAuthService(
    this._data,
    this._localAuth,
    this._sync,
    this._secureStorage,
  );

  final LocalDataService _data;
  final LocalAuthService _localAuth;
  final SyncService _sync;
  final SecureStorageService _secureStorage;

  User? get supabaseUser => Supabase.instance.client.auth.currentUser;

  bool get hasOnlineSession => supabaseUser != null;

  Future<void> init() => _secureStorage.init();

  /// [LocalAuthService.pinLength] owns the rule; this is re-exported so the
  /// auth screens have a single import to reach.
  static const int pinLength = LocalAuthService.pinLength;

  static String normalizePin(String pin) => LocalAuthService.normalizePin(pin);

  static bool isValidPin(String pin) => LocalAuthService.isValidPin(pin);

  /// Verifies a PIN on-device and returns the matching depot user.
  ///
  /// Returns null when no local hash matches; callers surface a generic
  /// message so the response does not reveal whether the account exists.
  Future<UserModel?> authenticatePin(String pin) async {
    final normalized = normalizePin(pin);
    if (!isValidPin(normalized)) return null;

    final user = await _localAuth.authenticatePin(normalized);
    if (user == null) return null;

    if (user.status != UserStatus.active) return null;

    await _secureStorage.saveRole(user.role.value);
    await _secureStorage.cacheUser(user);
    return user;
  }

  /// Best-effort session acquisition. Never throws: an offline login is a
  /// complete success on its own, it just cannot sync yet.
  Future<void> tryEstablishSession(String pin) async {
    try {
      if (hasOnlineSession) return;

      final result = await Supabase.instance.client.rpc(
        'login_with_pin',
        params: {'p_pin': normalizePin(pin)},
      );

      if (result is! Map) return;
      final email = result['email'] as String?;
      final secret = result['secret'] as String?;
      if (email == null || secret == null) return;

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: secret,
      );
      _sync.scheduleSync();
    } catch (_) {
      // Offline or throttled. The local session stands on its own.
    }
  }

  /// Online PIN login for a device that has nothing to compare against
  /// locally (fresh install, wiped storage, or a PIN rotated on another
  /// device). Returns the depot user, or null when the PIN is rejected, the
  /// device is offline, or the server cannot be reached.
  ///
  /// The successful path is also a sync: it pulls the `users` collection so
  /// this device has the matching offline hash cached for future radio-off
  /// logins.
  Future<UserModel?> tryOnlinePinLogin(String pin) async {
    try {
      final result = await Supabase.instance.client.rpc(
        'login_with_pin',
        params: {'p_pin': normalizePin(pin)},
      );
      debugPrint('[auth] online PIN login: response=$result');
      if (result is! Map) return null;
      final email = result['email'] as String?;
      final secret = result['secret'] as String?;
      if (email == null || secret == null) return null;

      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: secret,
      );

      // Bring the depot users into this device's local database so the session
      // works offline and the caller can resolve the profile.
      await _sync.pullCollection('users');

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;
      final user = await _loadProfile(userId);
      if (user != null) {
        await _secureStorage.saveRole(user.role.value);
        await _secureStorage.cacheUser(user);
        // Hash the PIN the server just accepted with the device's own bcrypt,
        // so this device can verify it offline from here on even when the
        // account carries no synced offline hash.
        await _localAuth.storeCredentialHash(
          userId: user.id,
          hash: LocalAuthService.hashPin(pin),
          role: user.role,
        );
      }
      debugPrint('[auth] online PIN login: user=${user?.id}');
      _sync.scheduleSync();
      return user;
    } catch (e) {
      debugPrint('[auth] online PIN login failed: $e');
      return null;
    }
  }

  /// True when the local database holds at least one cached PIN hash, so a
  /// local miss is meaningful rather than the fallback doing the judging.
  Future<bool> hasLocalCredentials() => _localAuth.hasAnyCredential();

  /// True when the shared-device wrong-PIN throttle is engaged.
  Future<bool> isDeviceLockedOut() => _localAuth.isDeviceLockedOut();

  Future<UserModel?> _loadProfile(String userId) async {
    // Local database first: it is the source of truth and works offline.
    final local = await _localAuth.loadUser(userId);
    if (local != null) return local;

    // Never return a *different* cached user: a driver whose profile has not
    // synced yet must not be signed in as the previous driver on this device.
    final cached = await _secureStorage.getCachedUser();
    if (cached != null && cached.id == userId) return cached;

    // Not known on this device yet (the classic fresh-install case). A session
    // should exist by the time this runs, so pull the users collection and try
    // again. On failure the caller falls back to the cached user, preserving
    // offline behavior.
    try {
      await _sync.pullCollection('users');
      return await _localAuth.loadUser(userId);
    } catch (_) {
      return null;
    }
  }

  /// Creates an account and caches its PIN on this device.
  ///
  /// Two RPCs cover the two situations:
  ///
  ///   * No session yet (a brand-new device, no installed account): the first
  ///     user is bootstrapped as the `superadmin` via `admin_bootstrap`, which
  ///     refuses to run once any admin exists. This is the online-only first
  ///     run.
  ///   * An admin session exists: `admin_create_user` adds any staff account.
  ///     [depotId] is only consulted for unrestricted callers; a depot admin's
  ///     staff are always bound to that admin's own depot by the server.
  ///
  /// The PIN is hashed twice by design — pgcrypto on the server for online PIN
  /// login, Dart bcrypt on the device for offline use. The Dart hash is stored
  /// and synced so any depot device can verify the PIN without connectivity.
  Future<UserModel?> registerWithPin({
    required String email,
    required String name,
    required String pin,
    required UserRole role,
    String phone = '',
    String? depotId,
  }) async {
    final normalized = normalizePin(pin);
    if (!isValidPin(normalized)) {
      throw AuthFailure('Le code PIN doit contenir $pinLength chiffres.');
    }

    final offlineHash = LocalAuthService.hashPin(normalized);
    final firstRun = !hasOnlineSession;

    Map<String, dynamic>? result;
    try {
      if (firstRun && role == UserRole.superadmin) {
        result = await Supabase.instance.client.rpc('admin_bootstrap', params: {
          'p_email': email.trim(),
          'p_name': name.trim(),
          'p_pin': normalized,
        });
      } else {
        result = await Supabase.instance.client.rpc('admin_create_user', params: {
          'p_email': email.trim(),
          'p_name': name.trim(),
          'p_pin': normalized,
          'p_role': role.value,
          'p_phone': phone.trim(),
          'p_data': <String, dynamic>{},
          'p_offline_pin_hash': offlineHash,
          'p_depot_id': depotId,
        });
      }
    } on PostgrestException catch (e) {
      throw AuthFailure(_mapAuthMessage(e.message));
    } on AuthException catch (e) {
      throw AuthFailure(_mapAuthMessage(e.message));
    }

    final id = result?['id'] as String?;
    if (id == null) {
      throw AuthFailure('Échec de la création du compte.');
    }

    // Only the bootstrap signs this device in: the new account's session secret
    // is the one way to become an admin. Adding a staff member while an admin is
    // signed in must not hijack that session.
    if (firstRun) {
      final secret = result!['secret'] as String?;
      if (secret != null && result['email'] != null) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: result['email'] as String,
          password: secret,
        );
      }
    }

    final user = UserModel(
      id: id,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role,
      status: UserStatus.active,
      depotId: depotId,
    );

    // The offline hash travels in the synced user document so every device picks
    // it up on the next pull; the plaintext PIN never does. `pinCode` is
    // stripped so a payload can never leak it, even if a future caller forgets.
    await _data.createDocument(
      'users',
      {
        ...user.toMap()..remove('pinCode'),
        'offlinePinHash': offlineHash,
      },
      docId: id,
    );
    await _localAuth.storeCredentialHash(
      userId: id,
      hash: offlineHash,
      role: role,
    );
    await _secureStorage.cacheUser(user);
    _sync.scheduleSync();

    return user;
  }

  /// Assigns a PIN to a user and caches it on this device so they can log in
  /// without a connection. The synced document is updated with the offline hash
  /// so other devices pick it up on their next pull.
  Future<void> setDriverPin(String userId, String pin) async {
    final normalized = normalizePin(pin);
    if (!isValidPin(normalized)) {
      throw AuthFailure('Le code PIN doit contenir $pinLength chiffres.');
    }

    final offlineHash = LocalAuthService.hashPin(normalized);

    await Supabase.instance.client.rpc(
      'admin_set_pin',
      params: {
        'p_user_id': userId,
        'p_pin': normalized,
        'p_offline_pin_hash': offlineHash,
      },
    );

    final user = await _localAuth.loadUser(userId);
    await _data.updateDocument('users', userId, {
      'offlinePinHash': offlineHash,
    });
    await _localAuth.storeCredentialHash(
      userId: userId,
      hash: offlineHash,
      role: user?.role ?? UserRole.driver,
    );
  }

  /// Re-hashes a locally known user's PIN after an online login, so a device
  /// that signed in with email/password can later accept that user's PIN.
  Future<void> cachePinForUser(UserModel user, String pin) async {
    final offlineHash = LocalAuthService.hashPin(normalizePin(pin));
    await _data.updateDocument('users', user.id, {
      'offlinePinHash': offlineHash,
    });
    await _localAuth.storeCredentialHash(
      userId: user.id,
      hash: offlineHash,
      role: user.role,
    );
  }

  Future<bool> isAuthenticated() async {
    if (supabaseUser != null) return true;
    return await _secureStorage.getCachedUser() != null;
  }

  Future<UserModel?> restoreSession() async {
    if (supabaseUser != null) {
      final user = await _loadProfile(supabaseUser!.id);
      if (user != null) return user;
    }
    return _secureStorage.getCachedUser();
  }

  Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
    await _secureStorage.clearAll();
    await _secureStorage.clearCachedUser();
  }

  /// Wipes cached PIN hashes. Called on logout so a shared device does not keep
  /// every depot user's PIN.
  Future<void> forgetDeviceCredentials() => _localAuth.clearAll();

  Future<void> updateUserData(String uid, Map<String, dynamic> data) =>
      _data.updateDocument('users', uid, data);

  Future<UserModel?> getCachedUser() => _secureStorage.getCachedUser();

  Future<String?> getStoredRole() => _secureStorage.getRole();

  Future<void> cacheUser(UserModel user) => _secureStorage.cacheUser(user);

  static String _mapAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('admin_already_exists')) {
      return 'Un administrateur existe déjà. Connectez-vous avec son compte.';
    }
    if (lower.contains('admin_only') || lower.contains('not_a_depot_user')) {
      return "Action réservée à l'administrateur.";
    }
    if (lower.contains('forbidden')) {
      return 'Action non autorisée.';
    }
    if (lower.contains('invalid_pin_format')) {
      return 'Le code PIN doit contenir $pinLength chiffres.';
    }
    if (lower.contains('too_many_attempts')) {
      return 'Trop de tentatives incorrectes. Réessayez dans 15 minutes.';
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'Cet email est déjà utilisé.';
    }
    if (lower.contains('invalid login credentials')) {
      return 'Identifiants invalides.';
    }
    return message;
  }
}

/// Auth errors that already carry a user-facing French message.
class AuthFailure implements Exception {
  AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}