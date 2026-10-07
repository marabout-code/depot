import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_data_service.dart';
import '../core/services/local_first_auth_service.dart';
import '../core/constants/app_constants.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

enum DriversStatus { initial, loading, loaded, error }

class DriversState {
  final DriversStatus status;
  final List<DriverModel> drivers;
  final String? error;

  const DriversState({
    this.status = DriversStatus.initial,
    this.drivers = const [],
    this.error,
  });

  DriversState copyWith({
    DriversStatus? status,
    List<DriverModel>? drivers,
    String? error,
  }) {
    return DriversState(
      status: status ?? this.status,
      drivers: drivers ?? this.drivers,
      error: error,
    );
  }
}

class DriverNotifier extends StateNotifier<DriversState> {
  final LocalDataService _data;
  final LocalFirstAuthService _authService;

  DriverNotifier(this._data, this._authService) : super(const DriversState());

  Future<void> loadDrivers() async {
    state = state.copyWith(status: DriversStatus.loading);
    try {
      final users = await _data.getDocuments<UserModel>(
        AppConstants.usersCollection,
        UserModel.fromMap,
        where: [WhereClause(field: 'role', value: 'driver')],
      );
      final drivers = users
          .map((u) => DriverModel.fromUserModel(u))
          .toList();
      state = DriversState(
        status: DriversStatus.loaded,
        drivers: drivers,
      );
    } catch (e) {
      state = state.copyWith(
        status: DriversStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Creates a driver account, assigns the admin-chosen PIN, and writes the
  /// profile locally so the driver appears in the list without a network round
  /// trip. The account creation itself calls `admin_create_user`, which needs a
  /// connection; without one the driver is still created locally and the row
  /// syncs later, but the PIN cannot be verified on other devices until then.
  Future<void> saveDriver(DriverModel driver) async {
    state = state.copyWith(status: DriversStatus.loading);
    try {
      final normalizedPin =
          LocalFirstAuthService.normalizePin(driver.pinCode);

      UserModel? registered;
      try {
        registered = await _authService.registerWithPin(
          email: driver.email,
          name: driver.name,
          pin: normalizedPin,
          role: UserRole.driver,
          phone: driver.phone,
        );
      } catch (e) {
        state = state.copyWith(
          status: DriversStatus.error,
          error: e.toString().replaceFirst('Exception: ', ''),
        );
        return;
      }

      final uid = registered?.id ?? driver.id;
      final data = {
        ...driver.copyWith(id: uid).toMap(),
        'role': 'driver',
      }..remove('pinCode'); // A synced document must never carry the plaintext PIN.

      if (registered != null) {
        // `registerWithPin` already created the local row (including the offline
        // pin hash) and cached this device's credential. Merge the full driver
        // profile over it instead of recreating it, so the hash survives.
        await _data.updateDocument(
          AppConstants.usersCollection,
          uid,
          data,
        );
      } else {
        await _data.createDocument(
          AppConstants.usersCollection,
          data,
          docId: uid,
        );
      }

      await loadDrivers();
    } catch (e) {
      state = state.copyWith(
        status: DriversStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateDriver(String id, Map<String, dynamic> data) async {
    state = state.copyWith(status: DriversStatus.loading);
    try {
      // A PIN in the payload is a rotation request, not profile data: the new
      // PIN is hashed and never stored in the synced document.
      final newPin = data['pinCode'] as String?;
      if (newPin != null && newPin.isNotEmpty) {
        await _authService.setDriverPin(id, newPin);
        data = {...data}..remove('pinCode');
      } else {
        data = {...data}..remove('pinCode');
      }

      await _data.updateDocument(
        AppConstants.usersCollection,
        id,
        data,
      );
      await loadDrivers();
    } catch (e) {
      state = state.copyWith(
        status: DriversStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    await updateDriver(id, {
      'availability': {
        'isAvailable': isAvailable,
        'lastUpdated': DateTime.now().toIso8601String(),
      }
    });
  }

  Future<void> deleteDriver(String id) async {
    state = state.copyWith(status: DriversStatus.loading);
    try {
      await _data.deleteDocument(AppConstants.usersCollection, id);
      await loadDrivers();
    } catch (e) {
      state = state.copyWith(
        status: DriversStatus.error,
        error: e.toString(),
      );
    }
  }

  List<DriverModel> search(String query) {
    if (query.isEmpty) return state.drivers;
    final q = query.toLowerCase();
    return state.drivers.where((d) {
      return d.name.toLowerCase().contains(q) ||
          d.email.toLowerCase().contains(q) ||
          d.phone.toLowerCase().contains(q) ||
          d.vehicle.plateNumber.toLowerCase().contains(q);
    }).toList();
  }
}

final driverProvider =
    StateNotifierProvider<DriverNotifier, DriversState>((ref) {
  return DriverNotifier(
    ref.read(localDataServiceProvider),
    ref.read(authServiceProvider),
  );
});
