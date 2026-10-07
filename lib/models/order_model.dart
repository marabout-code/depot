import 'order_status.dart';

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] as String,
      productName: map['productName'] as String,
      quantity: (map['quantity'] as num).toInt(),
      unitPrice: (map['unitPrice'] as num).toDouble(),
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final List<OrderItem> items;
  final OrderStatus status;
  final double totalAmount;
  final String? driverId;
  final String? driverName;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deliveredAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    required this.items,
    this.status = OrderStatus.pending,
    this.totalAmount = 0,
    this.driverId,
    this.driverName,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.deliveredAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get calculatedTotal =>
      items.fold(0.0, (sum, item) => sum + item.totalPrice);

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status.value,
      'totalAmount': totalAmount > 0 ? totalAmount : calculatedTotal,
      'driverId': driverId,
      'driverName': driverName,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'] as String,
      orderNumber: map['orderNumber'] as String,
      customerName: map['customerName'] as String,
      customerPhone: map['customerPhone'] as String?,
      deliveryAddress: map['deliveryAddress'] as String?,
      items: (map['items'] as List<dynamic>)
          .map((e) => OrderItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      status: OrderStatus.fromString(map['status'] as String),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      driverId: map['driverId'] as String?,
      driverName: map['driverName'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.parse(map['deliveredAt'] as String)
          : null,
    );
  }

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    List<OrderItem>? items,
    OrderStatus? status,
    double? totalAmount,
    String? driverId,
    String? driverName,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deliveredAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      items: items ?? this.items,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      deliveredAt: deliveredAt ?? this.deliveredAt,
    );
  }
}
