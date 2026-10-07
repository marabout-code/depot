import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductModel? existingProduct;

  const ProductFormScreen({super.key, this.existingProduct});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _packageSizeController = TextEditingController();
  final _packQuantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costController = TextEditingController();
  final _stockQuantityController = TextEditingController();
  final _reorderLevelController = TextEditingController();
  final _barcodeController = TextEditingController();

  String _category = '';
  bool _isActive = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(categoryProvider.notifier).loadCategories());
    if (widget.existingProduct != null) {
      _isEditing = true;
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _brandController.text = p.brand;
      _packageSizeController.text = p.packageSize;
      _packQuantityController.text = p.packQuantity.toString();
      _priceController.text = p.price.toStringAsFixed(0);
      _costController.text = p.cost.toStringAsFixed(0);
      _stockQuantityController.text = p.stockQuantity.toString();
      _reorderLevelController.text = p.reorderLevel.toString();
      _barcodeController.text = p.barcode ?? '';
      _category = p.category;
      _isActive = p.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _packageSizeController.dispose();
    _packQuantityController.dispose();
    _priceController.dispose();
    _costController.dispose();
    _stockQuantityController.dispose();
    _reorderLevelController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final product = ProductModel(
      id: _isEditing
          ? widget.existingProduct!.id
          : const Uuid().v4(),
      name: _nameController.text.trim(),
      category: _category,
      brand: _brandController.text.trim(),
      packageSize: _packageSizeController.text.trim(),
      packQuantity: int.parse(_packQuantityController.text.trim()),
      price: double.parse(_priceController.text.trim()),
      cost: double.tryParse(_costController.text.trim()) ?? 0,
      stockQuantity: int.parse(_stockQuantityController.text.trim()),
      reorderLevel: int.parse(_reorderLevelController.text.trim()),
      isActive: _isActive,
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      createdAt: _isEditing ? widget.existingProduct!.createdAt : null,
    );

    await ref.read(productProvider.notifier).saveProduct(product);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.frProductSaved),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final categoriesState = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            _isEditing ? StringConstants.frEditProduct : StringConstants.frAddProduct),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionTitle('Informations générales'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _nameController,
              label: StringConstants.frProductName,
              icon: Icons.label,
              validator: (v) =>
                  v?.isEmpty == true ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            _buildDropdown(categoriesState),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _brandController,
              label: StringConstants.frProductBrand,
              icon: Icons.business,
              validator: (v) =>
                  v?.isEmpty == true ? 'Marque requise' : null,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Conditionnement'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _packageSizeController,
                    label: StringConstants.frPackageSize,
                    icon: Icons.settings_suggest,
                    hint: '33cl',
                    validator: (v) =>
                        v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _packQuantityController,
                    label: StringConstants.frPackQuantity,
                    icon: Icons.inventory,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.isEmpty == true ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Prix et stock'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _priceController,
                    label: StringConstants.frProductPrice,
                    icon: Icons.monetization_on,
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        v?.isEmpty == true ? 'Prix requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _costController,
                    label: 'Coût unitaire',
                    icon: Icons.money_off,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _stockQuantityController,
                    label: StringConstants.frStockQuantity,
                    icon: Icons.inventory_2,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _reorderLevelController,
                    label: StringConstants.frReorderLevel,
                    icon: Icons.warning_amber,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Options'),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _barcodeController,
              label: StringConstants.frBarcode,
              icon: Icons.qr_code,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: Text('Produit actif',
                  style: GoogleFonts.roboto()),
              value: _isActive,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.roboto(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }

  Widget _buildDropdown(CategoriesState categoriesState) {
    final categories = categoriesState.categories;
    return DropdownButtonFormField<String>(
      initialValue: _category.isEmpty && categories.isNotEmpty ? null : _category,
      decoration: InputDecoration(
        labelText: StringConstants.frProductCategory,
        prefixIcon: const Icon(Icons.category),
      ),
      items: categories.map((c) {
        return DropdownMenuItem(value: c.name, child: Text(c.name));
      }).toList(),
      onChanged: (v) {
        if (v != null) setState(() => _category = v);
      },
      validator: (v) => v == null || v.isEmpty ? 'Catégorie requise' : null,
    );
  }
}
