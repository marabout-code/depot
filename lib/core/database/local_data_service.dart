import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import '../database/depot_scope.dart';
import '../services/sync_service.dart';

final localDataServiceProvider = Provider<LocalDataService>((ref) {
  return LocalDataService(
    ref.read(appDatabaseProvider),
    // Every local write nudges the sync engine, so an edit made while online
    // reaches the server on the next pass instead of waiting for a connectivity
    // change, a realtime event or the next app launch — the situation that left
    // changes stranded for hours on an unreliable connection.
    onWrite: () => ref.read(syncServiceProvider).scheduleSync(),
  );
});

/// Local-first data access.
///
/// Exposes the same surface the providers were written against when the
/// backend was Firestore, but every read and write goes to SQLite on the
/// device. Nothing here touches the network: writes are recorded as `dirty`
/// rows and the sync engine drains them later, so the UI never blocks on a
/// round trip and keeps working with the radio off.
class LocalDataService {
  LocalDataService(this._db, {this.onWrite});

  final AppDatabase _db;

  /// Invoked after every write that changed a row, so the sync engine can queue
  /// a pass. Optional so tests can construct the service without a sync layer.
  final void Function()? onWrite;

  /// The depot this device's local database is scoped to. Reads are filtered by
  /// it and a scope change purges foreign rows, so one depot's admin never sees
  /// another's data. Defaults to [DepotScope.all] so the pre-login and test
  /// behaviour is an unfiltered database.
  DepotScope _scope = const DepotScope.all();

  DepotScope get scope => _scope;

  /// The collection whose rows survive a logout: their profiles and offline PIN
  /// hashes are what make an offline keypad login work after signing out.
  static const String _usersCollection = 'users';

  /// Establishes the active depot scope. When it changes (login as another
  /// depot, or logout) the rows that no longer belong are deleted and the sync
  /// cursors reset, so the next pass re-pulls the new scope from scratch.
  Future<void> setScope(DepotScope scope) async {
    if (scope == _scope) return;
    _scope = scope;
    await _purgeForScope(scope);
    await _resetSyncCursors();
    onWrite?.call();
  }

  Future<void> _purgeForScope(DepotScope scope) async {
    // Unrestricted callers read every depot, so there is nothing to remove.
    if (scope.isAll) return;

    if (scope.isNone) {
      await (_db.delete(_db.documents)
            ..where((d) => d.collection.equals(_usersCollection).not()))
          .go();
      return;
    }

    // A depot-scoped caller keeps only its own rows; the legacy NULL-depot rows
    // are shared and stay.
    final depotId = scope.depotId!;
    await (_db.delete(_db.documents)
          ..where(
            (d) => d.depotId.isNotNull() & d.depotId.equals(depotId).not(),
          ))
        .go();
  }

  Future<void> _resetSyncCursors() async {
    await _db
        .update(_db.syncState)
        .write(SyncStateCompanion(lastPulledAt: Value<DateTime?>(null)));
  }

  /// Filters and sorts happen in Dart over the decoded payload. The depot
  /// dataset is small enough that this stays well under a frame, and it keeps
  /// one code path for both synced and unsynced rows.
  static const Map<String, String> _orderFields = {
    'users': 'name',
    'orders': 'createdAt',
    'deliveries': 'createdAt',
    'movements': 'createdAt',
    'inventory': 'productName',
    'products': 'name',
    'categories': 'name',
    'routes': 'date',
    'depots': 'name',
  };

  Future<String> createDocument(
    String collection,
    Map<String, dynamic> data, {
    String? docId,
  }) async {
    final id = docId ?? const Uuid().v4();
    await _db.into(_db.documents).insert(
          DocumentsCompanion.insert(
            collection: collection,
            docId: id,
            payload: encodePayload({...data, 'id': id}),
            depotId: Value(_depotIdFor(collection, id, data)),
            version: const Value(1),
            localUpdatedAt: DateTime.now(),
            dirty: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
    onWrite?.call();
    return id;
  }

  /// The depot a new row is stamped with. A depot record belongs to itself
  /// (matching the server, so each depot admin reads its own record). Otherwise
  /// an explicit `depotId` in the payload wins — a superadmin assigning a user
  /// to a specific depot — and everything else inherits the caller's depot.
  /// An unrestricted caller stamps null when nothing is explicit.
  String? _depotIdFor(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) {
    if (collection == 'depots') return docId;
    final explicit = data['depotId'];
    if (explicit is String && explicit.isNotEmpty) return explicit;
    return _scope.stampDepotId;
  }

  Future<T?> getDocument<T>(
    String collection,
    String docId,
    T Function(Map<String, dynamic>) fromMap, {
    bool throwOnNotFound = true,
  }) async {
    final row = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .getSingleOrNull();

    if (row == null || row.deleted || !_scope.allows(row.depotId)) {
      if (throwOnNotFound) {
        throw LocalDataException('Document not found in $collection/$docId');
      }
      return null;
    }
    return fromMap(decodePayload(row.payload));
  }

  Future<Map<String, dynamic>?> rawDocument(
    String collection,
    String docId, {
    bool throwOnNotFound = false,
  }) async {
    final row = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .getSingleOrNull();

    if (row == null || row.deleted || !_scope.allows(row.depotId)) {
      if (throwOnNotFound) {
        throw LocalDataException('Document not found in $collection/$docId');
      }
      return null;
    }
    return decodePayload(row.payload);
  }

  Future<List<T>> getDocuments<T>(
    String collection,
    T Function(Map<String, dynamic>) fromMap, {
    String? orderBy,
    bool descending = false,
    int? limit,
    List<WhereClause>? where,
  }) async {
    final rows = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.deleted.equals(false)))
        .get();

    var items = rows
        .where((row) => _scope.allows(row.depotId))
        .map((row) => Map<String, dynamic>.from(decodePayload(row.payload)))
        .toList();

    for (final clause in where ?? const <WhereClause>[]) {
      items = items.where((item) => item[clause.field] == clause.value).toList();
    }

    final sortField = orderBy ?? _orderFields[collection];
    if (sortField != null) {
      items.sort((a, b) {
        final av = a[sortField];
        final bv = b[sortField];
        final cmp = _compare(av, bv);
        return descending ? -cmp : cmp;
      });
    }

    if (limit != null && items.length > limit) {
      items = items.sublist(0, limit);
    }

    return items.map(fromMap).toList();
  }

