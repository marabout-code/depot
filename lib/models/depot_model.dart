class DepotModel {
  final String id;
  final String name;
  final String city;
  final String address;
  final String status;
  final DateTime createdAt;

  DepotModel({
    required this.id,
    required this.name,
    this.city = '',
    this.address = '',
    this.status = 'active',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get displayName =>
      city.isNotEmpty ? '$name · $city' : name;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'address': address,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DepotModel.fromMap(Map<String, dynamic> map) {
    return DepotModel(
      id: map['id'] as String,
      name: map['name'] as String,
      city: (map['city'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'active',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    );
  }

  DepotModel copyWith({
    String? id,
    String? name,
    String? city,
    String? address,
    String? status,
    DateTime? createdAt,
  }) {
    return DepotModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}