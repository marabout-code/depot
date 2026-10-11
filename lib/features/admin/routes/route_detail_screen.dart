import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../models/route_model.dart';
import '../../../models/route_status.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/route_provider.dart';
import '../orders/order_detail_screen.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  final RouteModel route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(orderProvider.notifier).loadOrders());
  }

  @override
  Widget build(BuildContext context) {
    final routeState = ref.watch(routeProvider);
    final current = routeState.routes.firstWhere(
      (r) => r.id == widget.route.id,
      orElse: () => widget.route,
    );
    final orders = ref
        .watch(orderProvider)
        .orders
        .where((o) => current.orderIds.contains(o.id))
        .toList();

    final delivered =
        orders.where((o) => o.status == OrderStatus.delivered).length;

    return Scaffold(
      appBar: AppBar(title: Text(current.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(current),
          const SizedBox(height: 20),
          _buildProgress(current, delivered, orders.length),
          const SizedBox(height: 20),
          _buildOrdersSection(orders),
          const SizedBox(height: 24),
          _buildActions(current),
        ],
      ),
    );
  }

  Widget _buildHeader(RouteModel route) {
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.route, size: 32, color: AppTheme.secondaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route.name,
                  style: GoogleFonts.roboto(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${StringConstants.frRouteDate}: ${_formatDate(route.date)}',
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 2),
              Text(
                '${StringConstants.frAddDriver}: '
                '${route.driverName.isEmpty ? '—' : route.driverName}',
                style: GoogleFonts.roboto(
                    fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        _statusBadge(route.status),
      ],
    );
  }

  Widget _buildProgress(RouteModel route, int delivered, int total) {
    final value = total == 0 ? 0.0 : delivered / total;
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(StringConstants.frRouteProgress,
                    style: GoogleFonts.roboto(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text('$delivered / $total',
                    style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersSection(List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${StringConstants.frRouteOrders} (${orders.length})',
            style: GoogleFonts.roboto(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          Text(StringConstants.frNoOrders,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey))
        else
          ...orders.map((o) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(o.orderNumber,
                      style: GoogleFonts.roboto(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(o.customerName,
                      style: GoogleFonts.roboto(fontSize: 13)),
                  trailing: _orderBadge(o.status),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(order: o)),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildActions(RouteModel route) {
    final notifier = ref.read(routeProvider.notifier);
    final children = <Widget>[];

    if (route.status == RouteStatus.planned) {
      children.add(_actionButton(
        icon: Icons.play_arrow,
        label: StringConstants.frStartRoute,
        color: Colors.purple,
        onTap: () =>
            notifier.updateRouteStatus(route.id, RouteStatus.inProgress),
      ));
    }
    if (route.status == RouteStatus.inProgress) {
      children.add(_actionButton(
        icon: Icons.check,
        label: StringConstants.frCompleteRoute,
        color: AppTheme.primaryColor,
        onTap: () =>
            notifier.updateRouteStatus(route.id, RouteStatus.completed),
      ));
    }
    if (route.status == RouteStatus.planned ||
        route.status == RouteStatus.inProgress) {
      children.add(_actionButton(
        icon: Icons.cancel_outlined,
        label: StringConstants.frRouteStatusCancelled,
        color: AppTheme.errorColor,
        onTap: () =>
            notifier.updateRouteStatus(route.id, RouteStatus.cancelled),
      ));
    }

    children.add(_actionButton(
      icon: Icons.delete_outline,
      label: StringConstants.frDelete,
      color: AppTheme.errorColor,
      onTap: () => _confirmDelete(route),
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in children)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _confirmDelete(RouteModel route) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringConstants.frDeleteConfirm),
        content: Text('Supprimer la tournée « ${route.name} » ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(routeProvider.notifier).deleteRoute(route.id);
              Navigator.of(context).pop();
            },
            child: Text(StringConstants.frDelete,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(RouteStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _routeColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _routeLabel(status),
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _routeColor(status),
        ),
      ),
    );
  }

  Widget _orderBadge(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _orderColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _orderLabel(status),
        style: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _orderColor(status),
        ),
      ),
    );
  }

  static Color _routeColor(RouteStatus status) {
    switch (status) {
      case RouteStatus.planned:
        return Colors.orange;
      case RouteStatus.inProgress:
        return Colors.purple;
      case RouteStatus.completed:
        return AppTheme.primaryColor;
      case RouteStatus.cancelled:
        return AppTheme.errorColor;
    }
  }

  static String _routeLabel(RouteStatus status) {
    switch (status) {
      case RouteStatus.planned:
        return StringConstants.frRouteStatusPlanned;
      case RouteStatus.inProgress:
        return StringConstants.frRouteStatusInProgress;
      case RouteStatus.completed:
        return StringConstants.frRouteStatusCompleted;
      case RouteStatus.cancelled:
        return StringConstants.frRouteStatusCancelled;
    }
  }

  static Color _orderColor(OrderStatus status) {
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

  static String _orderLabel(OrderStatus status) {
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
