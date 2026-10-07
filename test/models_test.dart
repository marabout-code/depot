import 'package:flutter_test/flutter_test.dart';
import 'package:depot_distribution_app/models/product_model.dart';
import 'package:depot_distribution_app/models/order_model.dart';
import 'package:depot_distribution_app/models/order_status.dart';
import 'package:depot_distribution_app/models/delivery_model.dart';
import 'package:depot_distribution_app/models/delivery_status.dart';
import 'package:depot_distribution_app/models/inventory_model.dart';
import 'package:depot_distribution_app/models/driver_model.dart';
import 'package:depot_distribution_app/models/user_model.dart';
import 'package:depot_distribution_app/models/user_role.dart';
import 'package:depot_distribution_app/models/user_status.dart';

void main() {
  group('ProductModel', () {
    final product = ProductModel(
      id: 'p1',
      name: '33 Export',
      category: 'Beer',
      brand: '33',
      packageSize: '33cl',
      packQuantity: 12,
      price: 2500,
      stockQuantity: 100,
      reorderLevel: 20,
      barcode: '123456789',
    );

    test('creates with correct values', () {
      expect(product.id, 'p1');
      expect(product.name, '33 Export');
      expect(product.category, 'Beer');
      expect(product.brand, '33');
      expect(product.packageSize, '33cl');
      expect(product.packQuantity, 12);
      expect(product.price, 2500);
      expect(product.stockQuantity, 100);
      expect(product.reorderLevel, 20);
      expect(product.isActive, true);
      expect(product.barcode, '123456789');
    });

    test('serializes to and from map', () {
      final map = product.toMap();
      final deserialized = ProductModel.fromMap(map);
      expect(deserialized.id, product.id);
      expect(deserialized.name, product.name);
      expect(deserialized.category, product.category);
      expect(deserialized.brand, product.brand);
      expect(deserialized.price, product.price);
      expect(deserialized.stockQuantity, product.stockQuantity);
      expect(deserialized.barcode, product.barcode);
    });

    test('copyWith works correctly', () {
      final updated = product.copyWith(price: 3000, stockQuantity: 200);
      expect(updated.price, 3000);
      expect(updated.stockQuantity, 200);
      expect(updated.id, product.id);
    });

    test('needsReorder returns true when stock at or below reorder level', () {
      final lowStock = product.copyWith(stockQuantity: 15, reorderLevel: 20);
      expect(lowStock.needsReorder, true);
    });

    test('needsReorder returns false when stock above reorder level', () {
      expect(product.needsReorder, false);
    });

    test('displayName formats correctly', () {
      expect(product.displayName, '33 33 Export (33cl)');
    });
  });

  group('OrderStatus', () {
    test('fromString returns correct enum', () {
      expect(OrderStatus.fromString('pending'), OrderStatus.pending);
      expect(OrderStatus.fromString('delivered'), OrderStatus.delivered);
      expect(OrderStatus.fromString('cancelled'), OrderStatus.cancelled);
    });
  });

  group('OrderItem', () {
    test('calculates totalPrice correctly', () {
      final item = OrderItem(
        productId: 'p1',
        productName: '33 Export',
        quantity: 5,
        unitPrice: 2500,
      );
      expect(item.totalPrice, 12500);
    });

    test('serializes to and from map', () {
      final item = OrderItem(
        productId: 'p1',
        productName: '33 Export',
        quantity: 3,
        unitPrice: 2500,
      );
      final map = item.toMap();
      final deserialized = OrderItem.fromMap(map);
      expect(deserialized.productId, 'p1');
      expect(deserialized.quantity, 3);
      expect(deserialized.unitPrice, 2500);
    });
  });

  group('OrderModel', () {
    final order = OrderModel(
      id: 'o1',
      orderNumber: 'CMD-001',
      customerName: 'Client Test',
      customerPhone: '691234567',
      deliveryAddress: '123 Rue Principale',
      items: [
        OrderItem(productId: 'p1', productName: '33 Export', quantity: 10, unitPrice: 2500),
        OrderItem(productId: 'p2', productName: 'Mützig', quantity: 5, unitPrice: 2000),
      ],
    );

    test('creates with correct values', () {
      expect(order.id, 'o1');
      expect(order.orderNumber, 'CMD-001');
      expect(order.customerName, 'Client Test');
      expect(order.status, OrderStatus.pending);
    });

    test('calculatedTotal sums all items', () {
      expect(order.calculatedTotal, 35000);
    });

    test('totalItems sums all quantities', () {
      expect(order.totalItems, 15);
    });

    test('serializes to and from map', () {
      final map = order.toMap();
      final deserialized = OrderModel.fromMap(map);
      expect(deserialized.id, order.id);
      expect(deserialized.orderNumber, order.orderNumber);
      expect(deserialized.items.length, 2);
      expect(deserialized.calculatedTotal, 35000);
    });
  });

  group('DeliveryStatus', () {
    test('fromString returns correct enum', () {
      expect(DeliveryStatus.fromString('assigned'), DeliveryStatus.assigned);
      expect(DeliveryStatus.fromString('delivered'), DeliveryStatus.delivered);
      expect(DeliveryStatus.fromString('in_transit'), DeliveryStatus.inTransit);
    });
  });

  group('DeliveryModel', () {
    final delivery = DeliveryModel(
      id: 'd1',
      orderId: 'o1',
      orderNumber: 'CMD-001',
      driverId: 'drv1',
      driverName: 'Jean Driver',
      customerName: 'Client Test',
      customerPhone: '691234567',
      deliveryAddress: '123 Rue Principale',
      location: DeliveryLocation(latitude: 3.8667, longitude: 11.5167, address: '123 Rue Principale'),
    );

    test('creates with correct values', () {
      expect(delivery.id, 'd1');
      expect(delivery.driverId, 'drv1');
      expect(delivery.status, DeliveryStatus.assigned);
      expect(delivery.location!.latitude, 3.8667);
    });

    test('serializes to and from map', () {
      final map = delivery.toMap();
      final deserialized = DeliveryModel.fromMap(map);
      expect(deserialized.id, delivery.id);
      expect(deserialized.orderId, delivery.orderId);
      expect(deserialized.location!.latitude, delivery.location!.latitude);
    });
  });

  group('MovementType', () {
    test('fromString returns correct enum', () {
      expect(MovementType.fromString('stock_in'), MovementType.stockIn);
      expect(MovementType.fromString('stock_out'), MovementType.stockOut);
      expect(MovementType.fromString('damage'), MovementType.damage);
    });
  });

  group('InventoryModel', () {
    final inv = InventoryModel(
      id: 'inv1',
      productId: 'p1',
      productName: '33 Export',
      currentStock: 150,
      reservedQuantity: 20,
      availableQuantity: 130,
      location: 'Entrepôt A',
    );

    test('creates with correct values', () {
      expect(inv.id, 'inv1');
      expect(inv.productId, 'p1');
      expect(inv.currentStock, 150);
      expect(inv.reservedQuantity, 20);
      expect(inv.availableQuantity, 130);
      expect(inv.location, 'Entrepôt A');
    });

    test('serializes to and from map', () {
      final map = inv.toMap();
      final deserialized = InventoryModel.fromMap(map);
      expect(deserialized.id, inv.id);
      expect(deserialized.currentStock, inv.currentStock);
      expect(deserialized.location, inv.location);
    });
  });

  group('InventoryMovement', () {
    final movement = InventoryMovement(
      id: 'm1',
      productId: 'p1',
      productName: '33 Export',
      type: MovementType.stockIn,
      quantity: 50,
      quantityBefore: 100,
      quantityAfter: 150,
      performedBy: 'Admin',
      notes: 'Livraison fournisseur',
    );

    test('creates with correct values', () {
      expect(movement.id, 'm1');
      expect(movement.type, MovementType.stockIn);
      expect(movement.quantity, 50);
      expect(movement.quantityBefore, 100);
      expect(movement.quantityAfter, 150);
    });

    test('serializes to and from map', () {
      final map = movement.toMap();
      final deserialized = InventoryMovement.fromMap(map);
      expect(deserialized.id, movement.id);
      expect(deserialized.type, movement.type);
      expect(deserialized.quantity, movement.quantity);
      expect(deserialized.notes, 'Livraison fournisseur');
    });
  });

  group('Vehicle', () {
    test('creates with correct values', () {
      final v = Vehicle(type: 'Truck', plateNumber: 'LT123AB', color: 'Blanc');
      expect(v.type, 'Truck');
      expect(v.plateNumber, 'LT123AB');
      expect(v.color, 'Blanc');
    });

    test('serializes to and from map', () {
      final v = Vehicle(type: 'Motorcycle', plateNumber: 'MT456CD', color: 'Rouge');
      final map = v.toMap();
      final d = Vehicle.fromMap(map);
      expect(d.type, 'Motorcycle');
      expect(d.plateNumber, 'MT456CD');
    });
  });

  group('Availability', () {
    test('defaults to available', () {
      final a = Availability();
      expect(a.isAvailable, true);
      expect(a.lastLocation, isNull);
      expect(a.lastUpdated, isNull);
    });

    test('serializes to and from map', () {
      final a = Availability(
        isAvailable: false,
        lastLocation: const DriverLocation(latitude: 3.8667, longitude: 11.5167),
        lastUpdated: DateTime(2026, 7, 3),
      );
      final map = a.toMap();
      final d = Availability.fromMap(map);
      expect(d.isAvailable, false);
      expect(d.lastLocation!.latitude, 3.8667);
      expect(d.lastLocation!.longitude, 11.5167);
    });
  });

  group('Performance', () {
    test('defaults to zero', () {
      final p = Performance();
      expect(p.totalDeliveries, 0);
      expect(p.averageRating, 0.0);
      expect(p.totalEarnings, 0.0);
      expect(p.completedOrders, 0);
    });

    test('serializes to and from map', () {
      final p = Performance(
        totalDeliveries: 42,
        averageRating: 4.5,
        totalEarnings: 250000.0,
        completedOrders: 38,
      );
      final map = p.toMap();
      final d = Performance.fromMap(map);
      expect(d.totalDeliveries, 42);
      expect(d.averageRating, 4.5);
      expect(d.totalEarnings, 250000.0);
      expect(d.completedOrders, 38);
    });
  });

  group('DriverModel', () {
    final driver = DriverModel(
      id: 'drv1',
      name: 'Jean Driver',
      email: 'jean@example.com',
      phone: '691234567',
      pinCode: '1234',
      vehicle: Vehicle(type: 'Truck', plateNumber: 'LT789EF', color: 'Bleu'),
      availability: Availability(
        isAvailable: true,
        lastLocation: const DriverLocation(latitude: 3.8667, longitude: 11.5167),
      ),
      performance: Performance(
        totalDeliveries: 15,
        averageRating: 4.2,
        totalEarnings: 120000.0,
        completedOrders: 13,
      ),
      commissionRate: 8.5,
    );

    test('extends UserModel with correct inherited fields', () {
      expect(driver.id, 'drv1');
      expect(driver.name, 'Jean Driver');
      expect(driver.email, 'jean@example.com');
      expect(driver.role, UserRole.driver);
      expect(driver.status, UserStatus.active);
      expect(driver.pinCode, '1234');
    });

    test('has driver-specific fields', () {
      expect(driver.vehicle.type, 'Truck');
      expect(driver.vehicle.plateNumber, 'LT789EF');
      expect(driver.availability.isAvailable, true);
      expect(driver.availability.lastLocation!.latitude, 3.8667);
      expect(driver.performance.totalDeliveries, 15);
      expect(driver.performance.averageRating, 4.2);
      expect(driver.performance.totalEarnings, 120000.0);
      expect(driver.commissionRate, 8.5);
    });

    test('serializes to and from map', () {
      final map = driver.toMap();
      final d = DriverModel.fromMap(map);
      expect(d.id, driver.id);
      expect(d.name, driver.name);
      expect(d.vehicle.type, driver.vehicle.type);
      expect(d.vehicle.plateNumber, driver.vehicle.plateNumber);
      expect(d.availability.isAvailable, driver.availability.isAvailable);
      expect(d.performance.totalDeliveries, driver.performance.totalDeliveries);
      expect(d.commissionRate, driver.commissionRate);
    });

    test('fromUserModel creates DriverModel with defaults', () {
      final user = UserModel(
        id: 'u1',
        name: 'Test User',
        email: 'test@example.com',
        pinCode: '4321',
      );
      final d = DriverModel.fromUserModel(user);
      expect(d.id, 'u1');
      expect(d.name, 'Test User');
      expect(d.vehicle.type, '');
      expect(d.availability.isAvailable, true);
      expect(d.performance.totalDeliveries, 0);
      expect(d.commissionRate, 10.0);
    });

    test('fromUserModel accepts overrides', () {
      final user = UserModel(id: 'u2', name: 'Override', email: 'o@example.com');
      final d = DriverModel.fromUserModel(
        user,
        vehicle: Vehicle(type: 'Car', plateNumber: 'AB123CD', color: 'Noir'),
        commissionRate: 5.0,
      );
      expect(d.vehicle.type, 'Car');
      expect(d.commissionRate, 5.0);
    });

    test('copyWith works correctly', () {
      final updated = driver.copyWith(
        commissionRate: 10.0,
        vehicle: Vehicle(type: 'Motorcycle', plateNumber: 'NEW', color: 'Rouge'),
      );
      expect(updated.commissionRate, 10.0);
      expect(updated.vehicle.type, 'Motorcycle');
      expect(updated.id, driver.id);
      expect(updated.performance.totalDeliveries, driver.performance.totalDeliveries);
    });
  });
}
