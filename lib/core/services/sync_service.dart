import 'dart:async';
import 'dart:io' show SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';
import '../database/app_database.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    ref.read(appDatabaseProvider),
    ref.read(connectivityProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Overridable so tests can drive connectivity without the platform channel.
final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  return ref.read(syncServiceProvider).statusStream;
});

/// Where sync currently stands, surfaced in the settings screen.
class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.online = true,
    this.lastSyncedAt,
    this.pendingWrites = 0,
    this.lastError,
    this.clearError = false,
  });

  final bool running;
  final bool online;
  final DateTime? lastSyncedAt;
  final int pendingWrites;
  final String? lastError;

  /// Set by copyWith to clear a previous error, since `null` cannot be
  /// distinguished from "leave unchanged" with a nullable field alone.
  final bool clearError;

  bool get hasPendingWork => pendingWrites > 0;

  SyncStatus copyWith({
    bool? running,
    bool? online,
    DateTime? lastSyncedAt,
    int? pendingWrites,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncStatus(
      running: running ?? this.running,
      online: online ?? this.online,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      pendingWrites: pendingWrites ?? this.pendingWrites,
      lastError: clearError ? null : (lastError ?? this.lastError),
      clearError: false,
    );
  }
}

/// Pushes local changes to Supabase and pulls other devices' changes back.
///
/// SQLite on the device is the source of truth; this class only reconciles it
/// with the shared depot database. Everything the app shows comes from the
/// local database, so sync failing never blocks a user.
///
/// Conflict resolution is last-write-wins on a monotonic per-row `version`
/// counter, with wall clock as the tiebreaker. Two devices therefore converge
/// on a single order, and the highest version wins. Field-level merge is
/// deliberately not attempted: a half-merged order is worse than a clean
/// last-writer-wins, and depot edits are rarely simultaneous enough to
/// justify a CRDT.
class SyncService {
  SyncService(this._db, this._connectivity);

  final AppDatabase _db;
  final Connectivity _connectivity;

  /// A single RPC may not answer for a long time on a flaky link. Bounding it
  /// keeps one stalled request from pinning [_running] and freezing every later
  /// sync attempt.
  static const Duration rpcTimeout = Duration(seconds: 20);

  /// Heartbeat that pushes/pulls even when no connectivity change, realtime
  /// event or local write has happened, so a device that was offline (or whose
  /// realtime socket silently died) still converges.
  static const Duration pollInterval = Duration(seconds: 45);

  static const Duration minRetryDelay = Duration(seconds: 5);
  static const Duration maxRetryDelay = Duration(minutes: 5);

  /// Pull cursors are set from the server's `updatedAt`, then rewound by this
  /// much, so two rows sharing a timestamp, sub-second truncation or a skipped
  /// boundary cannot drop a change. Re-pulled rows are idempotent.
  static const Duration cursorOverlap = Duration(seconds: 2);

  final _controller = StreamController<SyncStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;
  Timer? _pollTimer;
  Timer? _retryTimer;
  int _consecutiveFailures = 0;
  bool _running = false;
  SyncStatus _status = const SyncStatus();

  Stream<SyncStatus> get statusStream async* {
    yield _status;
    yield* _controller.stream;
  }

