import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/database/local_auth_service.dart';
import '../core/database/local_data_service.dart';
import '../core/services/local_first_auth_service.dart';
import '../models/depot_model.dart';

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
  final bool isCreating;

  const DepotsState({
    this.status = DepotsStatus.initial,
    this.depots = const [],
    this.error,
    this.isCreating = false,
  });

  DepotsState copyWith({
    DepotsStatus? status,
    List<DepotModel>? depots,
    String? error,
    bool? isCreating,
  }) {
    return DepotsState(
      status: status ?? this.status,
      depots: depots ?? this.depots,
      error: error,
      isCreating: isCreating ?? this.isCreating,
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
    required String address,
    String? adminName,
    String? adminPin,
  }) async {
    state = state.copyWith(isCreating: true, error: null);
    try {
      final client = Supabase.instance.client;

      final result = await client.rpc('depot_create', params: {
        'p_name': name.trim(),
        'p_city': city.trim(),
        'p_address': address.trim(),
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
        try {
          final normalizedPin =
              LocalFirstAuthService.normalizePin(adminPin);
          final offlineHash =
              LocalAuthService.hashPin(normalizedPin);
          await client.rpc('admin_create_user', params: {
            'p_email':
                'admin_${DateTime.now().millisecondsSinceEpoch}@depot.local',
            'p_name': adminName.trim(),
            'p_pin': normalizedPin,
            'p_role': 'admin',
            'p_phone': '',
            'p_data': <String, dynamic>{},
            'p_offline_pin_hash': offlineHash,
            'p_depot_id': depotId,
          });
        } on PostgrestException catch (e) {
          warning =
              "Dépôt créé, mais échec de la création de l'administrateur : "
              '${e.message}';
        }
      }

      final now = DateTime.now().toIso8601String();
      await _data.createDocument(
        AppConstants.depotsCollection,
        {
          'id': depotId,
          'name': name.trim(),
          'city': city.trim(),
          'address': address.trim(),
          'status': 'active',
          'createdAt': now,
          'updatedAt': now,
        },
        docId: depotId,
      );

      await loadDepots();
      return DepotCreationResult(depotId: depotId, warning: warning);
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return null;
    }
  }

  /// Adds an administrator to an existing depot (used when the initial creation
  /// was skipped or failed). Needs a connection.
  Future<String?> createDepotAdmin({
    required String depotId,
    required String name,
    required String pin,
  }) async {
    state = state.copyWith(isCreating: true, error: null);
    try {
      final normalizedPin = LocalFirstAuthService.normalizePin(pin);
      if (!LocalFirstAuthService.isValidPin(normalizedPin)) {
        throw Exception(
          'Le code PIN doit contenir ${LocalFirstAuthService.pinLength} chiffres.',
        );
      }
      final offlineHash = LocalAuthService.hashPin(normalizedPin);
      await Supabase.instance.client.rpc('admin_create_user', params: {
        'p_email':
            'admin_${DateTime.now().millisecondsSinceEpoch}@depot.local',
        'p_name': name.trim(),
        'p_pin': normalizedPin,
        'p_role': 'admin',
        'p_phone': '',
        'p_data': <String, dynamic>{},
        'p_offline_pin_hash': offlineHash,
        'p_depot_id': depotId,
      });
      return null;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      state = state.copyWith(isCreating: false);
    }
  }
}

final depotProvider = StateNotifierProvider<DepotNotifier, DepotsState>((ref) {
  return DepotNotifier(ref.read(localDataServiceProvider));
});