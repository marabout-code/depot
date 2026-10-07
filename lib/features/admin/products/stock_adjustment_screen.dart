import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../providers/product_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final ProductModel product;

  const StockAdjustmentScreen({super.key, required this.product});

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _currentStock = widget.product.stockQuantity;
    _quantityController.text = _currentStock.toString();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newStock = int.tryParse(_quantityController.text.trim());
    if (newStock == null || newStock < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une valeur valide')),
      );
      return;
    }

    await ref.read(productProvider.notifier).adjustStock(
          widget.product.id,
          newStock,
          _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.frStockAdjusted),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final difference =
        (int.tryParse(_quantityController.text) ?? _currentStock) - _currentStock;

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frStockAdjustment),
        actions: [
          TextButton(
            onPressed: state.status == ProductsStatus.loading ? null : _save,
            child: state.status == ProductsStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    StringConstants.frSave,
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2,
                        size: 40, color: AppTheme.primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.product.displayName,
                              style: GoogleFonts.roboto(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(widget.product.category,
                              style: GoogleFonts.roboto(
                                  fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '${StringConstants.frCurrentStock}: $_currentStock',
              style: GoogleFonts.roboto(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: StringConstants.frNewStock,
                prefixIcon: const Icon(Icons.inventory_2),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (difference != 0) ...[
              const SizedBox(height: 8),
              Text(
                difference > 0
                    ? 'Augmentation de +$difference'
                    : 'Réduction de $difference',
                style: GoogleFonts.roboto(
                  color: difference > 0 ? Colors.green : AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: StringConstants.frAdjustmentNote,
                prefixIcon: const Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: Text(StringConstants.frSave),
                onPressed: state.status == ProductsStatus.loading ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
