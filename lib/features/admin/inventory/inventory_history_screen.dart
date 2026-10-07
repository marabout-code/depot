import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/inventory_model.dart';
import '../../../providers/inventory_provider.dart';

class InventoryHistoryScreen extends ConsumerStatefulWidget {
  final InventoryModel? item;

  const InventoryHistoryScreen({super.key, this.item});

  @override
  ConsumerState<InventoryHistoryScreen> createState() =>
      _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState
    extends ConsumerState<InventoryHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(inventoryProvider.notifier)
          .loadMovements(productId: widget.item?.productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final movements = state.movements;
    final title = widget.item != null
        ? StringConstants.frInventoryHistory
        : 'Tout l\'historique';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _buildBody(movements, state.status),
    );
  }

  Widget _buildBody(List<InventoryMovement> movements, InventoryStatus status) {
    if (status == InventoryStatus.loading && movements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (movements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(StringConstants.frNoMovements,
                style: GoogleFonts.roboto(
                    fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(inventoryProvider.notifier)
          .loadMovements(productId: widget.item?.productId),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: movements.length,
        itemBuilder: (_, i) => _buildMovementCard(movements[i]),
      ),
    );
  }

  Widget _buildMovementCard(InventoryMovement movement) {
    final dateStr =
        DateFormat('dd/MM/yyyy HH:mm').format(movement.createdAt);

    Color typeColor;
    switch (movement.type) {
      case MovementType.stockIn:
      case MovementType.returnItem:
        typeColor = Colors.green;
        break;
      case MovementType.stockOut:
      case MovementType.damage:
        typeColor = AppTheme.errorColor;
        break;
      case MovementType.adjustment:
        typeColor = AppTheme.secondaryColor;
        break;
    }

    IconData typeIcon;
    switch (movement.type) {
      case MovementType.stockIn:
        typeIcon = Icons.add_circle_outline;
        break;
      case MovementType.stockOut:
        typeIcon = Icons.remove_circle_outline;
        break;
      case MovementType.adjustment:
        typeIcon = Icons.tune;
        break;
      case MovementType.damage:
        typeIcon = Icons.warning_amber;
        break;
      case MovementType.returnItem:
        typeIcon = Icons.replay;
        break;
    }

    String typeLabel;
    switch (movement.type) {
      case MovementType.stockIn:
        typeLabel = StringConstants.frStockIn;
        break;
      case MovementType.stockOut:
        typeLabel = StringConstants.frStockOut;
        break;
      case MovementType.adjustment:
        typeLabel = StringConstants.frAdjustment;
        break;
      case MovementType.damage:
        typeLabel = StringConstants.frDamage;
        break;
      case MovementType.returnItem:
        typeLabel = StringConstants.frReturn;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(typeIcon, size: 20, color: typeColor),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(typeLabel,
                      style: GoogleFonts.roboto(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: typeColor)),
                ),
                const Spacer(),
                Text(dateStr,
                    style: GoogleFonts.roboto(
                        fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.item == null)
              Text(movement.productName,
                  style: GoogleFonts.roboto(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Avant: ${movement.quantityBefore}',
                    style: GoogleFonts.roboto(
                        fontSize: 13, color: Colors.grey[600])),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward,
                    size: 16, color: Colors.grey[400]),
                const SizedBox(width: 16),
                Text('Après: ${movement.quantityAfter}',
                    style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: movement.quantityAfter < movement.quantityBefore
                            ? AppTheme.errorColor
                            : Colors.green)),
              ],
            ),
            if (movement.notes != null && movement.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(movement.notes!,
                  style: GoogleFonts.roboto(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic)),
            ],
            if (movement.performedBy != null) ...[
              const SizedBox(height: 2),
              Text('Par: ${movement.performedBy}',
                  style: GoogleFonts.roboto(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ],
        ),
      ),
    );
  }
}
