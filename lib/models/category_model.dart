class CategoryModel {
  final String id;
  final String name;

  const CategoryModel({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as String,
        name: map['name'] as String,
      );

  CategoryModel copyWith({String? id, String? name}) => CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
      );
}
