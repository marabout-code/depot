import 'route_status.dart';

/// A tournée: one driver, a set of orders delivered together on a given day.
///
/// The order documents themselves keep a single `driverId`, but a route groups
/// many of them under one trip so a driver can be handed a full load at once and
/// the depot can report progress per tournée.
class RouteModel {
  final String id;
  final String name;
  final String driverId;
  final String driverName;
  final List<String> orderIds;
  final RouteStatus status;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  RouteModel({
    required this.id,
    required this.name,
    required this.driverId,
    required this.driverName,
    this.orderIds = const [],
    this.status = RouteStatus.planned,
    DateTime? date,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : date = date ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get orderCount => orderIds.length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'driverId': driverId,
      'driverName': driverName,
      'orderIds': orderIds,
      'status': status.value,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    return RouteModel(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? '',
      driverId: (map['driverId'] as String?) ?? '',
      driverName: (map['driverName'] as String?) ?? '',
      orderIds: ((map['orderIds'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      status: RouteStatus.fromString((map['status'] as String?) ?? 'planned'),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      notes: map['notes'] as String?,
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  RouteModel copyWith({
    String? id,
    String? name,
    String? driverId,
    String? driverName,
    List<String>? orderIds,
    RouteStatus? status,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      orderIds: orderIds ?? this.orderIds,
      status: status ?? this.status,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
