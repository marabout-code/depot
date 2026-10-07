import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Local-first store. SQLite on the device is the source of truth; Supabase is
/// a sync peer, never a read dependency.
///
/// Every synced collection is kept in the single `documents` table rather than
/// one typed table per collection. The app's models already serialize through
/// `toMap()` / `fromMap()`, so a `json` payload keeps them working unchanged
/// and lets one sync engine handle all seven collections.
class Documents extends Table {
  TextColumn get collection => text()();
  TextColumn get docId => text()();
  TextColumn get payload => text()();

  /// Monotonic version used for last-write-wins conflict resolution. A local
  /// write bumps it; the winning side is whichever version is higher.
  IntColumn get version => integer().withDefault(const Constant(1))();

  /// Wall clock time of the local write, used only as a tiebreaker when two
  /// devices produce the same version.
  DateTimeColumn get localUpdatedAt => dateTime()();

  /// Set while the row has local changes the server has not accepted.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// Soft delete so a removal can propagate to other devices.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {collection, docId};
}

/// Locally hashed PIN credentials so login works with no network.
///
/// `offlinePinHash` is produced by the Dart bcrypt implementation and is only
/// ever compared against a PIN typed on this device. The server keeps its own
/// pgcrypto hash separately; neither hash has to verify the other.
class LocalCredentials extends Table {
  TextColumn get userId => text()();
  TextColumn get offlinePinHash => text()();
  TextColumn get role => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Failed local PIN attempts, used to throttle offline brute forcing.
class LocalAttempts extends Table {
  TextColumn get userId => text()();
  IntColumn get failures => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime()();

  @override
  Set<Column> get primaryKey => {userId};
}

/// Sync bookkeeping, one row per collection.
class SyncState extends Table {
  TextColumn get collection => text()();
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {collection};
}

@DriftDatabase(tables: [Documents, LocalCredentials, LocalAttempts, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Test-only constructor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed the per-collection sync cursors so the first pull has a row to
          // read from.
          for (final name in kCollections) {
            await into(syncState).insert(
                  SyncStateCompanion.insert(collection: name),
                  mode: InsertMode.insertOrIgnore,
                );
          }
        },
      );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'depot_distribution',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
        shareAcrossIsolates: true,
      ),
    );
  }
}

/// Collections shared by the local database, the sync engine and the backup
/// exporter. Mirrors `AppConstants` collection names.
const List<String> kCollections = [
  'users',
  'products',
  'orders',
  'deliveries',
  'inventory',
  'movements',
  'categories',
];

/// The single local database handle, shared by the auth, data and sync layers.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Decodes a stored payload back into the camelCase map the models expect.
Map<String, dynamic> decodePayload(String json) =>
    Map<String, dynamic>.from(jsonDecode(json) as Map);

String encodePayload(Map<String, dynamic> data) => jsonEncode(data);