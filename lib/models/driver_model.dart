import 'user_model.dart';
import 'user_role.dart';
import 'user_status.dart';

class Vehicle {
  final String type;
  final String plateNumber;
  final String color;

  Vehicle({
    required this.type,
    required this.plateNumber,
    required this.color,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'plateNumber': plateNumber,
        'color': color,
      };

  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle(
        type: map['type'] as String,
        plateNumber: map['plateNumber'] as String,
        color: map['color'] as String,
      );
}

class Availability {
  final bool isAvailable;
  final DriverLocation? lastLocation;
  final DateTime? lastUpdated;

  Availability({
    this.isAvailable = true,
    this.lastLocation,
    this.lastUpdated,
  });

  Map<String, dynamic> toMap() => {
        'isAvailable': isAvailable,
        'lastLocation': lastLocation?.toMap(),
        'lastUpdated': lastUpdated?.toIso8601String(),
      };

  factory Availability.fromMap(Map<String, dynamic> map) => Availability(
        isAvailable: (map['isAvailable'] as bool?) ?? true,
        lastLocation: map['lastLocation'] == null
            ? null
            : DriverLocation.fromMap(
                Map<String, dynamic>.from(map['lastLocation'] as Map),
              ),
        lastUpdated: map['lastUpdated'] != null
            ? DateTime.parse(map['lastUpdated'] as String)
            : null,
      );
}

/// Plain latitude/longitude pair. Previously a Firestore `GeoPoint`, now stored
/// as a jsonb object so it round-trips through Postgres unchanged.
class DriverLocation {
  const DriverLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory DriverLocation.fromMap(Map<String, dynamic> map) => DriverLocation(
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
      );
}

class Performance {
  final int totalDeliveries;
  final double averageRating;
  final double totalEarnings;
  final int completedOrders;

  Performance({
    this.totalDeliveries = 0,
    this.averageRating = 0.0,
    this.totalEarnings = 0.0,
    this.completedOrders = 0,
  });

  Map<String, dynamic> toMap() => {
        'totalDeliveries': totalDeliveries,
        'averageRating': averageRating,
        'totalEarnings': totalEarnings,
        'completedOrders': completedOrders,
      };

  factory Performance.fromMap(Map<String, dynamic> map) => Performance(
        totalDeliveries: (map['totalDeliveries'] as num?)?.toInt() ?? 0,
        averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
        totalEarnings: (map['totalEarnings'] as num?)?.toDouble() ?? 0.0,
        completedOrders: (map['completedOrders'] as num?)?.toInt() ?? 0,
      );
}

class DriverModel extends UserModel {
  final Vehicle vehicle;
  final Availability availability;
  final Performance performance;
  final double commissionRate;

  DriverModel({
    required super.id,
    required super.name,
    required super.email,
    super.phone = '',
    super.role = UserRole.driver,
    super.status = UserStatus.active,
    super.pinCode = '',
    super.profileImage,
    super.createdAt,
    super.updatedAt,
    Vehicle? vehicle,
    Availability? availability,
    Performance? performance,
    this.commissionRate = 10.0,
  })  : vehicle = vehicle ??
            Vehicle(type: '', plateNumber: '', color: ''),
        availability = availability ?? Availability(),
        performance = performance ?? Performance();

  @override
  Map<String, dynamic> toMap() => {
        ...super.toMap(),
        'vehicle': vehicle.toMap(),
        'availability': availability.toMap(),
        'performance': performance.toMap(),
        'commissionRate': commissionRate,
      };

  static DriverModel fromMap(Map<String, dynamic> map) => DriverModel(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        phone: (map['phone'] as String?) ?? '',
        role: UserRole.fromString(map['role'] as String),
        status: UserStatus.fromString(map['status'] as String),
        pinCode: (map['pinCode'] as String?) ?? '',
        profileImage: map['profileImage'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        updatedAt: DateTime.parse(map['updatedAt'] as String),
        vehicle: map['vehicle'] != null
            ? Vehicle.fromMap(map['vehicle'] as Map<String, dynamic>)
            : Vehicle(type: '', plateNumber: '', color: ''),
        availability: map['availability'] != null
            ? Availability.fromMap(
                map['availability'] as Map<String, dynamic>)
            : Availability(),
        performance: map['performance'] != null
            ? Performance.fromMap(
                map['performance'] as Map<String, dynamic>)
            : Performance(),
        commissionRate:
            (map['commissionRate'] as num?)?.toDouble() ?? 10.0,
      );

  factory DriverModel.fromUserModel(UserModel user,
      {Vehicle? vehicle,
      Availability? availability,
      Performance? performance,
      double commissionRate = 10.0}) {
    return DriverModel(
      id: user.id,
      name: user.name,
      email: user.email,
      phone: user.phone,
      role: UserRole.driver,
      status: user.status,
      pinCode: user.pinCode,
      profileImage: user.profileImage,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      vehicle: vehicle ??
          Vehicle(type: '', plateNumber: '', color: ''),
      availability: availability ?? Availability(),
      performance: performance ?? Performance(),
      commissionRate: commissionRate,
    );
  }

  @override
  DriverModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    UserStatus? status,
    String? pinCode,
    String? profileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    Vehicle? vehicle,
    Availability? availability,
    Performance? performance,
    double? commissionRate,
  }) {
    return DriverModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      pinCode: pinCode ?? this.pinCode,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      vehicle: vehicle ?? this.vehicle,
      availability: availability ?? this.availability,
      performance: performance ?? this.performance,
      commissionRate: commissionRate ?? this.commissionRate,
    );
  }
}
