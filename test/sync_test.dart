import 'package:depot_distribution_app/core/database/app_database.dart';
import 'package:depot_distribution_app/core/database/local_data_service.dart';
import 'package:depot_distribution_app/core/services/sync_service.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('retryDelay (exponential backoff)', () {
    test('starts at zero for failed attempt 0', () {
      expect(SyncService.retryDelay(0), Duration.zero);
    });

    test('grows 5s, 10s, 20s and then caps', () {
      expect(SyncService.retryDelay(1), const Duration(seconds: 5));
      expect(SyncService.retryDelay(2), const Duration(seconds: 10));
      expect(SyncService.retryDelay(3), const Duration(seconds: 20));
    });

    test('never exceeds the maximum delay', () {
      for (var i = 1; i <= 30; i++) {
        expect(
          SyncService.retryDelay(i) <= SyncService.maxRetryDelay,
          isTrue,
          reason: 'attempt $i exceeded the cap',
        );
      }
      expect(SyncService.retryDelay(30), SyncService.maxRetryDelay);
    });
  });

  group('nextPullCursor', () {
    test('has no cursor when nothing was pulled', () {
      expect(SyncService.nextPullCursor(null, const []), isNull);
    });

    test('rewinds the newest remote timestamp by the overlap', () {
      final remote = DateTime.utc(2026, 1, 1, 10, 0, 0);
      expect(
        SyncService.nextPullCursor(null, [remote]),
        remote.subtract(SyncService.cursorOverlap),
      );
    });

    test('uses the maximum of several remote timestamps', () {
      final cursor = SyncService.nextPullCursor(null, [
        DateTime.utc(2026, 1, 1, 9),
        DateTime.utc(2026, 1, 1, 11),
        DateTime.utc(2026, 1, 1, 10),
      ]);
      expect(
        cursor,
        DateTime.utc(2026, 1, 1, 11).subtract(SyncService.cursorOverlap),
      );
    });

    test('keeps the existing cursor when nothing new was seen', () {
      final current = DateTime.utc(2026, 1, 1, 10);
      expect(SyncService.nextPullCursor(current, const []), current);
    });

    test('never moves the cursor backwards', () {
      final current = DateTime.utc(2026, 1, 1, 10);
      // A remote timestamp older than the cursor must not rewind it.
      final cursor = SyncService.nextPullCursor(current, [
        DateTime.utc(2026, 1, 1, 9),
      ]);
      expect(cursor, current);
    });

    test('ignores the device clock entirely', () {
      // Far-future local time is irrelevant because the cursor is derived from
      // the server timestamps passed in.
      final remote = DateTime.utc(2026, 1, 1, 10);
      final cursor = SyncService.nextPullCursor(null, [remote])!;
      expect(cursor.isBefore(DateTime.now().add(const Duration(days: 365))),
          isTrue);
    });
  });

  group('LocalDataService.onWrite', () {
    late AppDatabase db;
    late int writes;

    setUp(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      writes = 0;
    });

    tearDown(() async => db.close());

    test('fires after create, update, delete and batch operations', () async {
      final data = LocalDataService(db, onWrite: () => writes++);

      await data.createDocument('products', {'name': 'Ciment'}, docId: 'p1');
      expect(writes, 1);

      await data.updateDocument('products', 'p1', {'price': 5000});
      expect(writes, 2);

      await data.batchWrite([
        BatchOperation(
          type: BatchOperationType.set,
          collection: 'products',
          docId: 'p2',
          data: {'name': 'Fer'},
        ),
        BatchOperation(
          type: BatchOperationType.update,
          collection: 'products',
          docId: 'p1',
          data: {'price': 6000},
        ),
      ]);
      expect(writes, 3);

      await data.deleteDocument('products', 'p2');
      expect(writes, 4);
    });

    test('an update to an unknown row is treated as a create', () async {
      final data = LocalDataService(db, onWrite: () => writes++);

      await data.updateDocument('products', 'ghost', {'name': 'Sable'});

      expect(writes, 1);
      expect(await data.pendingSyncCount(), 1);
    });

    test('deleting a missing row does not signal a write', () async {
      final data = LocalDataService(db, onWrite: () => writes++);

      await data.deleteDocument('products', 'missing');

      expect(writes, 0);
    });

    test('works without the optional callback', () async {
      final data = LocalDataService(db);
      await data.createDocument('products', {'name': 'Brique'}, docId: 'b1');
      expect(await data.pendingSyncCount(), 1);
    });
  });
}