  static int _compare(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    final ad = DateTime.tryParse(a.toString());
    final bd = DateTime.tryParse(b.toString());
    if (ad != null && bd != null) return ad.compareTo(bd);
    return a.toString().compareTo(b.toString());
  }

  /// Merges [data] into the stored payload and marks the row for sync.
  Future<void> updateDocument(
    String collection,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final existing = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .getSingleOrNull();

    if (existing == null) {
      // Treat an update to an unknown row as an insert so callers do not have to
      // distinguish createDocument from updateDocument.
      await createDocument(collection, data, docId: docId);
      return;
    }

    final merged = decodePayload(existing.payload)
      ..addAll(data)
      ..['updatedAt'] = DateTime.now().toIso8601String()
      ..['id'] = docId;

    await (_db.update(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .write(
      DocumentsCompanion(
        payload: Value(encodePayload(merged)),
        version: Value(existing.version + 1),
        localUpdatedAt: Value(DateTime.now()),
        dirty: const Value(true),
        deleted: const Value(false),
      ),
    );
    onWrite?.call();
  }

  /// Soft delete: the tombstone has to reach other devices.
  Future<void> deleteDocument(String collection, String docId) async {
    final existing = await (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .getSingleOrNull();

    if (existing == null) return;

    await (_db.update(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .write(
      DocumentsCompanion(
        version: Value(existing.version + 1),
        localUpdatedAt: Value(DateTime.now()),
        dirty: const Value(true),
        deleted: const Value(true),
      ),
    );
    onWrite?.call();
  }

  /// Applies many operations in one transaction.
  Future<void> batchWrite(List<BatchOperation> operations) async {
    await _db.transaction(() async {
      for (final op in operations) {
        final existing = await _rowFor(op.collection, op.docId);

        switch (op.type) {
          case BatchOperationType.set:
            final payload = {
              if (existing != null) ...decodePayload(existing.payload),
              ...?op.data,
              'id': op.docId,
            };
            await _db.into(_db.documents).insert(
                  DocumentsCompanion.insert(
                    collection: op.collection,
                    docId: op.docId,
                    payload: encodePayload(payload),
                    depotId: existing != null
                        ? Value(existing.depotId)
                        : Value(_depotIdFor(op.collection, op.docId, payload)),
                    version: Value((existing?.version ?? 0) + 1),
                    localUpdatedAt: DateTime.now(),
                    dirty: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
          case BatchOperationType.update:
            if (existing == null) continue;
            await (_db.update(_db.documents)
                  ..where((d) =>
                      d.collection.equals(op.collection) &
                      d.docId.equals(op.docId)))
                .write(DocumentsCompanion(
              payload: Value(encodePayload({
                ...decodePayload(existing.payload),
                ...op.data!,
                'updatedAt': DateTime.now().toIso8601String(),
                'id': op.docId,
              })),
              version: Value(existing.version + 1),
              localUpdatedAt: Value(DateTime.now()),
              dirty: const Value(true),
            ));
          case BatchOperationType.delete:
            if (existing == null) continue;
            await (_db.update(_db.documents)
                  ..where((d) =>
                      d.collection.equals(op.collection) &
                      d.docId.equals(op.docId)))
                .write(DocumentsCompanion(
              version: Value(existing.version + 1),
              localUpdatedAt: Value(DateTime.now()),
              dirty: const Value(true),
              deleted: const Value(true),
            ));
        }
      }
    });
    onWrite?.call();
  }

  Future<Document?> _rowFor(String collection, String docId) {
    return (_db.select(_db.documents)
          ..where((d) => d.collection.equals(collection) & d.docId.equals(docId)))
        .getSingleOrNull();
  }

  /// Number of rows waiting to reach the server, for the settings screen.
  Future<int> pendingSyncCount() async {
    final count = await (_db.selectOnly(_db.documents)
          ..addColumns([_db.documents.docId.count()])
          ..where(_db.documents.dirty.equals(true)))
        .map((row) => row.read(_db.documents.docId.count()) ?? 0)
        .getSingle();
    return count;
  }
}

class LocalDataException implements Exception {
  LocalDataException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WhereClause {
  WhereClause({required this.field, required this.value});

  final String field;
  final dynamic value;
}

enum BatchOperationType { set, update, delete }

class BatchOperation {
  BatchOperation({
    required this.type,
    required this.collection,
    required this.docId,
    this.data,
  });

  final BatchOperationType type;
  final String collection;
  final String docId;
  final Map<String, dynamic>? data;
}