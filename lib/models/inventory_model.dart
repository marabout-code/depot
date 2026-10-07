enum MovementType {
  stockIn,
  stockOut,
  adjustment,
  damage,
  returnItem;

  String get value {
    switch (this) {
      case MovementType.stockIn:
        return 'stock_in';
      case MovementType.stockOut:
        return 'stock_out';
      case MovementType.adjustment:
        return 'adjustment';
      case MovementType.damage:
        return 'damage';
      case MovementType.returnItem:
        return 'return';
    }
  }

  static MovementType fromString(String type) {
    switch (type) {
      case 'stock_in':
        return MovementType.stockIn;
      case 'stock_out':
        return MovementType.stockOut;
      case 'adjustment':
        return MovementType.adjustment;
      case 'damage':
        return MovementType.damage;
      case 'return':
        return MovementType.returnItem;
      default:
        return MovementType.stockIn;
    }
  }
}

class InventoryMovement {
  final String id;
  final String productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final int quantityBefore;
  final int quantityAfter;
  final String? performedBy;
  final String? notes;
  final DateTime createdAt;

  InventoryMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.performedBy,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'type': type.value,
      'quantity': quantity,
      'quantityBefore': quantityBefore,
      'quantityAfter': quantityAfter,
      'performedBy': performedBy,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InventoryMovement.fromMap(Map<String, dynamic> map) {
    return InventoryMovement(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      type: MovementType.fromString(map['type'] as String),
      quantity: (map['quantity'] as num).toInt(),
      quantityBefore: (map['quantityBefore'] as num).toInt(),
      quantityAfter: (map['quantityAfter'] as num).toInt(),
      performedBy: map['performedBy'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
    );
  }
}

class InventoryModel {
  final String id;
  final String productId;
  final String productName;
  final int currentStock;
  final int reservedQuantity;
  final int availableQuantity;
  final double unitCost;
  final String? location;
  final DateTime lastCountedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.currentStock = 0,
    this.reservedQuantity = 0,
    this.availableQuantity = 0,
    this.unitCost = 0,
    this.location,
    DateTime? lastCountedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : lastCountedAt = lastCountedAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get stockValue => unitCost * availableQuantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'currentStock': currentStock,
      'reservedQuantity': reservedQuantity,
      'availableQuantity': availableQuantity,
      'unitCost': unitCost,
      'location': location,
      'lastCountedAt': lastCountedAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InventoryModel.fromMap(Map<String, dynamic> map) {
    return InventoryModel(
      id: map['id'] as String,
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      currentStock: (map['currentStock'] as num?)?.toInt() ?? 0,
      reservedQuantity: (map['reservedQuantity'] as num?)?.toInt() ?? 0,
      availableQuantity: (map['availableQuantity'] as num?)?.toInt() ?? 0,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0,
      location: map['location'] as String?,
      lastCountedAt: map['lastCountedAt'] != null
          ? DateTime.parse(map['lastCountedAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  InventoryModel copyWith({
    String? id,
    String? productId,
    String? productName,
    int? currentStock,
    int? reservedQuantity,
    int? availableQuantity,
    double? unitCost,
    String? location,
    DateTime? lastCountedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      currentStock: currentStock ?? this.currentStock,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      unitCost: unitCost ?? this.unitCost,
      location: location ?? this.location,
      lastCountedAt: lastCountedAt ?? this.lastCountedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
