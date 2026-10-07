import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import '../models/product_model.dart';
import '../models/inventory_model.dart';
import '../models/driver_model.dart';
import '../models/user_model.dart';

class TopProduct {
  final String productId;
  final String productName;
  final int totalQuantity;
  final double totalRevenue;

  TopProduct({
    required this.productId,
    required this.productName,
    required this.totalQuantity,
    required this.totalRevenue,
  });
}

class TopDriver {
  final String driverId;
  final String driverName;
  final int deliveries;
  final double earnings;
  final double rating;

  TopDriver({
    required this.driverId,
    required this.driverName,
    required this.deliveries,
    required this.earnings,
    required this.rating,
  });
}

class ReportData {
  // Orders / Sales
  final int totalOrders;
  final int pendingOrders;
  final int confirmedOrders;
  final int preparingOrders;
  final int outForDeliveryOrders;
  final int deliveredOrders;
  final int cancelledOrders;
  final double totalRevenue;
  final double todayRevenue;
  final double weekRevenue;
  final double monthRevenue;
  final List<TopProduct> topProducts;

  // Inventory
  final int totalInventoryItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalStockValue;
  final int stockInTotal;
  final int stockOutTotal;
  final int damageTotal;

  // Drivers
  final int totalDrivers;
  final int availableDrivers;
  final double averageDriverRating;
  final double totalDriverEarnings;
  final List<TopDriver> topDrivers;

  const ReportData({
    this.totalOrders = 0,
    this.pendingOrders = 0,
    this.confirmedOrders = 0,
    this.preparingOrders = 0,
    this.outForDeliveryOrders = 0,
    this.deliveredOrders = 0,
    this.cancelledOrders = 0,
    this.totalRevenue = 0,
    this.todayRevenue = 0,
    this.weekRevenue = 0,
    this.monthRevenue = 0,
    this.topProducts = const [],
    this.totalInventoryItems = 0,
    this.lowStockItems = 0,
    this.outOfStockItems = 0,
    this.totalStockValue = 0,
    this.stockInTotal = 0,
    this.stockOutTotal = 0,
    this.damageTotal = 0,
    this.totalDrivers = 0,
    this.availableDrivers = 0,
    this.averageDriverRating = 0,
    this.totalDriverEarnings = 0,
    this.topDrivers = const [],
  });
}

enum ReportsStatus { initial, loading, loaded, error }

class ReportsState {
  final ReportsStatus status;
  final ReportData data;
  final String? error;

  const ReportsState({
    this.status = ReportsStatus.initial,
    this.data = const ReportData(),
    this.error,
  });

  ReportsState copyWith({
    ReportsStatus? status,
    ReportData? data,
    String? error,
  }) {
    return ReportsState(
      status: status ?? this.status,
      data: data ?? this.data,
      error: error,
    );
  }
}

class ReportNotifier extends StateNotifier<ReportsState> {
  final LocalDataService _data;

  ReportNotifier(this._data) : super(const ReportsState());

