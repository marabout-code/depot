import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/database/local_auth_service.dart';
import '../core/database/local_data_service.dart';
import '../core/services/local_first_auth_service.dart';
import '../models/depot_model.dart';
import '../models/user_model.dart';
import '../models/user_role.dart';

enum DepotsStatus { initial, loading, loaded, error }

/// Result of a depot + first-admin creation. [warning] carries a partial
/// failure (e.g. the depot was created but its admin could not): [depotId] is
/// still valid.
class DepotCreationResult {
  final String depotId;
  final String? warning;

  const DepotCreationResult({required this.depotId, this.warning});
}

class DepotsState {
  final DepotsStatus status;
  final List<DepotModel> depots;
  final String? error;

  /// True while any depot mutation (create / edit / status / delete / admin)
  /// is in flight, so the UI can disable its buttons.
  final bool isBusy;

  const DepotsState({
    this.status = DepotsStatus.initial,
    this.depots = const [],
    this.error,
    this.isBusy = false,
  });

  DepotsState copyWith({
    DepotsStatus? status,
    List<DepotModel>? depots,
    String? error,
    bool? isBusy,
  }) {
    return DepotsState(
      status: status ?? this.status,
      depots: depots ?? this.depots,
      error: error,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

/// Headline counts for one depot, from the `depot_stats` RPC.
class DepotStats {
  final int admins;
  final int drivers;
  final int products;
  final int categories;
  final int orders;
  final int deliveries;
  final int routes;
  final int inventory;
  final int movements;

  const DepotStats({
    this.admins = 0,
    this.drivers = 0,
    this.products = 0,
    this.categories = 0,
    this.orders = 0,
    this.deliveries = 0,
    this.routes = 0,
    this.inventory = 0,
    this.movements = 0,
  });

  factory DepotStats.fromMap(Map<String, dynamic> map) {
    int read(String key) => (map[key] as num?)?.toInt() ?? 0;
    return DepotStats(
      admins: read('admins'),
      drivers: read('drivers'),
      products: read('products'),
      categories: read('categories'),
      orders: read('orders'),
      deliveries: read('deliveries'),
      routes: read('routes'),
      inventory: read('inventory'),
      movements: read('movements'),
    );
  }
}

class DepotNotifier extends StateNotifier<DepotsState> {
  final LocalDataService _data;

  DepotNotifier(this._data) : super(const DepotsState());

  Future<void> loadDepots() async {
    state = state.copyWith(status: DepotsStatus.loading);
    try {
      final depots = await _data.getDocuments<DepotModel>(
        AppConstants.depotsCollection,
        DepotModel.fromMap,
      );
      state = DepotsState(status: DepotsStatus.loaded, depots: depots);
    } catch (e) {
      state = state.copyWith(status: DepotsStatus.error, error: e.toString());
    }
  }

  /// Creates a depot and, when [adminName] and [adminPin] are given, its first
  /// administrator. Both RPCs need a connection. The synced depot row is
  /// mirrored locally so the new depot shows up immediately.
  Future<DepotCreationResult?> createDepot({
    required String name,
    required String city,
    String? adminName,
    String? adminPin,
  }) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      final client = Supabase.instance.client;

      final result = await client.rpc('depot_create', params: {
        'p_name': name.trim(),
        'p_city': city.trim(),
      });
      final depotId = result?['id'] as String?;
      if (depotId == null) {
        throw Exception('Échec de la création du dépôt.');
      }

      String? warning;
      final wantsAdmin = adminName != null &&
          adminName.trim().isNotEmpty &&
          adminPin != null &&
          adminPin.isNotEmpty;
      if (wantsAdmin) {
        final error = await _createDepotAdminRpc(
          depotId: depotId,
          name: adminName,
          pin: adminPin,
        );
        if (error != null) {
          warning = "Dépôt créé, mais échec de la création de "
              "l'administrateur : $error";
        }
      }

      final now = DateTime.now().toIso8601String();
      await _data.createDocument(
        AppConstants.depotsCollection,
        {
          'id': depotId,
          'name': name.trim(),
          'city': city.trim(),
          'status': DepotModel.statusActive,
          'createdAt': now,
          'updatedAt': now,
        },
        docId: depotId,
      );

      await loadDepots();
      return DepotCreationResult(depotId: depotId, warning: warning);
    } catch (e) {
      state = state.copyWith(isBusy: false, error: _message(e));
      return null;
    }
  }

  /// Renames a depot (neighborhood label). Needs a connection: the authoritative
  /// `depots` table is updated server side, then the local copy.
  Future<String?> updateDepot({
    required String id,
    required String name,
    required String city,
  }) async {
    if (name.trim().isEmpty) return 'Le nom du dépôt est requis.';

    state = state.copyWith(isBusy: true, error: null);
    try {
      await Supabase.instance.client.rpc('depot_update', params: {
        'p_id': id,
        'p_name': name.trim(),
        'p_city': city.trim(),
      });
      await _data.updateDocument(AppConstants.depotsCollection, id, {
        'name': name.trim(),
        'city': city.trim(),
      });
      await loadDepots();
      return null;
    } catch (e) {
      final message = _message(e);
      state = state.copyWith(isBusy: false, error: message);
      return message;
    }
  }

  /// Activates or deactivates a depot. Deactivating a depot stops new accounts
  /// from being bound to it without touching its existing staff or data.
  Future<String?> setDepotStatus(String id, String status) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      await Supabase.instance.client.rpc('depot_set_status', params: {
        'p_id': id,
        'p_status': status,
      });
      await _data.updateDocument(AppConstants.depotsCollection, id, {
        'status': status,
      });
      await loadDepots();
      return null;
    } catch (e) {
      final message = _message(e);
      state = state.copyWith(isBusy: false, error: message);
      return message;
    }
  }

  /// Deletes a depot that holds nothing. The server refuses with a clear
  /// message when the depot still has accounts or synced data; deactivate it
  /// instead in that case.
  Future<String?> deleteDepot(String id) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      await Supabase.instance.client.rpc('depot_delete', params: {'p_id': id});
      await _data.deleteDocument(AppConstants.depotsCollection, id);
      await loadDepots();
      return null;
    } catch (e) {
      final message = _message(e);
      state = state.copyWith(isBusy: false, error: message);
      return message;
    }
  }

  /// Adds an administrator to an existing depot (used when the initial creation
  /// was skipped or failed). Needs a connection. The new account is mirrored
  /// locally so it appears in the depot's detail screen without waiting for the
  /// next sync pass.
  Future<String?> createDepotAdmin({
    required String depotId,
    required String name,
    required String pin,
  }) async {
    state = state.copyWith(isBusy: true, error: null);
    final error = await _createDepotAdminRpc(
      depotId: depotId,
      name: name,
      pin: pin,
    );
    state = state.copyWith(isBusy: false, error: error);
    return error;
  }

  /// Rotates a depot account's PIN. Reuses `admin_set_pin`; the specified user
  /// must belong to a depot the caller may manage.
  Future<String?> resetUserPin({
    required String userId,
    required String pin,
  }) async {
    state = state.copyWith(isBusy: true, error: null);
    try {
      final normalizedPin = LocalFirstAuthService.normalizePin(pin);
      if (!LocalFirstAuthService.isValidPin(normalizedPin)) {
        throw Exception(
          'Le code PIN doit contenir ${LocalFirstAuthService.pinLength} chiffres.',
        );
      }
      final offlineHash = LocalAuthService.hashPin(normalizedPin);
      await Supabase.instance.client.rpc('admin_set_pin', params: {
        'p_user_id': userId,
        'p_pin': normalizedPin,
        'p_offline_pin_hash': offlineHash,
      });
      await _data.updateDocument(AppConstants.usersCollection, userId, {
        'offlinePinHash': offlineHash,
      });
      state = state.copyWith(isBusy: false, error: null);
      return null;
    } catch (e) {
      final message = _message(e);
      state = state.copyWith(isBusy: false, error: message);
      return message;
    }
  }

  /// Shared by [createDepot] and [createDepotAdmin]: validates the PIN, calls
  /// `admin_create_user` and mirrors the created account locally.
  Future<String?> _createDepotAdminRpc({
    required String depotId,
    required String name,
    required String pin,
  }) async {
    try {
      final normalizedPin = LocalFirstAuthService.normalizePin(pin);
      if (!LocalFirstAuthService.isValidPin(normalizedPin)) {
        throw Exception(
          'Le code PIN doit contenir ${LocalFirstAuthService.pinLength} chiffres.',
        );
      }
      final offlineHash = LocalAuthService.hashPin(normalizedPin);
      final result =
          await Supabase.instance.client.rpc('admin_create_user', params: {
        'p_email': 'admin_${DateTime.now().millisecondsSinceEpoch}@depot.local',
        'p_name': name.trim(),
        'p_pin': normalizedPin,
        'p_role': UserRole.admin.value,
        'p_phone': '',
        'p_data': <String, dynamic>{},
        'p_offline_pin_hash': offlineHash,
        'p_depot_id': depotId,
      });

      final id = result?['id'] as String?;
      if (id != null) {
        final now = DateTime.now().toIso8601String();
        await _data.createDocument(
          AppConstants.usersCollection,
          {
            'id': id,
            'name': name.trim(),
            'email': (result?['email'] as String?) ?? '',
            'phone': '',
            'role': UserRole.admin.value,
            'status': 'active',
            'offlinePinHash': offlineHash,
            'depotId': depotId,
            'createdAt': now,
            'updatedAt': now,
          },
          docId: id,
        );
      }
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  static String _message(Object error) {
    if (error is PostgrestException) {
      final code = error.message.toLowerCase();
      if (code.contains('superadmin_only')) {
        return 'Action réservée au superadministrateur.';
      }
      if (code.contains('depot_not_empty')) {
        return 'Ce dépôt contient encore des données. Désactivez-le au lieu de '
            'le supprimer.';
      }
      if (code.contains('depot_not_found')) {
        return 'Dépôt introuvable.';
      }
      if (code.contains('name_required')) {
        return 'Le nom du dépôt est requis.';
      }
      if (code.contains('invalid_status')) {
        return 'Statut de dépôt invalide.';
      }
      return error.message;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}

final depotProvider = StateNotifierProvider<DepotNotifier, DepotsState>((ref) {
  return DepotNotifier(ref.read(localDataServiceProvider));
});

/// The accounts bound to one depot, read straight from the local database so
/// the depot detail screen works offline. Only `users` carry `depotId` in their
/// synced payload, which is exactly what this filter needs.
final depotUsersProvider =
    FutureProvider.family.autoDispose<List<UserModel>, String>((ref, depotId) {
  return ref.read(localDataServiceProvider).getDocuments<UserModel>(
        AppConstants.usersCollection,
        UserModel.fromMap,
        where: [WhereClause(field: 'depotId', value: depotId)],
      );
});

/// Counts for one depot, from the server (`depot_stats`). Requires a connection;
/// callers surface an offline state and can retry.
final depotStatsProvider =
    FutureProvider.family.autoDispose<DepotStats, String>((ref, depotId) async {
  final result = await Supabase.instance.client
      .rpc('depot_stats', params: {'p_depot_id': depotId});
  if (result is Map) {
    return DepotStats.fromMap(Map<String, dynamic>.from(result));
  }
  return const DepotStats();
});
