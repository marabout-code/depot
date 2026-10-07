import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../providers/delivery_provider.dart';
import '../navigation/driver_navigation_screen.dart';

class DeliveryDetailScreen extends ConsumerWidget {
  final OrderModel order;

  const DeliveryDetailScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverDeliveriesProvider);
    final currentOrder = state.orders.firstWhere(
      (o) => o.id == order.id,
      orElse: () => order,
    );
    final isLoading = state.status == DriverDeliveriesStatus.updating;
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      appBar: AppBar(title: Text('${StringConstants.frDeliveryDetail} - ${currentOrder.orderNumber}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusHeader(currentOrder),
          const SizedBox(height: 20),
          _buildCustomerCard(currentOrder, context),
          const SizedBox(height: 16),
          _buildItemsCard(currentOrder, fmt),
          const SizedBox(height: 16),
          _buildInfoCard(currentOrder, fmt),
          if (currentOrder.status != OrderStatus.delivered && currentOrder.status != OrderStatus.cancelled) ...[
            const SizedBox(height: 24),
            _buildActionButtons(currentOrder, context, ref, isLoading),
          ],
          if (currentOrder.status == OrderStatus.delivered) ...[
            const SizedBox(height: 24),
            _buildDeliveredCard(currentOrder),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(OrderModel order) {
    Color color;
    String label;
    IconData icon;
    switch (order.status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        color = AppTheme.secondaryColor;
        label = 'Prête à être ramassée';
        icon = Icons.inventory_2;
        break;
      case OrderStatus.outForDelivery:
        color = Colors.purple;
        label = 'En cours de livraison';
        icon = Icons.local_shipping;
        break;
      case OrderStatus.delivered:
        color = Colors.green;
        label = 'Livrée avec succès';
        icon = Icons.check_circle;
        break;
      case OrderStatus.cancelled:
        color = AppTheme.errorColor;
        label = 'Annulée';
        icon = Icons.cancel;
        break;
    }

    return Card(
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.orderNumber,
                      style: GoogleFonts.roboto(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(OrderModel order, BuildContext context) {
    final nav = Navigator.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frCustomerDetails,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.person, order.customerName),
            if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
              _infoRow(Icons.phone, order.customerPhone!),
            if (order.deliveryAddress != null && order.deliveryAddress!.isNotEmpty)
              _infoRow(Icons.location_on, order.deliveryAddress!),
            if (order.status != OrderStatus.delivered &&
                order.status != OrderStatus.cancelled) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.navigation),
                  label: Text(StringConstants.frDeliveryNavigation),
                  onPressed: () => nav.push(
                    MaterialPageRoute(
                      builder: (_) => DriverNavigationScreen(order: order),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemsCard(OrderModel order, NumberFormat fmt) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frItemsToDeliver,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text('${item.quantity}x',
                              style: GoogleFonts.roboto(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: GoogleFonts.roboto(
                                    fontWeight: FontWeight.w500)),
                            Text(
                                '${fmt.format(item.unitPrice.toInt())} XAF / unité',
                                style: GoogleFonts.roboto(
                                    fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ),
                      Text('${fmt.format(item.totalPrice.toInt())} XAF',
                          style: GoogleFonts.roboto(
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(OrderModel order, NumberFormat fmt) {
    final total =
        order.totalAmount > 0 ? order.totalAmount : order.calculatedTotal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frOrderSummary,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.receipt, '${order.totalItems} ${StringConstants.frItemsCount}'),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(StringConstants.frTotalAmount,
                    style: GoogleFonts.roboto(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${fmt.format(total.toInt())} XAF',
                    style: GoogleFonts.roboto(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ],
            ),
            if (order.notes != null && order.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(StringConstants.frNotes,
                  style: GoogleFonts.roboto(
                      fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(order.notes!,
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: Colors.grey[600])),
            ],
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 12),
              _infoRow(Icons.check_circle, 'Livrée le ${DateFormat('dd/MM/yyyy HH:mm').format(order.deliveredAt!)}'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(
      OrderModel order, BuildContext context, WidgetRef ref, bool isLoading) {
    final notifier = ref.read(driverDeliveriesProvider.notifier);

    if (order.status == OrderStatus.confirmed ||
        order.status == OrderStatus.preparing) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.inventory),
              label: Text(StringConstants.frPickUp,
                  style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: isLoading
                  ? null
                  : () => _confirmAction(
                      context,
                      StringConstants.frConfirmPickUp,
                      'Confirmez-vous avoir ramassé cette commande ?',
                      () => notifier.pickUpOrder(order),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (order.status == OrderStatus.outForDelivery) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle),
              label: Text(StringConstants.frMarkDelivered,
                  style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w600, fontSize: 16)),
              onPressed: isLoading
                  ? null
                  : () => _confirmAction(
                      context,
                      StringConstants.frConfirmDelivery,
                      'Confirmez-vous que la livraison a été effectuée ?',
                      () => notifier.completeDelivery(order),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cancel_outlined),
              label: Text(StringConstants.frMarkFailed,
                  style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w500, fontSize: 15)),
              onPressed: isLoading
                  ? null
                  : () => _showFailDialog(context, order, notifier),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildDeliveredCard(OrderModel order) {
    return Card(
      color: Colors.green.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.celebration, size: 48, color: Colors.green),
            const SizedBox(height: 12),
            Text('Livraison terminée !',
                style: GoogleFonts.roboto(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 4),
              Text(
                  'Livrée le ${DateFormat('dd/MM/yyyy à HH:mm').format(order.deliveredAt!)}',
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.roboto(fontSize: 14, height: 1.3)),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
      BuildContext context, String title, String content, VoidCallback action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              action();
            },
            child: Text('Confirmer',
                style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showFailDialog(
      BuildContext context, OrderModel order, DeliveryNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringConstants.frMarkFailed),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Raison de l\'échec de la livraison :'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Client absent, adresse introuvable...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (controller.text.trim().isNotEmpty) {
                notifier.failDelivery(order, controller.text.trim());
              }
            },
            child: Text('Enregistrer',
                style: const TextStyle(
                    color: AppTheme.errorColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
