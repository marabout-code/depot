import 'package:depot_distribution_app/core/database/app_database.dart';
import 'package:depot_distribution_app/core/database/local_auth_service.dart';
import 'package:depot_distribution_app/core/database/local_data_service.dart';
import 'package:depot_distribution_app/models/user_model.dart';
import 'package:depot_distribution_app/models/user_role.dart';
// Only for the `&` operator on expressions; the drift matchers would collide
// with matcher's isNull/isNotNull.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalAuthService auth;
  late LocalDataService data;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    auth = LocalAuthService(db);
    data = LocalDataService(db);
  });

  tearDown(() async => db.close());

  Future<String> addUser({
    required String id,
    required String pin,
    String name = 'Test User',
  }) async {
    await data.createDocument('users', {
      'id': id,
      'name': name,
      'email': '$id@example.com',
      'role': UserRole.driver.value,
      'status': 'active',
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }, docId: id);

    await auth.storeCredential(userId: id, pin: pin, role: UserRole.driver);
    return id;
  }

  group('PIN validation', () {
    test('requires exactly four digits', () {
      expect(LocalAuthService.isValidPin('1234'), isTrue);
      expect(LocalAuthService.isValidPin('0000'), isTrue);
      expect(LocalAuthService.isValidPin('123'), isFalse);
      expect(LocalAuthService.isValidPin('12345'), isFalse);
      expect(LocalAuthService.isValidPin('12a4'), isFalse);
      expect(LocalAuthService.isValidPin(''), isFalse);
    });

    test('strips separators and left-pads short input', () {
      expect(LocalAuthService.normalizePin('12'), '0012');
      expect(LocalAuthService.normalizePin('1 2 3 4'), '1234');
      expect(LocalAuthService.normalizePin('ab12'), '0012');
    });
  });

  group('authenticatePin', () {
    test('resolves a known user and clears prior failures', () async {
      await addUser(id: 'u1', pin: '1234');

      final user = await auth.authenticatePin('1234');
      expect(user, isNotNull);
      expect(user!.id, 'u1');
    });

    test('rejects a wrong PIN', () async {
      await addUser(id: 'u1', pin: '1234');

      expect(await auth.authenticatePin('9999'), isNull);
    });

    test('rejects a malformed PIN without touching storage', () async {
      await addUser(id: 'u1', pin: '1234');

      expect(await auth.authenticatePin('12'), isNull);
    });

    test('refuses when the same PIN belongs to two accounts', () async {
      await addUser(id: 'u1', pin: '1234');
      await addUser(id: 'u2', pin: '1234');

      expect(await auth.authenticatePin('1234'), isNull);
    });

    test('locks out after repeated guesses', () async {
      await addUser(id: 'u1', pin: '1234');

      // Guesses that match no account are counted against the global bucket.
      for (var i = 0; i < LocalAuthService.maxLocalAttempts; i++) {
        expect(await auth.authenticatePin('9999'), isNull);
      }

      // Even the correct PIN is refused while the device is throttled.
      expect(await auth.authenticatePin('1234'), isNull);
      expect(await auth.isLockedOut('*'), isTrue);
    });

    test('a successful guess clears the global failure bucket', () async {
      await addUser(id: 'u1', pin: '1234');

      await auth.authenticatePin('9999');
      await auth.authenticatePin('9999');
      expect(await auth.isLockedOut('*'), isFalse);

      expect(await auth.authenticatePin('1234'), isNotNull);

      final attempts = await db.select(db.localAttempts).get();
      expect(attempts.where((a) => a.userId == '*'), isEmpty);
    });
  });

  group('storeCredential', () {
    test('rejects a PIN of the wrong length', () async {
      expect(
        () => auth.storeCredential(
          userId: 'u1',
          pin: '12345',
          role: UserRole.driver,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rotating a PIN invalidates the old one', () async {
      await addUser(id: 'u1', pin: '1234');

      await auth.storeCredential(
        userId: 'u1',
        pin: '5678',
        role: UserRole.driver,
      );

      expect(await auth.authenticatePin('1234'), isNull);
      expect(await auth.authenticatePin('5678'), isNotNull);
    });
  });

  group('LocalDataService', () {
    test('round-trips a document through the JSON payload', () async {
      await addUser(id: 'u1', pin: '1234');

      final user = await data.getDocument<UserModel>(
        'users',
        'u1',
        UserModel.fromMap,
      );
      expect(user!.email, 'u1@example.com');
    });

    test('soft delete hides the row from reads', () async {
      await addUser(id: 'u1', pin: '1234');

      await data.deleteDocument('users', 'u1');

      final raw = await data.rawDocument('users', 'u1');
      expect(raw, isNull);
    });

    test('update marks the row dirty for sync', () async {
      await addUser(id: 'u1', pin: '1234');

      await data.updateDocument('users', 'u1', {'name': 'Renamed'});

      final row = await (db.select(db.documents)
            ..where((d) => d.collection.equals('users') & d.docId.equals('u1')))
          .getSingle();
      expect(row.dirty, isTrue);
      expect(row.version, 2);
      expect(decodePayload(row.payload)['name'], 'Renamed');
    });
  });
}