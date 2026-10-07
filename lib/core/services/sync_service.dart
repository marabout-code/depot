import 'dart:async';
import 'dart:io' show SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_config.dart';
import '../database/app_database.dart';
import '../../models/user_role.dart';

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

  final _controller = StreamController<SyncStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _debounce;
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
      _emit(_status.copyWith(online: online));
      if (online) scheduleSync();
    });

    await syncNow();
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
      _emit(_status.copyWith(
        running: false,
        online: true,
        lastSyncedAt: now,
        clearError: true,
      ));
    } on SocketException {
      _emit(_status.copyWith(running: false, online: false));
    } on AuthException {
      _emit(_status.copyWith(
        running: false,
        lastError: 'Session expirée. Reconnectez-vous pour synchroniser.',
      ));
    } on PostgrestException catch (e) {
      _emit(_status.copyWith(running: false, lastError: e.message));
    } catch (e) {
      _emit(_status.copyWith(running: false, lastError: e.toString()));
    } finally {
      _running = false;
      await _refreshPendingCount();
    }
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

      await client.rpc(
        'sync_push_rows',
        params: {'p_collection': collection, 'p_rows': payload},
      );

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
    final client = Supabase.instance.client;

    for (final collection in kCollections) {
      final since = await _lastPulledAt(collection);
      final rows = await client.rpc('sync_pull_rows', params: {
        'p_collection': collection,
        'p_since': since?.toUtc().toIso8601String(),
      });

      if (rows is! List) continue;

      await _db.transaction(() async {
        for (final raw in rows) {
          await _applyRemote(collection, Map<String, dynamic>.from(raw as Map));
        }
      });

      await (_db.into(_db.syncState).insertOnConflictUpdate(
            SyncStateCompanion.insert(
              collection: collection,
              lastPulledAt: Value(DateTime.now()),
            ),
          ));
    }
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

    // A pulled user row carries the offline bcrypt hash so this device can
    // verify that user's PIN without connectivity. On deletion the hash is
    // removed with the credential.
    if (collection == 'users') {
      if (remote['deleted'] == true) {
        await (_db.delete(_db.localCredentials)
              ..where((c) => c.userId.equals(id)))
            .go();
      } else {
        final offlineHash = data['offlinePinHash'] as String?;
        if (offlineHash != null && offlineHash.isNotEmpty) {
          await _db.into(_db.localCredentials).insertOnConflictUpdate(
                LocalCredentialsCompanion.insert(
                  userId: id,
                  offlinePinHash: offlineHash,
                  role: data['role'] as String? ?? UserRole.driver.value,
                  updatedAt: remoteUpdatedAt.toLocal(),
                ),
              );
        }
      }
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
    unawaited(_connectivitySub?.cancel());
    unawaited(_controller.close());
  }
}