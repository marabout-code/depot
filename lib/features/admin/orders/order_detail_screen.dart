import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/driver_provider.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(driverProvider.notifier).loadDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);
    final currentOrder = state.orders.firstWhere(
      (o) => o.id == widget.order.id,
      orElse: () => widget.order,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(currentOrder.orderNumber),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(currentOrder),
          const SizedBox(height: 20),
          _buildStatusSection(currentOrder),
          const SizedBox(height: 20),
          _buildDriverSection(currentOrder),
          const SizedBox(height: 20),
          _buildCustomerInfo(currentOrder),
          const SizedBox(height: 20),
          _buildItemsSection(currentOrder),
          const SizedBox(height: 20),
          _buildSummary(currentOrder),
          if (currentOrder.notes != null) ...[
            const SizedBox(height: 20),
            _buildNotes(currentOrder),
          ],
          const SizedBox(height: 24),
          _buildActions(currentOrder),
        ],
      ),
    );
  }

  Widget _buildHeader(OrderModel order) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.receipt_long, size: 32, color: AppTheme.secondaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.orderNumber,
                  style: GoogleFonts.roboto(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${StringConstants.frCreatedAt}: ${_formatDate(order.createdAt)}',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frOrderStatus,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _statusIcon(order.status),
                const SizedBox(width: 12),
                Text(
                  _statusLabel(order.status),
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(order.status),
                  ),
                ),
              ],
            ),
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 8),
              Text(
                '${StringConstants.frDeliveredAt}: ${_formatDate(order.deliveredAt!)}',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverSection(OrderModel order) {
    final driverState = ref.watch(driverProvider);
    final drivers = driverState.drivers.toList();
    final notifier = ref.read(orderProvider.notifier);

    final bool hasDriver = order.driverName != null && order.driverId != null;
    final bool showDropdown = _selectedDriverId != null || !hasDriver;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Assignation livreur',
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (hasDriver && _selectedDriverId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping,
                        size: 20, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(order.driverName!,
                          style: GoogleFonts.roboto(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Modifier'),
                      onPressed: () =>
                          setState(() => _selectedDriverId = order.driverId),
                      style: TextButton.styleFrom(
                          foregroundColor: AppTheme.secondaryColor),
                    ),
                  ],
                ),
              ),
            if (showDropdown)
              if (drivers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(driverState.status == DriversStatus.loading
                      ? 'Chargement...'
                      : 'Aucun livreur disponible',
                      style: GoogleFonts.roboto(
                          fontSize: 14, color: Colors.grey[600])),
                )
              else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedDriverId),
                  initialValue: _selectedDriverId,
                  decoration: const InputDecoration(
                    labelText: 'Sélectionner un livreur',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: drivers
                      .map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.name,
                                style: GoogleFonts.roboto(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedDriverId = val),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 20),
                    label: Text(hasDriver ? "Mettre à jour" : "Assigner le livreur"),
                    onPressed: _selectedDriverId == null
                        ? null
                        : () {
                            final driver = drivers.firstWhere(
                                (d) => d.id == _selectedDriverId);
                            notifier.assignDriver(
                                order.id, _selectedDriverId!, driver.name);
                            setState(() => _selectedDriverId = null);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frCustomerInfo,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.person, StringConstants.frCustomerName, order.customerName),
            if (order.customerPhone != null)
              _infoRow(Icons.phone, StringConstants.frCustomerPhone, order.customerPhone!),
            if (order.deliveryAddress != null)
              _infoRow(Icons.location_on, StringConstants.frDeliveryAddress,
                  order.deliveryAddress!),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsSection(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frOrderItems,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${order.items.length} ${StringConstants.frItemsCount}',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[600])),
            const Divider(height: 20),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName,
                                style: GoogleFonts.roboto(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            Text(
                              '${item.quantity} x ${item.unitPrice.toStringAsFixed(0)} XAF',
                              style: GoogleFonts.roboto(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item.totalPrice.toStringAsFixed(0)} XAF',
                        style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(OrderModel order) {
    final total = order.totalAmount > 0 ? order.totalAmount : order.calculatedTotal;
    return Card(
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes(OrderModel order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frNotes,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(order.notes!,
                style: GoogleFonts.roboto(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(OrderModel order) {
    final notifier = ref.read(orderProvider.notifier);

    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.delivered) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(StringConstants.frUpdateStatus,
            style: GoogleFonts.roboto(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ..._availableTransitions(order.status).map((status) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton.icon(
              icon: Icon(_statusIconData(status), size: 20),
              label: Text(_transitionLabel(status)),
              onPressed: () => notifier.updateOrderStatus(order.id, status),
              style: OutlinedButton.styleFrom(
                foregroundColor: _statusColor(status),
                side: BorderSide(color: _statusColor(status)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        }),
        if (order.status != OrderStatus.cancelled) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: Text(StringConstants.frStatusCancelled),
            onPressed: () => _confirmCancel(context, order),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }

  List<OrderStatus> _availableTransitions(OrderStatus current) {
    switch (current) {
      case OrderStatus.pending:
        return [OrderStatus.confirmed, OrderStatus.cancelled];
      case OrderStatus.confirmed:
        return [OrderStatus.preparing];
      case OrderStatus.preparing:
        return [OrderStatus.outForDelivery];
      case OrderStatus.outForDelivery:
        return [OrderStatus.delivered];
      default:
        return [];
    }
  }

  String _transitionLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmer la commande';
      case OrderStatus.preparing:
        return 'Commencer la préparation';
      case OrderStatus.outForDelivery:
        return 'Envoyer en livraison';
      case OrderStatus.delivered:
        return 'Marquer comme livrée';
      default:
        return _statusLabel(status);
    }
  }

  void _confirmCancel(BuildContext context, OrderModel order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringConstants.frDeleteConfirm),
        content: const Text('Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(orderProvider.notifier).cancelOrder(order.id);
            },
            child: Text(StringConstants.frDelete,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Widget _statusIcon(OrderStatus status) {
    return Icon(_statusIconData(status), size: 28, color: _statusColor(status));
  }

  IconData _statusIconData(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.precision_manufacturing;
      case OrderStatus.outForDelivery:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.verified;
      case OrderStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return AppTheme.secondaryColor;
      case OrderStatus.outForDelivery:
        return Colors.purple;
      case OrderStatus.delivered:
        return AppTheme.primaryColor;
      case OrderStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return StringConstants.frStatusPending;
      case OrderStatus.confirmed:
        return StringConstants.frStatusConfirmed;
      case OrderStatus.preparing:
        return StringConstants.frStatusPreparing;
      case OrderStatus.outForDelivery:
        return StringConstants.frStatusOutForDelivery;
      case OrderStatus.delivered:
        return StringConstants.frStatusDelivered;
      case OrderStatus.cancelled:
        return StringConstants.frStatusCancelled;
    }
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.roboto(color: Colors.grey[600], fontSize: 14)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w500, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
