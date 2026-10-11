import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/route_model.dart';
import '../models/route_status.dart';

enum RoutesStatus { initial, loading, loaded, error }

class RoutesState {
  final RoutesStatus status;
  final List<RouteModel> routes;
  final String? error;

  const RoutesState({
    this.status = RoutesStatus.initial,
    this.routes = const [],
    this.error,
  });

  RoutesState copyWith({
    RoutesStatus? status,
    List<RouteModel>? routes,
    String? error,
  }) {
    return RoutesState(
      status: status ?? this.status,
      routes: routes ?? this.routes,
      error: error,
    );
  }
}

class RouteNotifier extends StateNotifier<RoutesState> {
  RouteNotifier(this._data) : super(const RoutesState());

  final LocalDataService _data;

  /// Which scope the current list was loaded with: `null` = all routes (admin),
  /// otherwise the driver whose routes are shown. Keeps [_refresh] in sync.
  String? _driverScope;

  /// All tournées, newest first. Used by the admin list.
  Future<void> loadRoutes() async {
    state = state.copyWith(status: RoutesStatus.loading);
    try {
      final routes = await _data.getDocuments<RouteModel>(
        AppConstants.routesCollection,
        RouteModel.fromMap,
        orderBy: 'date',
        descending: true,
      );
      _driverScope = null;
      state = RoutesState(status: RoutesStatus.loaded, routes: routes);
    } catch (e) {
      state = state.copyWith(status: RoutesStatus.error, error: e.toString());
    }
  }

  /// Only the tournées assigned to [driverId], for the driver home.
  Future<void> loadDriverRoutes(String driverId) async {
    state = state.copyWith(status: RoutesStatus.loading);
    try {
      final routes = await _data.getDocuments<RouteModel>(
        AppConstants.routesCollection,
        RouteModel.fromMap,
        where: [WhereClause(field: 'driverId', value: driverId)],
        orderBy: 'date',
        descending: true,
      );
      _driverScope = driverId;
      state = RoutesState(status: RoutesStatus.loaded, routes: routes);
    } catch (e) {
      state = state.copyWith(status: RoutesStatus.error, error: e.toString());
    }
  }

  /// Creates a tournée and assigns each selected order to the driver so the
  /// existing per-order delivery flow (which filters on `driverId`) picks them
  /// up without any change.
  Future<RouteModel?> createRoute({
    required String name,
    required DateTime date,
    required String driverId,
    required String driverName,
    required List<String> orderIds,
    String? notes,
  }) async {
    state = state.copyWith(status: RoutesStatus.loading);
    try {
      final route = RouteModel(
        id: const Uuid().v4(),
        name: name,
        driverId: driverId,
        driverName: driverName,
        orderIds: orderIds,
        date: date,
        notes: notes,
      );

      await _data.createDocument(
        AppConstants.routesCollection,
        route.toMap(),
        docId: route.id,
      );

      for (final orderId in orderIds) {
        await _data.updateDocument(
          AppConstants.ordersCollection,
          orderId,
          {'driverId': driverId, 'driverName': driverName},
        );
      }

      await loadRoutes();
      return route;
    } catch (e) {
      state = state.copyWith(status: RoutesStatus.error, error: e.toString());
      return null;
    }
  }

  Future<void> updateRouteStatus(String routeId, RouteStatus status) async {
    try {
      await _data.updateDocument(
        AppConstants.routesCollection,
        routeId,
        {'status': status.value},
      );
      await _refresh();
    } catch (e) {
      state = state.copyWith(status: RoutesStatus.error, error: e.toString());
    }
  }

  Future<void> deleteRoute(String routeId) async {
    state = state.copyWith(status: RoutesStatus.loading);
    try {
      await _data.deleteDocument(AppConstants.routesCollection, routeId);
      await _refresh();
    } catch (e) {
      state = state.copyWith(status: RoutesStatus.error, error: e.toString());
    }
  }

  /// Reloads while keeping whichever scope (all vs. per-driver) is in use.
  Future<void> _refresh() async {
    final scope = _driverScope;
    if (scope != null) {
      await loadDriverRoutes(scope);
    } else {
      await loadRoutes();
    }
  }

  List<RouteModel> search(String query) {
    if (query.isEmpty) return state.routes;
    final q = query.toLowerCase();
    return state.routes
        .where((r) =>
            r.name.toLowerCase().contains(q) ||
            r.driverName.toLowerCase().contains(q))
        .toList();
  }
}

final routeProvider =
    StateNotifierProvider<RouteNotifier, RoutesState>((ref) {
  return RouteNotifier(ref.read(localDataServiceProvider));
});