  /// Starts listening for connectivity changes and runs a first pass.
  Future<void> init() async {
    await _refreshPendingCount();

    if (SupabaseConfig.isPlaceholder) {
      _emit(_status.copyWith(online: false));
      return;
    }

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      final wasOnline = _status.online;
      _emit(_status.copyWith(online: online));
      if (online && !wasOnline) {
        // Network returned: sync right away rather than waiting for the
        // debounce, so pending writes reach the server as soon as possible.
        unawaited(syncNow());
      } else if (online) {
        scheduleSync();
      }
    });

    _subscribeRealtime();
    _startPeriodicSync();

    await syncNow();
  }

  /// Repeatedly attempts a pass so a missed connectivity event, a dead realtime
  /// socket or a failed push eventually recovers on its own. `syncNow` is a
  /// no-op while one is already running or when the project is unconfigured.
  void _startPeriodicSync() {
    _pollTimer ??= Timer.periodic(pollInterval, (_) {
      if (!_running) unawaited(syncNow());
    });
  }

  /// Listens for other devices' writes to `sync_documents` so this device can
  /// catch up immediately instead of waiting for its next poll. The event
  /// carries no data we trust: it only triggers a normal sync pass, which pulls
  /// whatever the caller is allowed to read under RLS.
  void _subscribeRealtime() {
    if (SupabaseConfig.isPlaceholder) return;
    try {
      _realtimeChannel = Supabase.instance.client
          .channel('sync_documents_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'sync_documents',
            callback: (_) => scheduleSync(),
          )
          .subscribe();
    } catch (_) {
      // Realtime unavailable (e.g. publication not enabled): polling still
      // keeps devices converged, just with more latency.
    }
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty &&
      !results.every((r) => r == ConnectivityResult.none);

  /// Coalesces bursts of writes into a single sync pass.
  void scheduleSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 3), () {
      unawaited(syncNow());
    });
  }

  Future<void> syncNow() async {
    if (_running || SupabaseConfig.isPlaceholder) return;

    if (!_isOnline(await _connectivity.checkConnectivity())) {
      _emit(_status.copyWith(online: false));
      return;
    }

    _running = true;
    _emit(_status.copyWith(running: true, online: true));

    try {
      await _pushLocalChanges();
      await _pullRemoteChanges();
      final now = DateTime.now();
      _consecutiveFailures = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
      _emit(_status.copyWith(
        running: false,
        online: true,
        lastSyncedAt: now,
        clearError: true,
      ));
    } on SocketException {
      _emit(_status.copyWith(running: false, online: false));
      _scheduleRetry();
    } on TimeoutException {
      _emit(_status.copyWith(
        running: false,
        lastError: 'La connexion est trop lente. Nouvelle tentative...',
      ));
      _scheduleRetry();
    } on AuthException {
      // A dead session needs a re-login, not a retry storm.
      _emit(_status.copyWith(
        running: false,
        lastError: 'Session expirée. Reconnectez-vous pour synchroniser.',
      ));
    } on PostgrestException catch (e) {
      _emit(_status.copyWith(running: false, lastError: e.message));
      _scheduleRetry();
    } catch (e) {
      _emit(_status.copyWith(running: false, lastError: e.toString()));
      _scheduleRetry();
    } finally {
      _running = false;
      await _refreshPendingCount();
    }
  }

  /// Retries after an exponentially growing delay (capped), so a device on a
  /// flaky link backs off instead of hammering the server.
  void _scheduleRetry() {
    _consecutiveFailures++;
    final delay = retryDelay(_consecutiveFailures);
    if (delay == Duration.zero) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_running) unawaited(syncNow());
    });
  }

  /// Backoff for the [failures]-th consecutive failure: 5s, 10s, 20s ... up to
  /// [maxRetryDelay]. Exposed as a static so it can be unit tested.
  static Duration retryDelay(int failures) {
    if (failures <= 0) return Duration.zero;
    final exponent = (failures - 1).clamp(0, 10);
    final ms = minRetryDelay.inMilliseconds * (1 << exponent);
    return Duration(
      milliseconds: ms.clamp(
        minRetryDelay.inMilliseconds,
        maxRetryDelay.inMilliseconds,
      ),
    );
  }

  /// The cursor for the next pull: the newest server `updatedAt` seen, rewound
  /// by [cursorOverlap]. The client clock is deliberately never used here — a
  /// device whose clock runs ahead must not skip changes. With nothing pulled,
  /// the existing cursor is kept, forcing a full pull next time.
  static DateTime? nextPullCursor(
    DateTime? current,
    Iterable<DateTime> remoteUpdatedAts,
  ) {
    DateTime? maxSeen;
    for (final t in remoteUpdatedAts) {
      if (maxSeen == null || t.isAfter(maxSeen)) maxSeen = t;
    }
    if (maxSeen == null) return current;
    final candidate = maxSeen.subtract(cursorOverlap);
    if (current != null && !candidate.isAfter(current)) return current;
    return candidate;
  }

  /// Uploads rows this device changed.
  ///
  /// `sync_push_rows` returns the rows the server accepted, i.e. those where the
  /// local version beat what was already stored. Everything else is marked
  /// clean immediately because the server already holds a newer copy; the pull
  /// pass then brings that copy down.
  Future<void> _pushLocalChanges() async {
    final client = Supabase.instance.client;

    for (final collection in kCollections) {
      final dirty = await (_db.select(_db.documents)
            ..where(
              (d) => d.collection.equals(collection) & d.dirty.equals(true),
            ))
          .get();

      if (dirty.isEmpty) continue;

      final payload = dirty
          .map((row) => {
                'id': row.docId,
                'data': decodePayload(row.payload),
                'version': row.version,
                'deleted': row.deleted,
                'updatedAt': row.localUpdatedAt.toUtc().toIso8601String(),
              })
          .toList();

      await client
          .rpc(
            'sync_push_rows',
            params: {'p_collection': collection, 'p_rows': payload},
          )
          .timeout(rpcTimeout);

      // Accepted rows are now durable on the server. Rejected rows lost the
      // version comparison, so the server already holds something newer; either
      // way the flag clears and the pull pass fetches whatever won.
      for (final row in dirty) {
        await (_db.update(_db.documents)
              ..where((d) =>
                  d.collection.equals(collection) & d.docId.equals(row.docId)))
            .write(const DocumentsCompanion(dirty: Value(false)));
      }
    }
  }

  /// Pulls rows changed since the last pass and applies remote winners.
  Future<void> _pullRemoteChanges() async {
    for (final collection in kCollections) {
      await _pullCollection(collection);
    }
  }

  /// Pulls one collection now. Public so the auth flow can fetch the `users`
  /// collection the moment a fresh device signs in, before any screen renders.
  Future<void> pullCollection(String collection) => _pullCollection(collection);

  Future<void> _pullCollection(String collection) async {
    final client = Supabase.instance.client;

    final since = await _lastPulledAt(collection);
    final rows = await client
        .rpc('sync_pull_rows', params: {
          'p_collection': collection,
          'p_since': since?.toUtc().toIso8601String(),
        })
        .timeout(rpcTimeout);

    if (rows is! List) return;

    final remoteUpdatedAts = <DateTime>[];
    await _db.transaction(() async {
      for (final raw in rows) {
        final remote = Map<String, dynamic>.from(raw as Map);
        final updatedAt =
            DateTime.tryParse(remote['updatedAt'] as String? ?? '')?.toUtc();
        if (updatedAt != null) remoteUpdatedAts.add(updatedAt);
        await _applyRemote(collection, remote);
      }
    });

    // Advance from the server's own timestamps, never the device clock.
    final nextCursor = nextPullCursor(since, remoteUpdatedAts);
    await (_db.into(_db.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
            collection: collection,
            lastPulledAt: Value(nextCursor),
          ),
        ));
  }

  /// Applies one remote row, but only if it wins over the local copy.
  Future<void> _applyRemote(
    String collection,
    Map<String, dynamic> remote,
  ) async {
    final id = remote['id'] as String;
    final remoteVersion = (remote['version'] as num).toInt();
    final remoteUpdatedAt =
        DateTime.tryParse(remote['updatedAt'] as String? ?? '')?.toUtc() ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

    final local = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(id)))
        .getSingleOrNull();

    if (local != null) {
      final remoteWins = remoteVersion > local.version ||
          (remoteVersion == local.version &&
              remoteUpdatedAt.isAfter(local.localUpdatedAt.toUtc()));
      if (!remoteWins) return;
    }

    final data = Map<String, dynamic>.from(remote['data'] as Map? ?? const {})
      ..['id'] = id;

    await _db.into(_db.documents).insertOnConflictUpdate(
          DocumentsCompanion.insert(
            collection: collection,
            docId: id,
            payload: encodePayload(data),
            version: Value(remoteVersion),
            localUpdatedAt: remoteUpdatedAt.toLocal(),
            dirty: const Value(false),
            deleted: Value(remote['deleted'] == true),
          ),
        );

    // A deleted user's credential must not outlive the account. Offline PIN
    // hashes are deliberately *not* pulled onto every device: each device
    // caches only the PINs it verified or set while online (see
    // LocalFirstAuthService.tryOnlinePinLogin / registerWithPin / setDriverPin),
    // so a stolen device cannot brute-force every depot user's 4-digit PIN.
    if (collection == 'users' && remote['deleted'] == true) {
      await (_db.delete(_db.localCredentials)
            ..where((c) => c.userId.equals(id)))
          .go();
    }
  }

  Future<DateTime?> _lastPulledAt(String collection) async {
    final row = await (_db.select(_db.syncState)
          ..where((s) => s.collection.equals(collection)))
        .getSingleOrNull();
    return row?.lastPulledAt;
  }

  Future<void> _refreshPendingCount() async {
    final count = await (_db.selectOnly(_db.documents)
          ..addColumns([_db.documents.docId.count()])
          ..where(_db.documents.dirty.equals(true)))
        .map((row) => row.read(_db.documents.docId.count()) ?? 0)
        .getSingle();

    _emit(_status.copyWith(pendingWrites: count));
  }

  void _emit(SyncStatus status) {
    _status = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  void dispose() {
    _debounce?.cancel();
    _pollTimer?.cancel();
    _retryTimer?.cancel();
    unawaited(_connectivitySub?.cancel());
    final channel = _realtimeChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    unawaited(_controller.close());
  }
}