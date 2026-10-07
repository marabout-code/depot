import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../providers/product_provider.dart';
import 'product_form_screen.dart';
import 'stock_adjustment_screen.dart';

class ProductDetailScreen extends ConsumerWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(productProvider);
    final currentProduct = state.products.firstWhere(
      (p) => p.id == product.id,
      orElse: () => product,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentProduct.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProductFormScreen(existingProduct: currentProduct),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(currentProduct),
          const SizedBox(height: 20),
          _buildStockCard(currentProduct, context),
          const SizedBox(height: 20),
          _buildInfoCard(currentProduct),
          const SizedBox(height: 20),
          _buildActions(currentProduct, context, ref),
          if (currentProduct.barcode != null) ...[
            const SizedBox(height: 20),
            _buildBarcodeCard(currentProduct),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ProductModel product) {
    return Row(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.inventory_2,
              size: 40, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(product.displayName,
                  style: GoogleFonts.roboto(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(product.category,
                  style: GoogleFonts.roboto(
                      fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.isActive
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      product.isActive ? 'Actif' : 'Inactif',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: product.isActive ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStockCard(ProductModel product, BuildContext context) {
    final stockColor = product.stockQuantity <= 0
        ? AppTheme.errorColor
        : product.needsReorder
            ? AppTheme.secondaryColor
            : AppTheme.primaryColor;

    final stockLabel = product.stockQuantity <= 0
        ? StringConstants.frOutOfStock
        : product.needsReorder
            ? StringConstants.frLowStock
            : StringConstants.frInStock;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frStockManagement,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('${product.stockQuantity}',
                          style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: stockColor)),
                      const SizedBox(height: 4),
                      Text('En stock',
                          style: GoogleFonts.roboto(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                Expanded(
                  child: Column(
                    children: [
                      Text('${product.reorderLevel}',
                          style: GoogleFonts.roboto(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Seuil',
                          style: GoogleFonts.roboto(
                              fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Valeur du stock',
                      style: GoogleFonts.roboto(
                          fontSize: 13, color: Colors.grey[600])),
                ),
                Text('${product.stockValue.toStringAsFixed(0)} XAF',
                    style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: stockColor)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: stockColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: stockColor),
                  const SizedBox(width: 6),
                  Text(stockLabel,
                      style: GoogleFonts.roboto(
                          color: stockColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ProductModel product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations',
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.category, StringConstants.frProductCategory,
                product.category),
            _infoRow(Icons.business, StringConstants.frProductBrand,
                product.brand),
            _infoRow(Icons.settings_suggest, StringConstants.frPackageSize,
                product.packageSize),
            _infoRow(Icons.inventory, StringConstants.frPackQuantity,
                '${product.packQuantity} unités/pack'),
            _infoRow(Icons.monetization_on, StringConstants.frProductPrice,
                '${product.price.toStringAsFixed(0)} XAF'),
            _infoRow(Icons.money_off, 'Coût unitaire',
                '${product.cost.toStringAsFixed(0)} XAF'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.roboto(color: Colors.grey[600])),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeCard(ProductModel product) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.qr_code, size: 32, color: Colors.grey[600]),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(StringConstants.frBarcode,
                    style: GoogleFonts.roboto(
                        fontSize: 13, color: Colors.grey[600])),
                Text(product.barcode!,
                    style: GoogleFonts.roboto(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
      ProductModel product, BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add_shopping_cart),
            label: Text('Ajuster le stock'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    StockAdjustmentScreen(product: product),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.secondaryColor,
              foregroundColor: Colors.black,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.delete_outline),
            label: Text(StringConstants.frDelete),
            onPressed: () => _confirmDelete(context, ref, product),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringConstants.frDeleteConfirm),
        content: Text(StringConstants.frDeleteWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(productProvider.notifier).deleteProduct(product.id);
              Navigator.of(context).pop();
            },
            child: Text(StringConstants.frDelete,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
