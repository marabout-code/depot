import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../../models/category_model.dart';
import '../../models/delivery_model.dart';
import '../../models/delivery_status.dart';
import '../../models/depot_model.dart';
import '../../models/driver_model.dart';
import '../../models/inventory_model.dart';
import '../../models/order_model.dart';
import '../../models/order_status.dart';
import '../../models/product_model.dart';
import '../../models/route_model.dart';
import '../../models/route_status.dart';
import '../../models/user_role.dart';
import '../../models/user_status.dart';

final demoDataServiceProvider = Provider<DemoDataService>((ref) {
  return DemoDataService(ref.read(appDatabaseProvider));
});

/// Fills the local database with a fixed, realistic sample dataset for
/// demonstrations, and removes exactly those rows again when switched off.
///
/// Every demo document carries a `demo: true` marker in its payload and is
/// written with `dirty = false`, so:
///
///   * the sync engine never pushes demo rows to Supabase (a demo must not
///     pollute the shared depot database), and
///   * switching the demo off deletes only the marked rows, leaving any real
///     data on the device untouched.
class DemoDataService {
  DemoDataService(this._db);

  final AppDatabase _db;

  static const String _marker = 'demo';

  /// True when at least one demo document is present.
  Future<bool> isSeeded() async {
    final rows = await _db.select(_db.documents).get();
    return rows.any(_isDemo);
  }

