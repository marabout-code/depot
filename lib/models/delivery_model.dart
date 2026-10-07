import 'delivery_status.dart';

class DeliveryLocation {
  final double latitude;
  final double longitude;
  final String? address;

  DeliveryLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  factory DeliveryLocation.fromMap(Map<String, dynamic> map) {
    return DeliveryLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String?,
    );
  }
}

class DeliveryModel {
  final String id;
  final String orderId;
  final String orderNumber;
  final String driverId;
  final String driverName;
  final String customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final DeliveryLocation? location;
  final DeliveryStatus status;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final String? signatureUrl;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeliveryModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.driverId,
    required this.driverName,
    required this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.location,
    this.status = DeliveryStatus.assigned,
    this.pickedUpAt,
    this.deliveredAt,
    this.signatureUrl,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'orderNumber': orderNumber,
      'driverId': driverId,
      'driverName': driverName,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'location': location?.toMap(),
      'status': status.value,
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'signatureUrl': signatureUrl,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DeliveryModel.fromMap(Map<String, dynamic> map) {
    return DeliveryModel(
      id: map['id'] as String,
      orderId: map['orderId'] as String,
      orderNumber: map['orderNumber'] as String,
      driverId: map['driverId'] as String,
      driverName: map['driverName'] as String,
      customerName: map['customerName'] as String,
      customerPhone: map['customerPhone'] as String?,
      deliveryAddress: map['deliveryAddress'] as String?,
      location: map['location'] != null
          ? DeliveryLocation.fromMap(map['location'] as Map<String, dynamic>)
          : null,
      status: DeliveryStatus.fromString(map['status'] as String),
      pickedUpAt: map['pickedUpAt'] != null
          ? DateTime.parse(map['pickedUpAt'] as String)
          : null,
      deliveredAt: map['deliveredAt'] != null
          ? DateTime.parse(map['deliveredAt'] as String)
          : null,
      signatureUrl: map['signatureUrl'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  DeliveryModel copyWith({
    String? id,
    String? orderId,
    String? orderNumber,
    String? driverId,
    String? driverName,
    String? customerName,
    String? customerPhone,
    String? deliveryAddress,
    DeliveryLocation? location,
    DeliveryStatus? status,
    DateTime? pickedUpAt,
    DateTime? deliveredAt,
    String? signatureUrl,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeliveryModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      location: location ?? this.location,
      status: status ?? this.status,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
