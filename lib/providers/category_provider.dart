import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../core/database/local_data_service.dart';
import '../models/category_model.dart';

enum CategoriesStatus { initial, loading, loaded, error }

class CategoriesState {
  final CategoriesStatus status;
  final List<CategoryModel> categories;
  final String? error;

  const CategoriesState({
    this.status = CategoriesStatus.initial,
    this.categories = const [],
    this.error,
  });

  CategoriesState copyWith({
    CategoriesStatus? status,
    List<CategoryModel>? categories,
    String? error,
  }) {
    return CategoriesState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      error: error,
    );
  }
}

class CategoryNotifier extends StateNotifier<CategoriesState> {
  final LocalDataService _data;

  static const String _collection = AppConstants.categoriesCollection;

  CategoryNotifier(this._data) : super(const CategoriesState());

  Future<void> loadCategories() async {
    state = state.copyWith(status: CategoriesStatus.loading);
    try {
      final categories = await _data.getDocuments<CategoryModel>(
        _collection,
        CategoryModel.fromMap,
      );
      state = CategoriesState(
        status: CategoriesStatus.loaded,
        categories: categories,
      );
    } catch (e) {
      state = state.copyWith(
        status: CategoriesStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> addCategory(String name) async {
    final id = const Uuid().v4();
    await _data.createDocument(
      _collection,
      CategoryModel(id: id, name: name.trim()).toMap(),
      docId: id,
    );
    await loadCategories();
  }

  Future<void> updateCategory(String id, String name) async {
    await _data.updateDocument(_collection, id, {'name': name.trim()});
    await loadCategories();
  }

  Future<void> deleteCategory(String id) async {
    await _data.deleteDocument(_collection, id);
    await loadCategories();
  }
}

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoriesState>((ref) {
  return CategoryNotifier(ref.read(localDataServiceProvider));
});
