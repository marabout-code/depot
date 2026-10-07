import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/product_provider.dart';

class OrderCreateScreen extends ConsumerStatefulWidget {
  const OrderCreateScreen({super.key});

  @override
  ConsumerState<OrderCreateScreen> createState() => _OrderCreateScreenState();
}

class _OrderCreateScreenState extends ConsumerState<OrderCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _deliveryAddressController = TextEditingController();
  final _notesController = TextEditingController();
  final _quantityControllers = <String, TextEditingController>{};
  final _selectedProducts = <ProductModel, int>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deliveryAddressController.dispose();
    _notesController.dispose();
    for (final c in _quantityControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addProduct(ProductModel product) {
    if (_selectedProducts.containsKey(product)) return;
    setState(() {
      _selectedProducts[product] = 1;
      _quantityControllers[product.id] =
          TextEditingController(text: '1');
    });
  }

  void _removeProduct(ProductModel product) {
    setState(() {
      _selectedProducts.remove(product);
      _quantityControllers.remove(product.id)?.dispose();
    });
  }

  void _updateQuantity(ProductModel product, String value) {
    final qty = int.tryParse(value);
    if (qty != null && qty > 0) {
      setState(() => _selectedProducts[product] = qty);
    }
  }

  Future<void> _createOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez au moins un article')),
      );
      return;
    }

    final items = _selectedProducts.entries.map((e) {
      return OrderItem(
        productId: e.key.id,
        productName: e.key.displayName,
        quantity: e.value,
        unitPrice: e.key.price,
      );
    }).toList();

    final now = DateTime.now();
    final orderNumber =
        '${StringConstants.frOrderNumberPrefix}-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-'
        '${now.millisecondsSinceEpoch.toString().substring(7)}';

    final order = OrderModel(
      id: const Uuid().v4(),
      orderNumber: orderNumber,
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      deliveryAddress: _deliveryAddressController.text.trim().isEmpty
          ? null
          : _deliveryAddressController.text.trim(),
      items: items,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await ref.read(orderProvider.notifier).createOrder(order);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.frOrderCreated),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final orderState = ref.watch(orderProvider);
    final total = _selectedProducts.entries.fold<double>(
      0,
      (sum, e) => sum + (e.key.price * e.value),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frCreateOrder),
        actions: [
          TextButton(
            onPressed:
                orderState.status == OrdersStatus.loading ? null : _createOrder,
            child: orderState.status == OrdersStatus.loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(StringConstants.frSave,
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle(StringConstants.frCustomerInfo),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerNameController,
              decoration: InputDecoration(
                labelText: StringConstants.frCustomerName,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (v) =>
                  v?.isEmpty == true ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _customerPhoneController,
              decoration: InputDecoration(
                labelText: StringConstants.frCustomerPhone,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deliveryAddressController,
              decoration: InputDecoration(
                labelText: StringConstants.frDeliveryAddress,
                prefixIcon: const Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(StringConstants.frOrderItems),
            const SizedBox(height: 12),
            // Product selector
            if (productState.status == ProductsStatus.loaded)
              _buildProductSelector(productState.products)
            else
              const LinearProgressIndicator(),
            const SizedBox(height: 12),
            // Selected items list
            if (_selectedProducts.isNotEmpty) ...[
              ..._selectedProducts.entries.map((e) =>
                  _buildSelectedItemCard(e.key, e.value)),
              const SizedBox(height: 16),
              Card(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(StringConstants.frTotalAmount,
                          style: GoogleFonts.roboto(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${total.toStringAsFixed(0)} XAF',
                          style: GoogleFonts.roboto(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            _buildSectionTitle(StringConstants.frNotes),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Optionnel',
                prefixIcon: const Icon(Icons.notes),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.roboto(
            fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryColor));
  }

  Widget _buildProductSelector(List<ProductModel> products) {
    final active = products.where((p) => p.isActive).toList();
    return Column(
      children: [
        TextFormField(
          readOnly: true,
          decoration: InputDecoration(
            labelText: StringConstants.frSelectProduct,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          onTap: () => _showProductPicker(context, active),
        ),
      ],
    );
  }

  void _showProductPicker(BuildContext context, List<ProductModel> products) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(StringConstants.frSelectProduct,
                  style: GoogleFonts.roboto(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  final alreadyAdded = _selectedProducts.containsKey(p);
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.inventory_2,
                          size: 20, color: AppTheme.primaryColor),
                    ),
                    title: Text(p.displayName,
                        style: GoogleFonts.roboto(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        '${p.price.toStringAsFixed(0)} XAF • Stock: ${p.stockQuantity}',
                        style: GoogleFonts.roboto(fontSize: 12)),
                    trailing: alreadyAdded
                        ? Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : const Icon(Icons.add_circle_outline),
                    onTap: () {
                      _addProduct(p);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedItemCard(ProductModel product, int quantity) {
    final controller = _quantityControllers[product.id]!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.displayName,
                      style: GoogleFonts.roboto(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${product.price.toStringAsFixed(0)} XAF / unité',
                      style: GoogleFonts.roboto(
                          fontSize: 12, color: Colors.grey[600])),
                  Text('Sous-total: ${(product.price * quantity).toStringAsFixed(0)} XAF',
                      style: GoogleFonts.roboto(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor)),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: StringConstants.frQuantity,
                  labelStyle: GoogleFonts.roboto(fontSize: 11),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                onChanged: (v) => _updateQuantity(product, v),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppTheme.errorColor),
              onPressed: () => _removeProduct(product),
            ),
          ],
        ),
      ),
    );
  }
}