  Future<void> loadReports() async {
    state = state.copyWith(status: ReportsStatus.loading);
    try {
      final results = await Future.wait([
        _data.getDocuments<OrderModel>(
          AppConstants.ordersCollection,
          OrderModel.fromMap,
          orderBy: 'createdAt',
          descending: true,
        ),
        _data.getDocuments<ProductModel>(
          AppConstants.productsCollection,
          ProductModel.fromMap,
        ),
        _data.getDocuments<InventoryModel>(
          AppConstants.inventoryCollection,
          InventoryModel.fromMap,
        ),
        _data.getDocuments<InventoryMovement>(
          AppConstants.movementsCollection,
          InventoryMovement.fromMap,
          orderBy: 'createdAt',
          descending: true,
        ),
        _data.getDocuments<UserModel>(
          AppConstants.usersCollection,
          UserModel.fromMap,
          where: [WhereClause(field: 'role', value: 'driver')],
        ),
      ]);

      final orders = results[0] as List<OrderModel>;
      final products = results[1] as List<ProductModel>;
      final inventory = results[2] as List<InventoryModel>;
      final movements = results[3] as List<InventoryMovement>;
      final driverUsers = results[4] as List<UserModel>;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekStartDay = DateTime(weekStart.year, weekStart.month, weekStart.day);
      final monthStart = DateTime(now.year, now.month, 1);

      int pending = 0, confirmed = 0, preparing = 0, outFor = 0, delivered = 0, cancelled = 0;
      double totalRev = 0, todayRev = 0, weekRev = 0, monthRev = 0;
      final productQtys = <String, int>{};
      final productNames = <String, String>{};
      final productRev = <String, double>{};

      for (final o in orders) {
        switch (o.status) {
          case OrderStatus.pending: pending++; break;
          case OrderStatus.confirmed: confirmed++; break;
          case OrderStatus.preparing: preparing++; break;
          case OrderStatus.outForDelivery: outFor++; break;
          case OrderStatus.delivered: delivered++; break;
          case OrderStatus.cancelled: cancelled++; break;
        }
        final rev = o.totalAmount > 0 ? o.totalAmount : o.calculatedTotal;
        totalRev += rev;

        final created = o.createdAt;
        if (created.isAfter(todayStart)) {
          todayRev += rev;
        }
        if (created.isAfter(weekStartDay)) {
          weekRev += rev;
        }
        if (created.isAfter(monthStart)) {
          monthRev += rev;
        }

        if (o.status == OrderStatus.delivered) {
          for (final item in o.items) {
            productQtys.update(
              item.productId,
              (v) => v + item.quantity,
              ifAbsent: () => item.quantity,
            );
            productNames[item.productId] = item.productName;
            productRev.update(
              item.productId,
              (v) => v + item.totalPrice,
              ifAbsent: () => item.totalPrice,
            );
          }
        }
      }

      final topProductsList = productQtys.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topProducts = topProductsList.take(5).map((e) => TopProduct(
        productId: e.key,
        productName: productNames[e.key] ?? '',
        totalQuantity: e.value,
        totalRevenue: productRev[e.key] ?? 0,
      )).toList();

      int totalInv = 0, lowStock = 0, outOfStock = 0;
      double stockVal = 0;
      final productMap = {for (final p in products) p.id: p};

      for (final inv in inventory) {
        totalInv++;
        final stock = inv.availableQuantity > 0 ? inv.availableQuantity : inv.currentStock;
        if (stock <= 0) {
          outOfStock++;
        } else {
          final product = productMap[inv.productId];
          if (product != null && stock <= product.reorderLevel) {
            lowStock++;
          }
        }
        if (productMap[inv.productId] != null) {
          stockVal += stock * productMap[inv.productId]!.price;
        }
      }

      int stockInQty = 0, stockOutQty = 0, damageQty = 0;
      for (final m in movements) {
        switch (m.type) {
          case MovementType.stockIn:
          case MovementType.returnItem:
            stockInQty += m.quantity;
            break;
          case MovementType.stockOut:
            stockOutQty += m.quantity;
            break;
          case MovementType.damage:
            damageQty += m.quantity;
            break;
          case MovementType.adjustment:
            break;
        }
      }

      final drivers = driverUsers.map((u) => DriverModel.fromUserModel(u)).toList();
      int availDrivers = 0;
      double totalRating = 0;
      double totalEarnings = 0;
      int ratingCount = 0;
      final driverStats = <TopDriver>[];

      for (final d in drivers) {
        if (d.availability.isAvailable) availDrivers++;
        if (d.performance.averageRating > 0) {
          totalRating += d.performance.averageRating;
          ratingCount++;
        }
        totalEarnings += d.performance.totalEarnings;
        driverStats.add(TopDriver(
          driverId: d.id,
          driverName: d.name,
          deliveries: d.performance.totalDeliveries,
          earnings: d.performance.totalEarnings,
          rating: d.performance.averageRating,
        ));
      }
      driverStats.sort((a, b) => b.deliveries.compareTo(a.deliveries));
      final topDriversList = driverStats.take(5).toList();

      final data = ReportData(
        totalOrders: orders.length,
        pendingOrders: pending,
        confirmedOrders: confirmed,
        preparingOrders: preparing,
        outForDeliveryOrders: outFor,
        deliveredOrders: delivered,
        cancelledOrders: cancelled,
        totalRevenue: totalRev,
        todayRevenue: todayRev,
        weekRevenue: weekRev,
        monthRevenue: monthRev,
        topProducts: topProducts,
        totalInventoryItems: totalInv,
        lowStockItems: lowStock,
        outOfStockItems: outOfStock,
        totalStockValue: stockVal,
        stockInTotal: stockInQty,
        stockOutTotal: stockOutQty,
        damageTotal: damageQty,
        totalDrivers: drivers.length,
        availableDrivers: availDrivers,
        averageDriverRating: ratingCount > 0 ? totalRating / ratingCount : 0,
        totalDriverEarnings: totalEarnings,
        topDrivers: topDriversList,
      );

      state = ReportsState(status: ReportsStatus.loaded, data: data);
    } catch (e) {
      state = state.copyWith(status: ReportsStatus.error, error: e.toString());
    }
  }
}

final reportProvider =
    StateNotifierProvider<ReportNotifier, ReportsState>((ref) {
  return ReportNotifier(ref.read(localDataServiceProvider));
});
