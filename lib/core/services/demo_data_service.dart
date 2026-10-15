import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../database/local_auth_service.dart';
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
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../models/user_status.dart';

final demoDataServiceProvider = Provider<DemoDataService>((ref) {
  return DemoDataService(
    ref.read(appDatabaseProvider),
    ref.read(localAuthServiceProvider),
  );
});

/// Fills the local database with a fixed, realistic sample dataset for
/// demonstrations, and removes exactly those rows again when switched off.
///
/// The dataset mirrors the production multi-depot model so the role differences
/// are visible end to end:
///
///   * two active depots, each owning its own products, stock, orders and
///     staff, plus a third deactivated (and still empty) depot so the
///     `Actif`/`Inactif` states are both visible in the depot list;
///   * one `superadmin` with no depot (unrestricted — sees everything);
///   * one `admin` bound to each depot (scoped to that depot);
///   * drivers bound to a depot;
///   * every document carries the `depotId` it belongs to, so depot scoping is
///     observable, not implied;
///   * each demo account also gets a cached bcrypt PIN here, so the keypad login
///     works offline and you can sign in as any role.
///
/// Every demo document carries a `demo: true` marker in its payload and is
/// written with `dirty = false`, so:
///
///   * the sync engine never pushes demo rows to Supabase (a demo must not
///     pollute the shared depot database), and
///   * switching the demo off deletes only the marked rows and the demo PIN
///     credentials, leaving any real data on the device untouched.
class DemoDataService {
  DemoDataService(this._db, this._auth);

  final AppDatabase _db;
  final LocalAuthService _auth;

  static const String _marker = 'demo';

  static const String depot1Id = 'demo_depot_1';
  static const String depot2Id = 'demo_depot_2';
  static const String depot3Id = 'demo_depot_3';

