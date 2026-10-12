import 'package:flutter_test/flutter_test.dart';
import 'package:depot_distribution_app/models/depot_model.dart';
import 'package:depot_distribution_app/models/user_model.dart';
import 'package:depot_distribution_app/models/user_role.dart';
import 'package:depot_distribution_app/models/user_status.dart';

void main() {
  group('UserModel', () {
    test('should create UserModel with correct values', () {
      final user = UserModel(
        id: '123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '1234567890',
        role: UserRole.admin,
        status: UserStatus.active,
        pinCode: '1234',
      );

      expect(user.id, '123');
      expect(user.name, 'John Doe');
      expect(user.email, 'john@example.com');
      expect(user.phone, '1234567890');
      expect(user.role, UserRole.admin);
      expect(user.status, UserStatus.active);
      expect(user.pinCode, '1234');
    });

    test('should serialize to and from map', () {
      final user = UserModel(
        id: '123',
        name: 'John Doe',
        email: 'john@example.com',
        phone: '1234567890',
        role: UserRole.admin,
        status: UserStatus.active,
        pinCode: '5678',
      );

      final map = user.toMap();
      final deserialized = UserModel.fromMap(map);

      expect(deserialized.id, user.id);
      expect(deserialized.name, user.name);
      expect(deserialized.email, user.email);
      expect(deserialized.phone, user.phone);
      expect(deserialized.role, user.role);
      expect(deserialized.status, user.status);
      expect(deserialized.pinCode, user.pinCode);
    });

    test('should handle copyWith correctly', () {
      final user = UserModel(
        id: '123',
        name: 'John Doe',
        email: 'john@example.com',
      );

      final updated = user.copyWith(name: 'Jane Doe', role: UserRole.admin);

      expect(updated.name, 'Jane Doe');
      expect(updated.role, UserRole.admin);
      expect(updated.id, '123');
      expect(updated.email, 'john@example.com');
      expect(updated.pinCode, '');
    });

    test('should handle pinCode in copyWith', () {
      final user = UserModel(
        id: '123',
        name: 'John Doe',
        email: 'john@example.com',
      );

      final updated = user.copyWith(pinCode: '9876');

      expect(updated.pinCode, '9876');
    });
  });

  group('UserRole', () {
    test('fromString should return correct enum', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('driver'), UserRole.driver);
      expect(UserRole.fromString('superadmin'), UserRole.superadmin);
      expect(UserRole.fromString('unknown'), UserRole.driver);
    });

    test('value should return correct string', () {
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.driver.value, 'driver');
      expect(UserRole.superadmin.value, 'superadmin');
      expect(UserRole.superadmin.isAdmin, isTrue);
      expect(UserRole.admin.isAdmin, isTrue);
      expect(UserRole.driver.isAdmin, isFalse);
    });
  });

  group('DepotModel', () {
    test('fromMap/toMap round trip keeps fields', () {
      final depot = DepotModel.fromMap({
        'id': 'd1',
        'name': 'Bafoussam',
        'city': 'Bafoussam',
        'address': 'Rue de la Mairie',
        'status': 'active',
        'createdAt': '2026-01-01T10:00:00.000Z',
      });
      expect(depot.id, 'd1');
      expect(depot.name, 'Bafoussam');
      expect(depot.displayName, 'Bafoussam · Bafoussam');
      final map = depot.toMap();
      expect(map['name'], 'Bafoussam');
      expect(map['address'], 'Rue de la Mairie');
      expect(map['status'], 'active');
    });

    test('defaults to active when status is missing', () {
      final depot = DepotModel.fromMap({
        'id': 'd2',
        'name': 'Douala',
        'createdAt': '2026-01-01T10:00:00.000Z',
      });
      expect(depot.status, 'active');
      expect(depot.isActive, isTrue);
      expect(depot.isInactive, isFalse);
      expect(depot.displayName, 'Douala');
    });

    test('isActive reflects the status field', () {
      final inactive = DepotModel(
        id: 'd3',
        name: 'Yaoundé',
        status: DepotModel.statusInactive,
      );
      expect(inactive.isActive, isFalse);
      expect(inactive.isInactive, isTrue);
      expect(inactive.displayName, 'Yaoundé');
    });

    test('copyWith changes status without touching other fields', () {
      final depot = DepotModel(id: 'd4', name: 'Centre', city: 'Ebolowa');
      final inactive = depot.copyWith(status: DepotModel.statusInactive);
      expect(inactive.id, 'd4');
      expect(inactive.name, 'Centre');
      expect(inactive.city, 'Ebolowa');
      expect(inactive.isActive, isFalse);
      expect(depot.isActive, isTrue);
    });
  });

  group('UserStatus', () {
    test('fromString should return correct enum', () {
      expect(UserStatus.fromString('active'), UserStatus.active);
      expect(UserStatus.fromString('inactive'), UserStatus.inactive);
      expect(UserStatus.fromString('unknown'), UserStatus.active);
    });

    test('value should return correct string', () {
      expect(UserStatus.active.value, 'active');
      expect(UserStatus.inactive.value, 'inactive');
    });
  });
}
