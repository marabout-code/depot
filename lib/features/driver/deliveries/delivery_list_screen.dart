import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/auth_provider.dart';
import 'delivery_detail_screen.dart';

class DeliveryListScreen extends ConsumerStatefulWidget {
  const DeliveryListScreen({super.key});

  @override
  ConsumerState<DeliveryListScreen> createState() => _DeliveryListScreenState();
}

class _DeliveryListScreenState extends ConsumerState<DeliveryListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        ref.read(driverDeliveriesProvider.notifier).loadDriverData(userId);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverDeliveriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frMyDeliveries),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Actives'),
                  if (state.activeOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${state.activeOrders.length}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Terminées'),
                  if (state.completedOrders.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${state.completedOrders.length}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final userId = ref.read(authProvider).user?.id;
              if (userId != null) {
                ref.read(driverDeliveriesProvider.notifier).loadDriverData(userId);
              }
            },
          ),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(DriverDeliveriesState state) {
    switch (state.status) {
      case DriverDeliveriesStatus.initial:
      case DriverDeliveriesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DriverDeliveriesStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? StringConstants.frErrorGeneral),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final userId = ref.read(authProvider).user?.id;
                  if (userId != null) {
                    ref
                        .read(driverDeliveriesProvider.notifier)
                        .loadDriverData(userId);
                  }
                },
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case DriverDeliveriesStatus.loaded:
      case DriverDeliveriesStatus.updating:
        return TabBarView(
          controller: _tabController,
          children: [
            _buildOrderList(state.activeOrders, state),
            _buildOrderList(state.completedOrders, state),
          ],
        );
    }
  }

  Widget _buildOrderList(List<OrderModel> orders, DriverDeliveriesState state) {
    if (state.status == DriverDeliveriesStatus.updating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Mise à jour...'),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      final isActive = orders == state.activeOrders;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.assignment : Icons.check_circle_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              isActive
                  ? StringConstants.frNoActiveDeliveries
                  : StringConstants.frNoCompletedDeliveries,
              style: GoogleFonts.roboto(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId = ref.read(authProvider).user?.id;
        if (userId != null) {
          ref.read(driverDeliveriesProvider.notifier).loadDriverData(userId);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) => _buildOrderCard(orders[i]),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final isActive = order.status != OrderStatus.delivered;
    Color statusColor;
    String statusLabel;
    switch (order.status) {
      case OrderStatus.pending:
        statusColor = AppTheme.secondaryColor;
        statusLabel = StringConstants.frStatusPending;
        break;
      case OrderStatus.confirmed:
        statusColor = Colors.blue;
        statusLabel = StringConstants.frStatusConfirmed;
        break;
      case OrderStatus.preparing:
        statusColor = Colors.orange;
        statusLabel = StringConstants.frStatusPreparing;
        break;
      case OrderStatus.outForDelivery:
        statusColor = Colors.purple;
        statusLabel = StringConstants.frStatusOutForDelivery;
        break;
      case OrderStatus.delivered:
        statusColor = Colors.green;
        statusLabel = StringConstants.frStatusDelivered;
        break;
      case OrderStatus.cancelled:
        statusColor = AppTheme.errorColor;
        statusLabel = StringConstants.frStatusCancelled;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DeliveryDetailScreen(order: order),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isActive ? Icons.local_shipping : Icons.check_circle,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.orderNumber,
                        style: GoogleFonts.roboto(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(order.customerName,
                        style: GoogleFonts.roboto(
                            fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text('${order.totalItems} articles',
                        style: GoogleFonts.roboto(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel,
                    style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