  /// The demo staff accounts and the PIN each one signs in with.
  ///
  /// PINs are unique across the dataset: the keypad refuses a PIN that matches
  /// two accounts, so two demo users can never share one. `0000` is reserved for
  /// the superadmin so it is obvious which account is unrestricted.
  ///
  /// Public so the settings screen can show them: signing in as each role is the
  /// only way to observe the depot-scoping differences without real accounts.
  static const List<DemoAccount> accounts = [
    DemoAccount(
      id: 'demo_superadmin',
      label: 'Superadmin — tous les dépôts',
      pin: '0000',
      role: UserRole.superadmin,
    ),
    DemoAccount(
      id: 'demo_admin_1',
      label: 'Admin — Dépôt Central (Bonabéri)',
      pin: '1111',
      role: UserRole.admin,
    ),
    DemoAccount(
      id: 'demo_admin_2',
      label: 'Admin — Dépôt Yaoundé (Centre)',
      pin: '2222',
      role: UserRole.admin,
    ),
    DemoAccount(
      id: 'demo_driver_1',
      label: 'Jean Mbarga — conducteur, Dépôt Central',
      pin: '3333',
      role: UserRole.driver,
    ),
    DemoAccount(
      id: 'demo_driver_2',
      label: 'Paul Nkoulou — conducteur, Dépôt Central',
      pin: '4444',
      role: UserRole.driver,
    ),
    DemoAccount(
      id: 'demo_driver_3',
      label: 'Awa Fofana — conducteur, Dépôt Yaoundé',
      pin: '5555',
      role: UserRole.driver,
    ),
  ];

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
                depotId: Value(row.data['depotId'] as String?),
                version: const Value(1),
                localUpdatedAt: DateTime.now(),
                dirty: const Value(false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });

    // Cache each demo account's PIN so the keypad can sign in offline. This is
    // device-local only: the hash never lands in a synced document.
    for (final account in accounts) {
      await _auth.storeCredential(
        userId: account.id,
        pin: account.pin,
        role: account.role,
      );
    }

    return rows.length;
  }

  /// Deletes every demo document and demo PIN credential. Returns how many
  /// documents were removed.
  Future<int> clear() async {
    final rows = await _db.select(_db.documents).get();
    final demo = rows.where(_isDemo).toList();

    await _db.transaction(() async {
      for (final row in demo) {
        await (_db.delete(_db.documents)
              ..where((d) =>
                  d.collection.equals(row.collection) &
                  d.docId.equals(row.docId)))
            .go();
      }
      for (final account in accounts) {
        await (_db.delete(_db.localCredentials)
              ..where((c) => c.userId.equals(account.id)))
            .go();
        await (_db.delete(_db.localAttempts)
              ..where((a) => a.userId.equals(account.id)))
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

    void add(
      String collection,
      String docId,
      Map<String, dynamic> data, {
      String? depotId,
    }) {
      rows.add(_DemoRow(
        collection: collection,
        docId: docId,
        data: {
          ...data,
          'depotId': ?depotId,
        },
      ));
    }

    // --- Dépôts ---
    // A depot's synced row belongs to itself (depot_id = its own id), matching
    // the server so each depot admin can read their own depot record.
    add(
      'depots',
      depot1Id,
      DepotModel(
        id: depot1Id,
        name: 'Dépôt Central',
        city: 'Bonabéri',
        status: DepotModel.statusActive,
        createdAt: now,
      ).toMap(),
      depotId: depot1Id,
    );
    add(
      'depots',
      depot2Id,
      DepotModel(
        id: depot2Id,
        name: 'Dépôt Yaoundé',
        city: 'Centre',
        status: DepotModel.statusActive,
        createdAt: now,
      ).toMap(),
      depotId: depot2Id,
    );
    // Deactivated and still empty: exercises the `Inactif` state in the list
    // (and the active-only filter in the driver form) without any staff or data.
    add(
      'depots',
      depot3Id,
      DepotModel(
        id: depot3Id,
        name: 'Dépôt Bafoussam',
        city: 'Tamdja',
        status: DepotModel.statusInactive,
        createdAt: now,
      ).toMap(),
      depotId: depot3Id,
    );

    // --- Comptes (superadmin, un admin par dépôt, conducteurs) ---
    add(
      'users',
      'demo_superadmin',
      UserModel(
        id: 'demo_superadmin',
        name: 'Superadmin Démo',
        email: 'superadmin@demo.local',
        phone: '+237 690 00 00 00',
        role: UserRole.superadmin,
        status: UserStatus.active,
      ).toMap(),
    );
    add(
      'users',
      'demo_admin_1',
      UserModel(
        id: 'demo_admin_1',
        name: 'Admin Douala',
        email: 'admin.douala@demo.local',
        phone: '+237 690 01 01 01',
        role: UserRole.admin,
        status: UserStatus.active,
        depotId: depot1Id,
      ).toMap(),
      depotId: depot1Id,
    );
    add(
      'users',
      'demo_admin_2',
      UserModel(
        id: 'demo_admin_2',
        name: 'Admin Yaoundé',
        email: 'admin.yaounde@demo.local',
        phone: '+237 690 02 02 02',
        role: UserRole.admin,
        status: UserStatus.active,
        depotId: depot2Id,
      ).toMap(),
      depotId: depot2Id,
    );

    final drivers = <({DriverModel driver, String depotId})>[
      (
        depotId: depot1Id,
        driver: DriverModel(
          id: 'demo_driver_1',
          name: 'Jean Mbarga',
          email: 'jean.mbarga@demo.local',
          phone: '+237 690 11 22 33',
          role: UserRole.driver,
          status: UserStatus.active,
          depotId: depot1Id,
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
      ),
      (
        depotId: depot1Id,
        driver: DriverModel(
          id: 'demo_driver_2',
          name: 'Paul Nkoulou',
          email: 'paul.nkoulou@demo.local',
          phone: '+237 691 44 55 66',
          role: UserRole.driver,
          status: UserStatus.active,
          depotId: depot1Id,
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
      ),
      (
        depotId: depot2Id,
        driver: DriverModel(
          id: 'demo_driver_3',
          name: 'Awa Fofana',
          email: 'awa.fofana@demo.local',
          phone: '+237 692 77 88 99',
          role: UserRole.driver,
          status: UserStatus.active,
          depotId: depot2Id,
          vehicle:
              Vehicle(type: 'Moto', plateNumber: 'MT-1092', color: 'Rouge'),
          availability: Availability(isAvailable: false),
          performance: Performance(
            totalDeliveries: 54,
            averageRating: 4.9,
            totalEarnings: 190000,
            completedOrders: 54,
          ),
        ),
      ),
    ];
    for (final entry in drivers) {
      add('users', entry.driver.id, entry.driver.toMap(),
          depotId: entry.depotId);
    }

    // --- Catégories (une liste par dépôt) ---
    final categories = <({CategoryModel category, String depotId})>[
      (depotId: depot1Id, category: CategoryModel(id: 'demo_cat_1_gazeuse', name: 'Boissons gazeuses')),
      (depotId: depot1Id, category: CategoryModel(id: 'demo_cat_1_eau', name: 'Eaux minérales')),
      (depotId: depot1Id, category: CategoryModel(id: 'demo_cat_1_biere', name: 'Bières')),
      (depotId: depot2Id, category: CategoryModel(id: 'demo_cat_2_gazeuse', name: 'Boissons gazeuses')),
      (depotId: depot2Id, category: CategoryModel(id: 'demo_cat_2_eau', name: 'Eaux minérales')),
      (depotId: depot2Id, category: CategoryModel(id: 'demo_cat_2_biere', name: 'Bières')),
      (depotId: depot2Id, category: CategoryModel(id: 'demo_cat_2_jus', name: 'Jus & énergies')),
    ];
    for (final entry in categories) {
      add('categories', entry.category.id, entry.category.toMap(),
          depotId: entry.depotId);
    }

    // --- Produits ---
    final products = <({ProductModel product, String depotId})>[
      // Dépôt Central (Douala)
      (depotId: depot1Id, product: _product('demo_prod_1', 'Coca-Cola', 'Coca-Cola', 'Boissons gazeuses', '1.5 L', 6, 600, 450, 120, 24, '6001066001234')),
      (depotId: depot1Id, product: _product('demo_prod_2', 'Fanta Orange', 'Fanta', 'Boissons gazeuses', '1.5 L', 6, 600, 450, 80, 24, '6001066002340')),
      (depotId: depot1Id, product: _product('demo_prod_3', 'Sprite', 'Sprite', 'Boissons gazeuses', '1.5 L', 6, 600, 450, 60, 24, '6001066003456')),
      (depotId: depot1Id, product: _product('demo_prod_4', 'Eau Minérale Tangui', 'Tangui', 'Eaux minérales', '1.5 L', 6, 400, 250, 200, 48, '6001066005678')),
      (depotId: depot1Id, product: _product('demo_prod_5', 'Castel Beer', 'Castel', 'Bières', '65 cl', 12, 700, 500, 96, 24, '6001066007890')),
      // Dépôt Yaoundé
      (depotId: depot2Id, product: _product('demo_prod_6', 'Djino Cocktail', 'Djino', 'Jus & énergies', '1 L', 12, 700, 500, 40, 12, '6001066004562')),
      (depotId: depot2Id, product: _product('demo_prod_7', 'Source du Pays', 'Source du Pays', 'Eaux minérales', '0.5 L', 12, 300, 180, 15, 24, '6001066006784')),
      (depotId: depot2Id, product: _product('demo_prod_8', '33 Export', '33 Export', 'Bières', '65 cl', 12, 700, 500, 0, 24, '6001066008906')),
      (depotId: depot2Id, product: _product('demo_prod_9', 'Malta Guinness', 'Guinness', 'Jus & énergies', '33 cl', 24, 800, 600, 48, 12, '6001066009012')),
      (depotId: depot2Id, product: _product('demo_prod_10', 'Coca-Cola Canette', 'Coca-Cola', 'Boissons gazeuses', '33 cl', 24, 500, 350, 144, 36, '6001066010128')),
    ];
    for (final entry in products) {
      add('products', entry.product.id, entry.product.toMap(),
          depotId: entry.depotId);
    }

    // --- Inventaire ---
    for (final entry in products) {
      final p = entry.product;
      final inv = InventoryModel(
        id: 'demo_inv_${p.id}',
        productId: p.id,
        productName: p.displayName,
        currentStock: p.stockQuantity,
        availableQuantity: p.stockQuantity,
        unitCost: p.cost,
        location: 'Entrepôt principal',
      );
      add('inventory', inv.id, inv.toMap(), depotId: entry.depotId);
    }

    // --- Mouvements de stock ---
    final movements = <({InventoryMovement movement, String depotId})>[
      (
        depotId: depot1Id,
        movement: InventoryMovement(
          id: 'demo_mov_1',
          productId: 'demo_prod_1',
          productName: 'Coca-Cola Coca-Cola (1.5 L)',
          type: MovementType.stockIn,
          quantity: 120,
          quantityBefore: 0,
          quantityAfter: 120,
          performedBy: 'Admin Douala',
          notes: 'Réception fournisseur',
          createdAt: now.subtract(const Duration(days: 6)),
        ),
      ),
      (
        depotId: depot1Id,
        movement: InventoryMovement(
          id: 'demo_mov_2',
          productId: 'demo_prod_5',
          productName: 'Castel Castel Beer (65 cl)',
          type: MovementType.stockOut,
          quantity: 48,
          quantityBefore: 144,
          quantityAfter: 96,
          performedBy: 'Admin Douala',
          notes: 'Commande CMD-D002',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ),
      (
        depotId: depot2Id,
        movement: InventoryMovement(
          id: 'demo_mov_3',
          productId: 'demo_prod_6',
          productName: 'Djino Djino Cocktail (1 L)',
          type: MovementType.stockIn,
          quantity: 40,
          quantityBefore: 0,
          quantityAfter: 40,
          performedBy: 'Admin Yaoundé',
          notes: 'Réception fournisseur',
          createdAt: now.subtract(const Duration(days: 4)),
        ),
      ),
      (
        depotId: depot2Id,
        movement: InventoryMovement(
          id: 'demo_mov_4',
          productId: 'demo_prod_7',
          productName: 'Source du Pays Source du Pays (0.5 L)',
          type: MovementType.damage,
          quantity: 5,
          quantityBefore: 20,
          quantityAfter: 15,
          performedBy: 'Admin Yaoundé',
          notes: 'Casiers cassés',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ),
    ];
    for (final entry in movements) {
      add('movements', entry.movement.id, entry.movement.toMap(),
          depotId: entry.depotId);
    }

    // --- Commandes ---
    final orders = <({OrderModel order, String depotId})>[
      // Dépôt Central (Douala)
      (
        depotId: depot1Id,
        order: _order('demo_order_1', 'CMD-D001', 'Boutique Chez Alice', '+237 655 10 20 30', 'Marché Central, Douala', [
          _item('demo_prod_1', 'Coca-Cola Coca-Cola (1.5 L)', 24, 600),
          _item('demo_prod_2', 'Fanta Fanta Orange (1.5 L)', 12, 600),
        ], OrderStatus.pending, now.subtract(const Duration(hours: 5))),
      ),
      (
        depotId: depot1Id,
        order: _order('demo_order_2', 'CMD-D002', 'Alimentation Le Bon Prix', '+237 656 11 21 31', 'Akwa, Douala', [
          _item('demo_prod_5', 'Castel Castel Beer (65 cl)', 48, 700),
        ], OrderStatus.confirmed, now.subtract(const Duration(hours: 8)),
            driverId: 'demo_driver_1', driverName: 'Jean Mbarga'),
      ),
      (
        depotId: depot1Id,
        order: _order('demo_order_3', 'CMD-D003', 'Bar Le Bambou', '+237 657 12 22 32', 'Bonapriso, Douala', [
          _item('demo_prod_3', 'Sprite Sprite (1.5 L)', 24, 600),
        ], OrderStatus.outForDelivery, now.subtract(const Duration(hours: 2)),
            driverId: 'demo_driver_2', driverName: 'Paul Nkoulou'),
      ),
      (
        depotId: depot1Id,
        order: _order('demo_order_4', 'CMD-D004', 'Supérette Etoile', '+237 658 13 23 33', 'Deido, Douala', [
          _item('demo_prod_4', 'Tangui Eau Minérale Tangui (1.5 L)', 48, 400),
        ], OrderStatus.delivered, now.subtract(const Duration(days: 1)),
            driverId: 'demo_driver_1',
            driverName: 'Jean Mbarga',
            deliveredAt: now.subtract(const Duration(hours: 20))),
      ),
      // Dépôt Yaoundé
      (
        depotId: depot2Id,
        order: _order('demo_order_5', 'CMD-Y001', 'Restaurant La Falaise', '+237 659 14 24 34', 'Bastos, Yaoundé', [
          _item('demo_prod_6', 'Djino Djino Cocktail (1 L)', 24, 700),
          _item('demo_prod_10', 'Coca-Cola Coca-Cola Canette (33 cl)', 48, 500),
        ], OrderStatus.preparing, now.subtract(const Duration(hours: 1)),
            driverId: 'demo_driver_3', driverName: 'Awa Fofana'),
      ),
      (
        depotId: depot2Id,
        order: _order('demo_order_6', 'CMD-Y002', 'Kiosque Carrefour', '+237 660 15 25 35', 'Carrefour Bastos, Yaoundé', [
          _item('demo_prod_9', 'Guinness Malta Guinness (33 cl)', 24, 800),
        ], OrderStatus.pending, now.subtract(const Duration(minutes: 30))),
      ),
      (
        depotId: depot2Id,
        order: _order('demo_order_7', 'CMD-Y003', 'Snack Bonapriso', '+237 661 16 26 36', 'Bonapriso, Yaoundé', [
          _item('demo_prod_8', '33 Export 33 Export (65 cl)', 24, 700),
        ], OrderStatus.delivered, now.subtract(const Duration(days: 2)),
            driverId: 'demo_driver_3',
            driverName: 'Awa Fofana',
            deliveredAt: now.subtract(const Duration(days: 2))),
      ),
    ];
    for (final entry in orders) {
      add('orders', entry.order.id, entry.order.toMap(),
          depotId: entry.depotId);
    }

    // --- Livraisons (pour les commandes en cours / livrées) ---
    final deliveries = <({DeliveryModel delivery, String depotId})>[
      (
        depotId: depot1Id,
        delivery: DeliveryModel(
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
      ),
      (
        depotId: depot1Id,
        delivery: DeliveryModel(
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
      ),
      (
        depotId: depot2Id,
        delivery: DeliveryModel(
          id: 'del_demo_order_7',
          orderId: 'demo_order_7',
          orderNumber: 'CMD-Y003',
          driverId: 'demo_driver_3',
          driverName: 'Awa Fofana',
          customerName: 'Snack Bonapriso',
          customerPhone: '+237 661 16 26 36',
          deliveryAddress: 'Bonapriso, Yaoundé',
          status: DeliveryStatus.delivered,
          pickedUpAt: now.subtract(const Duration(days: 2, hours: 1)),
          deliveredAt: now.subtract(const Duration(days: 2)),
        ),
      ),
    ];
    for (final entry in deliveries) {
      add('deliveries', entry.delivery.id, entry.delivery.toMap(),
          depotId: entry.depotId);
    }

    // --- Tournées ---
    final routes = <({RouteModel route, String depotId})>[
      (
        depotId: depot1Id,
        route: RouteModel(
          id: 'demo_route_1',
          name: 'Tournée Centre-ville',
          driverId: 'demo_driver_1',
          driverName: 'Jean Mbarga',
          orderIds: ['demo_order_2', 'demo_order_4'],
          status: RouteStatus.inProgress,
          date: now,
          notes: 'Livraisons du matin',
        ),
      ),
      (
        depotId: depot1Id,
        route: RouteModel(
          id: 'demo_route_2',
          name: 'Tournée Marché',
          driverId: 'demo_driver_2',
          driverName: 'Paul Nkoulou',
          orderIds: ['demo_order_3'],
          status: RouteStatus.planned,
          date: now.add(const Duration(days: 1)),
        ),
      ),
      (
        depotId: depot2Id,
        route: RouteModel(
          id: 'demo_route_3',
          name: 'Tournée Bastos',
          driverId: 'demo_driver_3',
          driverName: 'Awa Fofana',
          orderIds: ['demo_order_5', 'demo_order_7'],
          status: RouteStatus.planned,
          date: now.add(const Duration(days: 1)),
          notes: 'Reprise après arrêt maladie',
        ),
      ),
    ];
    for (final entry in routes) {
      add('routes', entry.route.id, entry.route.toMap(),
          depotId: entry.depotId);
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

/// A demo login: the account id, a human label, the PIN that signs it in, and
/// its role, so the cached credential can be written with the right role and the
/// settings screen can show the credentials.
class DemoAccount {
  const DemoAccount({
    required this.id,
    required this.label,
    required this.pin,
    required this.role,
  });

  final String id;
  final String label;
  final String pin;
  final UserRole role;
}
