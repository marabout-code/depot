import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(ref.read(appDatabaseProvider));
});

/// Exports and restores the local database.
///
/// Backups are taken from the device database, which is the source of truth,
/// so a backup captures unsynced work too. Credentials are deliberately not
/// included: PIN hashes exist only for on-device verification, and a restored
/// backup must not resurrect them on a different handset.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const int schemaVersion = 1;

  static const List<String> _collections = [
    AppConstants.usersCollection,
    AppConstants.productsCollection,
    AppConstants.ordersCollection,
    AppConstants.deliveriesCollection,
    AppConstants.inventoryCollection,
    AppConstants.movementsCollection,
    AppConstants.categoriesCollection,
  ];

  Future<String> _buildJson() async {
    final data = <String, dynamic>{
      'version': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
    };

    for (final collection in _collections) {
      final rows = await (_db.select(_db.documents)
            ..where((d) => d.collection.equals(collection) & d.deleted.equals(false)))
          .get();

      data[collection] = rows
          .map((row) => {
                'id': row.docId,
                'data': decodePayload(row.payload),
                'version': row.version,
              })
          .toList();
    }

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<String> exportToJson() async {
    final json = await _buildJson();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${AppConstants.backupFileName}',
    );
    await file.writeAsString(json);
    return file.path;
  }

  Future<String> exportRawJsonString() => _buildJson();

  /// Restores documents from a backup.
  ///
  /// Rows are applied with the version they were exported at, so restoring an
  /// older backup does not silently overwrite newer data that synced in the
  /// meantime: the version comparison in the sync engine keeps the higher one.
  /// Rows are marked dirty so the restored content reaches the server.
  Future<int> importFromJsonString(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Fichier de sauvegarde invalide.');
    }
    final data = Map<String, dynamic>.from(decoded);

    final version = data['version'];
    if (version is int && version > schemaVersion) {
      throw FormatException(
        'Sauvegarde créée par une version plus récente de l\'application '
        '(v$version).',
      );
    }

    var count = 0;

    await _db.transaction(() async {
      for (final collection in _collections) {
        final rows = data[collection];
        if (rows is! List) continue;

        for (final raw in rows) {
          if (raw is! Map) continue;
          final row = Map<String, dynamic>.from(raw);

          final id = row['id'] as String?;
          if (id == null) continue;

          final payload = row['data'];
          if (payload is! Map) continue;

          // The users collection is keyed by auth uid, which is device specific
          // only in the sense that a restore targets one depot. Keep the ids so
          // driver PIN assignments stay attached to the right accounts.
          final restored = Map<String, dynamic>.from(payload)..['id'] = id;

          await _db.into(_db.documents).insert(
                DocumentsCompanion.insert(
                  collection: collection,
                  docId: id,
                  payload: encodePayload(restored),
                  version: Value((row['version'] as num?)?.toInt() ?? 1),
                  localUpdatedAt: DateTime.now(),
                  dirty: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
          count++;
        }
      }
    });

    return count;
  }

  Future<int> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Fichier introuvable : $filePath');
    }
    final jsonString = await file.readAsString();
    if (jsonString.trim().isEmpty) {
      throw Exception('Le fichier est vide.');
    }
    return importFromJsonString(jsonString);
  }
}