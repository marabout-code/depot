import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../models/route_model.dart';
import '../../../models/route_status.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/route_provider.dart';
import '../deliveries/delivery_detail_screen.dart';

/// Driver view of the tournées assigned to them: each route lists its orders and
/// can be started in one tap, which marks every order out for delivery.
class MyRoutesScreen extends ConsumerStatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  ConsumerState<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends ConsumerState<MyRoutesScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        ref.read(routeProvider.notifier).loadDriverRoutes(userId);
      }
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(StringConstants.frMyRoutes)),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = ref.read(authProvider).user?.id;
          if (userId != null) {
            await ref.read(routeProvider.notifier).loadDriverRoutes(userId);
          }
          await ref.read(orderProvider.notifier).loadOrders();
        },
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(RoutesState state) {
    if (state.status == RoutesStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final routes = state.routes
        .where((r) => r.status != RouteStatus.cancelled)
        .toList();

    if (routes.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Center(
            child: Text(StringConstants.frNoActiveRoutes,
                style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey)),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: routes.length,
      itemBuilder: (_, i) => _buildRoute(routes[i]),
    );
  }

  Widget _buildRoute(RouteModel route) {
    final orders = ref
        .watch(orderProvider)
        .orders
        .where((o) => route.orderIds.contains(o.id))
        .toList();
    final delivered =
        orders.where((o) => o.status == OrderStatus.delivered).length;
    final total = orders.length;
    final value = total == 0 ? 0.0 : delivered / total;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.route, color: AppTheme.primaryColor),
        ),
        title: Text(route.name,
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatDate(route.date)} • $delivered/$total',
                style: GoogleFonts.roboto(
                    fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: Colors.grey[300],
              ),
            ),
          ],
        ),
        trailing: _statusBadge(route.status),
        children: [
          ...orders.map((o) => ListTile(
                dense: true,
                title: Text(o.orderNumber,
                    style: GoogleFonts.roboto(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(o.customerName,
                    style: GoogleFonts.roboto(fontSize: 12)),
                trailing: _orderBadge(o.status),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DeliveryDetailScreen(order: o),
                  ),
                ),
              )),
          if (route.status == RouteStatus.planned)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.play_arrow),
                  label: Text(StringConstants.frStartRoute),
                  onPressed: _busy ? null : () => _startRoute(route, orders),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startRoute(RouteModel route, List<OrderModel> orders) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(driverDeliveriesProvider.notifier);

    for (final order in orders) {
      if (order.status == OrderStatus.delivered ||
          order.status == OrderStatus.cancelled) {
        continue;
      }
      await notifier.pickUpOrder(order);
    }
    await ref
        .read(routeProvider.notifier)
        .updateRouteStatus(route.id, RouteStatus.inProgress);
    await ref.read(orderProvider.notifier).loadOrders();

    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      const SnackBar(content: Text(StringConstants.frStartRoute)),
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
          fontSize: 11,
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
