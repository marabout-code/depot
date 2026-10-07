import 'package:flutter_test/flutter_test.dart';
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
      expect(UserRole.fromString('unknown'), UserRole.driver);
    });

    test('value should return correct string', () {
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.driver.value, 'driver');
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