  /// Replaces any existing demo dataset with a fresh copy. Idempotent.
  Future<int> seed() async {
    await clear();
    final rows = _build();

    await _db.transaction(() async {
      for (final row in rows) {
        await _db.into(_db.documents).insert(
              DocumentsCompanion.insert(
                collection: row.collection,
                docId: row.docId,
                payload: encodePayload({
                  ...row.data,
                  'id': row.docId,
                  _marker: true,
                }),
                version: const Value(1),
                localUpdatedAt: DateTime.now(),
                dirty: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });
    return rows.length;
  }

  /// Deletes every demo document. Returns how many rows were removed.
  Future<int> clear() async {
    final rows = await _db.select(_db.documents).get();
    final demo = rows.where(_isDemo).toList();
    if (demo.isEmpty) return 0;

    await _db.transaction(() async {
      for (final row in demo) {
        await (_db.delete(_db.documents)
              ..where((d) =>
                  d.collection.equals(row.collection) &
                  d.docId.equals(row.docId)))
            .go();
      }
    });
    return demo.length;
  }

  static bool _isDemo(Document row) {
    try {
      return decodePayload(row.payload)[_marker] == true;
    } catch (_) {
      return false;
    }
  }

  List<_DemoRow> _build() {
    final now = DateTime.now();
    final rows = <_DemoRow>[];

    void add(String collection, String docId, Map<String, dynamic> data) {
      rows.add(_DemoRow(collection: collection, docId: docId, data: data));
    }

    // --- Dépôt ---
    add(
      'depots',
      'demo_depot_1',
      DepotModel(
        id: 'demo_depot_1',
        name: 'Dépôt Central Démo',
        city: 'Douala',
        address: 'Rue des Palmiers, Bonabéri',
        createdAt: now,
      ).toMap(),
    );

    // --- Catégories ---
    final categories = [
      CategoryModel(id: 'demo_cat_gazeuse', name: 'Boissons gazeuses'),
      CategoryModel(id: 'demo_cat_eau', name: 'Eaux minérales'),
      CategoryModel(id: 'demo_cat_biere', name: 'Bières'),
      CategoryModel(id: 'demo_cat_jus', name: 'Jus & énergies'),
    ];
    for (final c in categories) {
      add('categories', c.id, c.toMap());
    }

    // --- Produits ---
    final products = <ProductModel>[
      _product('demo_prod_1', 'Coca-Cola', 'Coca-Cola', 'Boissons gazeuses',
          '1.5 L', 6, 600, 450, 120, 24, '6001066001234'),
      _product('demo_prod_2', 'Fanta Orange', 'Fanta', 'Boissons gazeuses',
          '1.5 L', 6, 600, 450, 80, 24, '6001066002340'),
      _product('demo_prod_3', 'Sprite', 'Sprite', 'Boissons gazeuses', '1.5 L',
          6, 600, 450, 60, 24, '6001066003456'),
      _product('demo_prod_4', 'Djino Cocktail', 'Djino', 'Jus & énergies', '1 L',
          12, 700, 500, 40, 12, '6001066004562'),
      _product('demo_prod_5', 'Eau Minérale Tangui', 'Tangui',
          'Eaux minérales', '1.5 L', 6, 400, 250, 200, 48, '6001066005678'),
      _product('demo_prod_6', 'Source du Pays', 'Source du Pays',
          'Eaux minérales', '0.5 L', 12, 300, 180, 15, 24, '6001066006784'),
      _product('demo_prod_7', 'Castel Beer', 'Castel', 'Bières', '65 cl', 12,
          700, 500, 96, 24, '6001066007890'),
      _product('demo_prod_8', '33 Export', '33 Export', 'Bières', '65 cl', 12,
          700, 500, 0, 24, '6001066008906'),
      _product('demo_prod_9', 'Malta Guinness', 'Guinness', 'Jus & énergies',
          '33 cl', 24, 800, 600, 48, 12, '6001066009012'),
      _product('demo_prod_10', 'Coca-Cola Canette', 'Coca-Cola',
          'Boissons gazeuses', '33 cl', 24, 500, 350, 144, 36, '6001066010128'),
    ];
    for (final p in products) {
      add('products', p.id, p.toMap());
    }

    // --- Inventaire ---
    for (final p in products) {
      final inv = InventoryModel(
        id: 'demo_inv_${p.id}',
        productId: p.id,
        productName: p.displayName,
        currentStock: p.stockQuantity,
        availableQuantity: p.stockQuantity,
        unitCost: p.cost,
        location: 'Entrepôt principal',
      );
      add('inventory', inv.id, inv.toMap());
    }

    // --- Mouvements de stock ---
    final movements = [
      InventoryMovement(
        id: 'demo_mov_1',
        productId: 'demo_prod_1',
        productName: 'Coca-Cola Coca-Cola (1.5 L)',
        type: MovementType.stockIn,
        quantity: 120,
        quantityBefore: 0,
        quantityAfter: 120,
        performedBy: 'Admin Démo',
        notes: 'Réception fournisseur',
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      InventoryMovement(
        id: 'demo_mov_2',
        productId: 'demo_prod_8',
        productName: '33 Export 33 Export (65 cl)',
        type: MovementType.stockOut,
        quantity: 48,
        quantityBefore: 48,
        quantityAfter: 0,
        performedBy: 'Admin Démo',
        notes: 'Commande CMD-D003',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      InventoryMovement(
        id: 'demo_mov_3',
        productId: 'demo_prod_6',
        productName: 'Source du Pays Source du Pays (0.5 L)',
        type: MovementType.damage,
        quantity: 5,
        quantityBefore: 20,
        quantityAfter: 15,
        performedBy: 'Admin Démo',
        notes: 'Casiers cassés',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ];
    for (final m in movements) {
      add('movements', m.id, m.toMap());
    }

    // --- Conducteurs ---
    final drivers = <DriverModel>[
      DriverModel(
        id: 'demo_driver_1',
        name: 'Jean Mbarga',
        email: 'jean.mbarga@demo.local',
        phone: '+237 690 11 22 33',
        role: UserRole.driver,
        status: UserStatus.active,
        vehicle: Vehicle(
            type: 'Camion', plateNumber: 'LT-4521', color: 'Blanc'),
        availability: Availability(isAvailable: true),
        performance: Performance(
          totalDeliveries: 128,
          averageRating: 4.8,
          totalEarnings: 450000,
          completedOrders: 126,
        ),
      ),
      DriverModel(
        id: 'demo_driver_2',
        name: 'Paul Nkoulou',
        email: 'paul.nkoulou@demo.local',
        phone: '+237 691 44 55 66',
        role: UserRole.driver,
        status: UserStatus.active,
        vehicle: Vehicle(
            type: 'Fourgon', plateNumber: 'LT-7788', color: 'Bleu'),
        availability: Availability(isAvailable: true),
        performance: Performance(
          totalDeliveries: 86,
          averageRating: 4.6,
          totalEarnings: 310000,
          completedOrders: 84,
        ),
      ),
      DriverModel(
        id: 'demo_driver_3',
        name: 'Awa Fofana',
        email: 'awa.fofana@demo.local',
        phone: '+237 692 77 88 99',
        role: UserRole.driver,
        status: UserStatus.active,
        vehicle: Vehicle(type: 'Moto', plateNumber: 'MT-1092', color: 'Rouge'),
        availability: Availability(isAvailable: false),
        performance: Performance(
          totalDeliveries: 54,
          averageRating: 4.9,
          totalEarnings: 190000,
          completedOrders: 54,
        ),
      ),
    ];
    for (final d in drivers) {
      add('users', d.id, d.toMap());
    }

    // --- Commandes ---
    final orders = <OrderModel>[
      _order('demo_order_1', 'CMD-D001', 'Boutique Chez Alice',
          '+237 655 10 20 30', 'Marché Central, Douala', [
        _item('demo_prod_1', 'Coca-Cola Coca-Cola (1.5 L)', 24, 600),
        _item('demo_prod_2', 'Fanta Fanta Orange (1.5 L)', 12, 600),
      ], OrderStatus.pending, now.subtract(const Duration(hours: 5))),
      _order('demo_order_2', 'CMD-D002', 'Alimentation Le Bon Prix',
          '+237 656 11 21 31', 'Akwa, Douala', [
        _item('demo_prod_7', 'Castel Castel Beer (65 cl)', 48, 700),
      ], OrderStatus.confirmed, now.subtract(const Duration(hours: 8)),
          driverId: 'demo_driver_1', driverName: 'Jean Mbarga'),
      _order('demo_order_3', 'CMD-D003', 'Bar Le Bambou',
          '+237 657 12 22 32', 'Bonapriso, Douala', [
        _item('demo_prod_8', '33 Export 33 Export (65 cl)', 24, 700),
        _item('demo_prod_9', 'Guinness Malta Guinness (33 cl)', 24, 800),
      ], OrderStatus.outForDelivery, now.subtract(const Duration(hours: 2)),
          driverId: 'demo_driver_2', driverName: 'Paul Nkoulou'),
      _order('demo_order_4', 'CMD-D004', 'Supérette Etoile', '+237 658 13 23 33',
          'Deido, Douala', [
        _item('demo_prod_5', 'Tangui Eau Minérale Tangui (1.5 L)', 48, 400),
      ], OrderStatus.delivered, now.subtract(const Duration(days: 1)),
          driverId: 'demo_driver_1',
          driverName: 'Jean Mbarga',
          deliveredAt: now.subtract(const Duration(hours: 20))),
      _order('demo_order_5', 'CMD-D005', 'Restaurant La Falaise',
          '+237 659 14 24 34', 'Bonanjo, Douala', [
        _item('demo_prod_4', 'Djino Djino Cocktail (1 L)', 24, 700),
        _item('demo_prod_10', 'Coca-Cola Coca-Cola Canette (33 cl)', 48, 500),
      ], OrderStatus.preparing, now.subtract(const Duration(hours: 1)),
          driverId: 'demo_driver_3', driverName: 'Awa Fofana'),
      _order('demo_order_6', 'CMD-D006', 'Kiosque Carrefour',
          '+237 660 15 25 35', 'Carrefour Bonamoussadi, Douala', [
        _item('demo_prod_3', 'Sprite Sprite (1.5 L)', 24, 600),
      ], OrderStatus.pending, now.subtract(const Duration(minutes: 30))),
    ];
    for (final o in orders) {
      add('orders', o.id, o.toMap());
    }

    // --- Livraisons (pour les commandes en cours / livrées) ---
    final deliveries = [
      DeliveryModel(
        id: 'del_demo_order_3',
        orderId: 'demo_order_3',
        orderNumber: 'CMD-D003',
        driverId: 'demo_driver_2',
        driverName: 'Paul Nkoulou',
        customerName: 'Bar Le Bambou',
        customerPhone: '+237 657 12 22 32',
        deliveryAddress: 'Bonapriso, Douala',
        status: DeliveryStatus.inTransit,
        pickedUpAt: now.subtract(const Duration(hours: 1)),
      ),
      DeliveryModel(
        id: 'del_demo_order_4',
        orderId: 'demo_order_4',
        orderNumber: 'CMD-D004',
        driverId: 'demo_driver_1',
        driverName: 'Jean Mbarga',
        customerName: 'Supérette Etoile',
        customerPhone: '+237 658 13 23 33',
        deliveryAddress: 'Deido, Douala',
        status: DeliveryStatus.delivered,
        pickedUpAt: now.subtract(const Duration(hours: 22)),
        deliveredAt: now.subtract(const Duration(hours: 20)),
      ),
    ];
    for (final d in deliveries) {
      add('deliveries', d.id, d.toMap());
    }

    // --- Tournées ---
    final routes = [
      RouteModel(
        id: 'demo_route_1',
        name: 'Tournée Centre-ville',
        driverId: 'demo_driver_1',
        driverName: 'Jean Mbarga',
        orderIds: ['demo_order_2', 'demo_order_4'],
        status: RouteStatus.inProgress,
        date: now,
        notes: 'Livraisons du matin',
      ),
      RouteModel(
        id: 'demo_route_2',
        name: 'Tournée Marché',
        driverId: 'demo_driver_2',
        driverName: 'Paul Nkoulou',
        orderIds: ['demo_order_3'],
        status: RouteStatus.planned,
        date: now.add(const Duration(days: 1)),
      ),
    ];
    for (final r in routes) {
      add('routes', r.id, r.toMap());
    }

    return rows;
  }

  static ProductModel _product(
    String id,
    String name,
    String brand,
    String category,
    String packageSize,
    int packQuantity,
    double price,
    double cost,
    int stock,
    int reorderLevel,
    String barcode,
  ) {
    return ProductModel(
      id: id,
      name: name,
      category: category,
      brand: brand,
      packageSize: packageSize,
      packQuantity: packQuantity,
      price: price,
      cost: cost,
      stockQuantity: stock,
      reorderLevel: reorderLevel,
      barcode: barcode,
    );
  }

  static OrderItem _item(
    String productId,
    String productName,
    int quantity,
    double unitPrice,
  ) {
    return OrderItem(
      productId: productId,
      productName: productName,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }

  static OrderModel _order(
    String id,
    String number,
    String customerName,
    String phone,
    String address,
    List<OrderItem> items,
    OrderStatus status,
    DateTime createdAt, {
    String? driverId,
    String? driverName,
    DateTime? deliveredAt,
  }) {
    return OrderModel(
      id: id,
      orderNumber: number,
      customerName: customerName,
      customerPhone: phone,
      deliveryAddress: address,
      items: items,
      status: status,
      driverId: driverId,
      driverName: driverName,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
    );
  }
}

class _DemoRow {
  const _DemoRow({
    required this.collection,
    required this.docId,
    required this.data,
  });

  final String collection;
  final String docId;
  final Map<String, dynamic> data;
}
