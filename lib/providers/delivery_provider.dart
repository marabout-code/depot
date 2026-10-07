import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import '../models/delivery_model.dart';
import '../models/delivery_status.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';

enum DriverDeliveriesStatus { initial, loading, loaded, error, updating }

class DriverDeliveriesState {
  final DriverDeliveriesStatus status;
  final List<OrderModel> orders;
  final List<DeliveryModel> deliveries;
  final DriverModel? driverProfile;
  final String? error;

  const DriverDeliveriesState({
    this.status = DriverDeliveriesStatus.initial,
    this.orders = const [],
    this.deliveries = const [],
    this.driverProfile,
    this.error,
  });

  DriverDeliveriesState copyWith({
    DriverDeliveriesStatus? status,
    List<OrderModel>? orders,
    List<DeliveryModel>? deliveries,
    DriverModel? driverProfile,
    String? error,
  }) {
    return DriverDeliveriesState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      deliveries: deliveries ?? this.deliveries,
      driverProfile: driverProfile ?? this.driverProfile,
      error: error,
    );
  }

  List<OrderModel> get activeOrders =>
      orders.where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled).toList();

  List<OrderModel> get completedOrders =>
      orders.where((o) => o.status == OrderStatus.delivered).toList();
}

class DeliveryNotifier extends StateNotifier<DriverDeliveriesState> {
  final LocalDataService _data;

  DeliveryNotifier(this._data) : super(const DriverDeliveriesState());

  Future<void> loadDriverData(String driverId) async {
    state = state.copyWith(status: DriverDeliveriesStatus.loading);
    try {
      final results = await Future.wait([
        _data.getDocuments<OrderModel>(
          AppConstants.ordersCollection,
          OrderModel.fromMap,
          where: [WhereClause(field: 'driverId', value: driverId)],
          orderBy: 'createdAt',
          descending: true,
        ),
        _data.getDocuments<DeliveryModel>(
          AppConstants.deliveriesCollection,
          DeliveryModel.fromMap,
          where: [WhereClause(field: 'driverId', value: driverId)],
          orderBy: 'createdAt',
          descending: true,
        ),
        _data.getDocument<UserModel>(
          AppConstants.usersCollection,
          driverId,
          UserModel.fromMap,
          throwOnNotFound: false,
        ),
      ]);

      final orders = results[0] as List<OrderModel>;
      final deliveries = results[1] as List<DeliveryModel>;
      final userDoc = results[2] as UserModel?;

      DriverModel? driverProfile;
      if (userDoc != null) {
        final driverDoc = await _data.getDocument<UserModel>(
          AppConstants.usersCollection,
          driverId,
          UserModel.fromMap,
          throwOnNotFound: false,
        );
        if (driverDoc != null) {
          final raw = await _data.getDocument<Map<String, dynamic>>(
            AppConstants.usersCollection,
            driverId,
            (m) => m,
            throwOnNotFound: false,
          );
          if (raw != null) {
            driverProfile = DriverModel.fromMap(raw);
          }
        }
      }

      state = DriverDeliveriesState(
        status: DriverDeliveriesStatus.loaded,
        orders: orders,
        deliveries: deliveries,
        driverProfile: driverProfile,
      );
    } catch (e) {
      state = state.copyWith(
        status: DriverDeliveriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> pickUpOrder(OrderModel order) async {
    state = state.copyWith(status: DriverDeliveriesStatus.updating);
    try {
      final now = DateTime.now();
      await _data.updateDocument(
        AppConstants.ordersCollection,
        order.id,
        {'status': OrderStatus.outForDelivery.value},
      );

      final deliveryId = 'del_${order.id}';
      await _data.createDocument(
        AppConstants.deliveriesCollection,
        DeliveryModel(
          id: deliveryId,
          orderId: order.id,
          orderNumber: order.orderNumber,
          driverId: order.driverId ?? '',
          driverName: order.driverName ?? '',
          customerName: order.customerName,
          customerPhone: order.customerPhone,
          deliveryAddress: order.deliveryAddress,
          status: DeliveryStatus.pickedUp,
          pickedUpAt: now,
          notes: order.notes,
        ).toMap(),
        docId: deliveryId,
      );

      await loadDriverData(order.driverId ?? '');
    } catch (e) {
      state = state.copyWith(
        status: DriverDeliveriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> startDelivery(OrderModel order) async {
    state = state.copyWith(status: DriverDeliveriesStatus.updating);
    try {
      final deliveryId = 'del_${order.id}';
      await _data.updateDocument(
        AppConstants.deliveriesCollection,
        deliveryId,
        {'status': DeliveryStatus.inTransit.value},
      );
      await loadDriverData(order.driverId ?? '');
    } catch (e) {
      state = state.copyWith(
        status: DriverDeliveriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> completeDelivery(OrderModel order) async {
    state = state.copyWith(status: DriverDeliveriesStatus.updating);
    try {
      final now = DateTime.now();
      await _data.updateDocument(
        AppConstants.ordersCollection,
        order.id,
        {'status': OrderStatus.delivered.value, 'deliveredAt': now.toIso8601String()},
      );

      final deliveryId = 'del_${order.id}';
      await _data.updateDocument(
        AppConstants.deliveriesCollection,
        deliveryId,
        {'status': DeliveryStatus.delivered.value, 'deliveredAt': now.toIso8601String()},
      );

      await _updateDriverPerformance(order.driverId ?? '', order.totalAmount > 0 ? order.totalAmount : order.calculatedTotal);
      await loadDriverData(order.driverId ?? '');
    } catch (e) {
      state = state.copyWith(
        status: DriverDeliveriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> failDelivery(OrderModel order, String reason) async {
    state = state.copyWith(status: DriverDeliveriesStatus.updating);
    try {
      final deliveryId = 'del_${order.id}';
      await _data.updateDocument(
        AppConstants.deliveriesCollection,
        deliveryId,
        {'status': DeliveryStatus.failed.value, 'notes': reason},
      );
      await loadDriverData(order.driverId ?? '');
    } catch (e) {
      state = state.copyWith(
        status: DriverDeliveriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> _updateDriverPerformance(String driverId, double orderAmount) async {
    try {
      final doc = await _data.getDocument<Map<String, dynamic>>(
        AppConstants.usersCollection,
        driverId,
        (m) => m,
        throwOnNotFound: false,
      );
      if (doc == null) return;

      final perf = doc['performance'] as Map<String, dynamic>? ?? {};
      final totalDel = ((perf['totalDeliveries'] as num?)?.toInt() ?? 0) + 1;
      final completed = ((perf['completedOrders'] as num?)?.toInt() ?? 0) + 1;
      final earnings = ((perf['totalEarnings'] as num?)?.toDouble() ?? 0) + (orderAmount * 0.1);

      await _data.updateDocument(
        AppConstants.usersCollection,
        driverId,
        {
          'performance': {
            'totalDeliveries': totalDel,
            'completedOrders': completed,
            'totalEarnings': earnings,
            'averageRating': (perf['averageRating'] as num?)?.toDouble() ?? 0.0,
          }
        },
      );
    } catch (_) {}
  }
}

final driverDeliveriesProvider =
    StateNotifierProvider<DeliveryNotifier, DriverDeliveriesState>((ref) {
  return DeliveryNotifier(ref.read(localDataServiceProvider));
});
