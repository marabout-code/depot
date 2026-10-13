class DepotModel {
  /// The only two values the `depots.status` check constraint allows. A
  /// deactivated depot keeps its accounts and data but can no longer be the
  /// target of a new account (see `admin_create_user`).
  static const String statusActive = 'active';
  static const String statusInactive = 'inactive';

  final String id;
  final String name;
  final String city;
  final String status;
  final DateTime createdAt;

  DepotModel({
    required this.id,
    required this.name,
    this.city = '',
    this.status = statusActive,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName =>
      city.isNotEmpty ? '$name · $city' : name;

  bool get isActive => status == statusActive;

  bool get isInactive => !isActive;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DepotModel.fromMap(Map<String, dynamic> map) {
    return DepotModel(
      id: map['id'] as String,
      name: map['name'] as String,
      city: (map['city'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }

  DepotModel copyWith({
    String? id,
    String? name,
    String? city,
    String? status,
    DateTime? createdAt,
  }) {
    return DepotModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}