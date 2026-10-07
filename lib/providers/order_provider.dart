import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';

enum OrdersStatus { initial, loading, loaded, error }

class OrdersState {
  final OrdersStatus status;
  final List<OrderModel> orders;
  final String? error;

  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.error,
  });

  OrdersState copyWith({
    OrdersStatus? status,
    List<OrderModel>? orders,
    String? error,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      error: error,
    );
  }
}

class OrderNotifier extends StateNotifier<OrdersState> {
  final LocalDataService _data;

  OrderNotifier(this._data) : super(const OrdersState());

  Future<void> loadOrders() async {
    state = state.copyWith(status: OrdersStatus.loading);
    try {
      final orders = await _data.getDocuments<OrderModel>(
        AppConstants.ordersCollection,
        OrderModel.fromMap,
        orderBy: 'createdAt',
        descending: true,
      );
      state = OrdersState(
        status: OrdersStatus.loaded,
        orders: orders,
      );
    } catch (e) {
      state = state.copyWith(
        status: OrdersStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> createOrder(OrderModel order) async {
    state = state.copyWith(status: OrdersStatus.loading);
    try {
      await _data.createDocument(
        AppConstants.ordersCollection,
        order.toMap(),
        docId: order.id,
      );
      await loadOrders();
    } catch (e) {
      state = state.copyWith(
        status: OrdersStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'status': newStatus.value,
      if (newStatus == OrderStatus.delivered) 'deliveredAt': now.toIso8601String(),
    };
    try {
      await _data.updateDocument(
        AppConstants.ordersCollection,
        orderId,
        data,
      );
      await loadOrders();
    } catch (e) {
      state = state.copyWith(
        status: OrdersStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> assignDriver(String orderId, String driverId, String driverName) async {
    try {
      await _data.updateDocument(
        AppConstants.ordersCollection,
        orderId,
        {'driverId': driverId, 'driverName': driverName},
      );
      await loadOrders();
    } catch (e) {
      state = state.copyWith(
        status: OrdersStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  List<OrderModel> filterByStatus(OrderStatus? status) {
    if (status == null) return state.orders;
    return state.orders.where((o) => o.status == status).toList();
  }

  List<OrderModel> search(String query) {
    if (query.isEmpty) return state.orders;
    final q = query.toLowerCase();
    return state.orders.where((o) {
      return o.orderNumber.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.customerPhone?.toLowerCase().contains(q) == true;
    }).toList();
  }
}

final orderProvider =
    StateNotifierProvider<OrderNotifier, OrdersState>((ref) {
  return OrderNotifier(ref.read(localDataServiceProvider));
});
