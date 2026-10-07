class ProductModel {
  final String id;
  final String name;
  final String category;
  final String brand;
  final String packageSize;
  final int packQuantity;
  final String? imageUrl;
  final double price;
  final double cost;
  final int stockQuantity;
  final int reorderLevel;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? barcode;

  ProductModel({
    required this.id,
    required this.name,
    required this.category,
    required this.brand,
    required this.packageSize,
    required this.packQuantity,
    this.imageUrl,
    required this.price,
    this.cost = 0,
    this.stockQuantity = 0,
    this.reorderLevel = 10,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.barcode,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'brand': brand,
      'packageSize': packageSize,
      'packQuantity': packQuantity,
      'imageUrl': imageUrl,
      'price': price,
      'cost': cost,
      'stockQuantity': stockQuantity,
      'reorderLevel': reorderLevel,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'barcode': barcode,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? '',
      brand: map['brand'] as String,
      packageSize: map['packageSize'] as String,
      packQuantity: (map['packQuantity'] as num).toInt(),
      imageUrl: map['imageUrl'] as String?,
      price: (map['price'] as num).toDouble(),
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (map['reorderLevel'] as num?)?.toInt() ?? 10,
      isActive: (map['isActive'] as bool?) ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      barcode: map['barcode'] as String?,
    );
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? category,
    String? brand,
    String? packageSize,
    int? packQuantity,
    String? imageUrl,
    double? price,
    double? cost,
    int? stockQuantity,
    int? reorderLevel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? barcode,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      packageSize: packageSize ?? this.packageSize,
      packQuantity: packQuantity ?? this.packQuantity,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      cost: cost ?? this.cost,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      barcode: barcode ?? this.barcode,
    );
  }

  String get displayName => '$brand $name ($packageSize)';

  bool get needsReorder => stockQuantity <= reorderLevel;

  double get stockValue => cost * stockQuantity;
}
