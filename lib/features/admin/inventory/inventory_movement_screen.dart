import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inventory_model.dart';
import '../../../providers/inventory_provider.dart';

class InventoryMovementScreen extends ConsumerStatefulWidget {
  final InventoryModel item;

  const InventoryMovementScreen({super.key, required this.item});

  @override
  ConsumerState<InventoryMovementScreen> createState() =>
      _InventoryMovementScreenState();
}

class _InventoryMovementScreenState
    extends ConsumerState<InventoryMovementScreen> {
  MovementType _selectedType = MovementType.stockIn;
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  int _currentStock = 0;
  int _newStock = 0;

  static const _movementTypes = [
    MovementType.stockIn,
    MovementType.stockOut,
    MovementType.adjustment,
    MovementType.damage,
    MovementType.returnItem,
  ];

  String _movementLabel(MovementType type) {
    switch (type) {
      case MovementType.stockIn:
        return StringConstants.frStockIn;
      case MovementType.stockOut:
        return StringConstants.frStockOut;
      case MovementType.adjustment:
        return StringConstants.frAdjustment;
      case MovementType.damage:
        return StringConstants.frDamage;
      case MovementType.returnItem:
        return StringConstants.frReturn;
    }
  }

  IconData _movementIcon(MovementType type) {
    switch (type) {
      case MovementType.stockIn:
        return Icons.add_circle_outline;
      case MovementType.stockOut:
        return Icons.remove_circle_outline;
      case MovementType.adjustment:
        return Icons.tune;
      case MovementType.damage:
        return Icons.warning_amber;
      case MovementType.returnItem:
        return Icons.replay;
    }
  }

  @override
  void initState() {
    super.initState();
    _currentStock = widget.item.availableQuantity > 0
        ? widget.item.availableQuantity
        : widget.item.currentStock;
    _newStock = _currentStock;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final qty = int.tryParse(_quantityController.text) ?? 0;
    setState(() {
      switch (_selectedType) {
        case MovementType.stockIn:
        case MovementType.returnItem:
          _newStock = _currentStock + qty;
          break;
        case MovementType.stockOut:
        case MovementType.damage:
          _newStock = (_currentStock - qty).clamp(0, _currentStock);
          break;
        case MovementType.adjustment:
          _newStock = qty;
          break;
      }
    });
  }

  Future<void> _record() async {
    final qty = int.tryParse(_quantityController.text);
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une quantité valide')),
      );
      return;
    }

    if (_selectedType == MovementType.adjustment && qty == _currentStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun changement détecté')),
      );
      return;
    }

    await ref.read(inventoryProvider.notifier).recordMovement(
          productId: widget.item.productId,
          productName: widget.item.productName,
          type: _selectedType,
          quantity: qty,
          currentStock: _currentStock,
          performedBy: 'Admin',
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.frMovementRecorded),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final isLoading = state.status == InventoryStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frInventoryMovement),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _record,
            child: isLoading
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.productName,
                      style: GoogleFonts.roboto(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _stockChip('Stock actuel', '$_currentStock',
                          AppTheme.primaryColor),
                      const SizedBox(width: 12),
                      _stockChip(
                          'Nouveau stock',
                          '$_newStock',
                          _newStock < _currentStock
                              ? AppTheme.errorColor
                              : Colors.green),
                    ],
                  ),
                  if (widget.item.location != null) ...[
                    const SizedBox(height: 8),
                    Text('Emplacement: ${widget.item.location}',
                        style: GoogleFonts.roboto(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Type de mouvement',
              style: GoogleFonts.roboto(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._movementTypes.map((type) {
            final selected = _selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  setState(() => _selectedType = type);
                  _updatePreview();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primaryColor.withValues(alpha: 0.1)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primaryColor
                          : Colors.grey[300]!,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_movementIcon(type),
                          color: selected
                              ? AppTheme.primaryColor
                              : Colors.grey[600]),
                      const SizedBox(width: 12),
                      Text(_movementLabel(type),
                          style: GoogleFonts.roboto(
                              fontSize: 15,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected
                                  ? AppTheme.primaryColor
                                  : Colors.black87)),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          TextField(
            controller: _quantityController,
            decoration: InputDecoration(
              labelText: _selectedType == MovementType.adjustment
                  ? 'Nouvelle quantité totale'
                  : 'Quantité',
              prefixIcon: const Icon(Icons.numbers),
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _updatePreview(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: StringConstants.frAdjustmentNote,
              prefixIcon: const Icon(Icons.notes),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _stockChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: GoogleFonts.roboto(
                    fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 4),
            Text(value,
                style: GoogleFonts.roboto(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
