import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/local_data_service.dart';
import '../core/constants/app_constants.dart';
import '../models/product_model.dart';

enum ProductsStatus { initial, loading, loaded, error }

class ProductsState {
  final ProductsStatus status;
  final List<ProductModel> products;
  final String? error;

  const ProductsState({
    this.status = ProductsStatus.initial,
    this.products = const [],
    this.error,
  });

  ProductsState copyWith({
    ProductsStatus? status,
    List<ProductModel>? products,
    String? error,
  }) {
    return ProductsState(
      status: status ?? this.status,
      products: products ?? this.products,
      error: error,
    );
  }
}

class ProductNotifier extends StateNotifier<ProductsState> {
  final LocalDataService _data;

  ProductNotifier(this._data) : super(const ProductsState());

  Future<void> loadProducts() async {
    state = state.copyWith(status: ProductsStatus.loading);
    try {
      final products = await _data.getDocuments<ProductModel>(
        AppConstants.productsCollection,
        ProductModel.fromMap,
        orderBy: 'name',
      );
      state = ProductsState(
        status: ProductsStatus.loaded,
        products: products,
      );
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> saveProduct(ProductModel product) async {
    state = state.copyWith(status: ProductsStatus.loading);
    try {
      await _data.createDocument(
        AppConstants.productsCollection,
        product.toMap(),
        docId: product.id,
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    state = state.copyWith(status: ProductsStatus.loading);
    try {
      await _data.updateDocument(
        AppConstants.productsCollection,
        id,
        data,
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    state = state.copyWith(status: ProductsStatus.loading);
    try {
      await _data.deleteDocument(AppConstants.productsCollection, id);
      await loadProducts();
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> adjustStock(
      String productId, int newStock, String? note) async {
    state = state.copyWith(status: ProductsStatus.loading);
    try {
      await _data.updateDocument(
        AppConstants.productsCollection,
        productId,
        {'stockQuantity': newStock, 'notes': note},
      );
      await loadProducts();
    } catch (e) {
      state = state.copyWith(
        status: ProductsStatus.error,
        error: e.toString(),
      );
    }
  }

  List<ProductModel> search(String query) {
    if (query.isEmpty) return state.products;
    final q = query.toLowerCase();
    return state.products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q) ||
          p.barcode?.toLowerCase().contains(q) == true;
    }).toList();
  }
}

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductsState>((ref) {
  return ProductNotifier(ref.read(localDataServiceProvider));
});
