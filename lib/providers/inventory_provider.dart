import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/inventory_model.dart';
import '../models/product_model.dart';

enum InventoryStatus { initial, loading, loaded, error }

class InventoryState {
  final InventoryStatus status;
  final List<InventoryModel> items;
  final List<InventoryMovement> movements;
  final String? error;

  const InventoryState({
    this.status = InventoryStatus.initial,
    this.items = const [],
    this.movements = const [],
    this.error,
  });

  InventoryState copyWith({
    InventoryStatus? status,
    List<InventoryModel>? items,
    List<InventoryMovement>? movements,
    String? error,
  }) {
    return InventoryState(
      status: status ?? this.status,
      items: items ?? this.items,
      movements: movements ?? this.movements,
      error: error,
    );
  }
}

class InventoryNotifier extends StateNotifier<InventoryState> {
  final LocalDataService _data;

  InventoryNotifier(this._data) : super(const InventoryState());

  Future<void> loadInventory() async {
    state = state.copyWith(status: InventoryStatus.loading);
    try {
      final items = await _data.getDocuments<InventoryModel>(
        AppConstants.inventoryCollection,
        InventoryModel.fromMap,
        orderBy: 'productName',
      );
      state = InventoryState(
        status: InventoryStatus.loaded,
        items: items,
        movements: state.movements,
      );
    } catch (e) {
      state = state.copyWith(
        status: InventoryStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> syncFromProducts(List<ProductModel> products) async {
    state = state.copyWith(status: InventoryStatus.loading);
    try {
      final existing = await _data.getDocuments<InventoryModel>(
        AppConstants.inventoryCollection,
        InventoryModel.fromMap,
      );
      final existingMap = {for (final e in existing) e.productId: e};

      final operations = <BatchOperation>[];
      for (final p in products) {
        final existingItem = existingMap[p.id];
        if (existingItem == null) {
          final inv = InventoryModel(
            id: const Uuid().v4(),
            productId: p.id,
            productName: p.displayName,
            currentStock: p.stockQuantity,
            unitCost: p.cost,
            location: 'Entrepôt principal',
          );
          operations.add(BatchOperation(
            type: BatchOperationType.set,
            collection: AppConstants.inventoryCollection,
            docId: inv.id,
            data: inv.toMap(),
          ));
        } else if (existingItem.unitCost != p.cost) {
          operations.add(BatchOperation(
            type: BatchOperationType.update,
            collection: AppConstants.inventoryCollection,
            docId: existingItem.id,
            data: {'unitCost': p.cost},
          ));
        }
      }
      if (operations.isNotEmpty) {
        await _data.batchWrite(operations);
      }
      await loadInventory();
    } catch (e) {
      state = state.copyWith(
        status: InventoryStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> recordMovement({
    required String productId,
    required String productName,
    required MovementType type,
    required int quantity,
    required int currentStock,
    String? performedBy,
    String? notes,
  }) async {
    state = state.copyWith(status: InventoryStatus.loading);
    try {
      int newStock = currentStock;
      switch (type) {
        case MovementType.stockIn:
        case MovementType.returnItem:
          newStock = currentStock + quantity;
          break;
        case MovementType.stockOut:
        case MovementType.damage:
          newStock = (currentStock - quantity).clamp(0, currentStock);
          break;
        case MovementType.adjustment:
          newStock = quantity;
          break;
      }

      final movement = InventoryMovement(
        id: const Uuid().v4(),
        productId: productId,
        productName: productName,
        type: type,
        quantity: quantity,
        quantityBefore: currentStock,
        quantityAfter: newStock,
        performedBy: performedBy,
        notes: notes,
      );

      await _data.createDocument(
        AppConstants.movementsCollection,
        movement.toMap(),
        docId: movement.id,
      );

      final invId = 'inv_$productId';
      final existingItems = state.items;
      final existing = existingItems.where((i) => i.productId == productId).firstOrNull;
      await _data.createDocument(
        AppConstants.inventoryCollection,
        InventoryModel(
          id: invId,
          productId: productId,
          productName: productName,
          currentStock: newStock,
          unitCost: existing?.unitCost ?? 0,
          location: 'Entrepôt principal',
        ).toMap(),
        docId: invId,
      );

      await loadInventory();
    } catch (e) {
      state = state.copyWith(
        status: InventoryStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> loadMovements({String? productId}) async {
    try {
      final where = productId != null
          ? [WhereClause(field: 'productId', value: productId)]
          : null;
      final movements = await _data.getDocuments<InventoryMovement>(
        AppConstants.movementsCollection,
        InventoryMovement.fromMap,
        orderBy: 'createdAt',
        descending: true,
        where: where,
      );
      state = state.copyWith(movements: movements);
    } catch (e) {
      state = state.copyWith(
        status: InventoryStatus.error,
        error: e.toString(),
      );
    }
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier(ref.read(localDataServiceProvider));
});
