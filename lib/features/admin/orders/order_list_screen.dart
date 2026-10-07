import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../providers/order_provider.dart';
import 'order_create_screen.dart';
import 'order_detail_screen.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  OrderStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(orderProvider);
    final notifier = ref.read(orderProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frOrders),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToCreate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildStatusChips(),
          Expanded(
            child: _buildBody(state, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: StringConstants.frSearchOrder,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
    );
  }

  Widget _buildStatusChips() {
    final statuses = [null, ...OrderStatus.values];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: statuses.map((status) {
          final selected = _statusFilter == status;
          final label = status == null
              ? 'Tous'
              : _statusLabel(status);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(label, style: GoogleFonts.roboto(fontSize: 13)),
              selected: selected,
              selectedColor: _statusColor(status).withValues(alpha: 0.2),
              onSelected: (_) => setState(() => _statusFilter = status),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(OrdersState state, OrderNotifier notifier) {
    switch (state.status) {
      case OrdersStatus.initial:
      case OrdersStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case OrdersStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? StringConstants.frErrorGeneral),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => notifier.loadOrders(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case OrdersStatus.loaded:
        var orders = _statusFilter == null
            ? state.orders
            : notifier.filterByStatus(_statusFilter);
        if (_searchQuery.isNotEmpty) {
          orders = notifier.search(_searchQuery);
        }

        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(StringConstants.frNoOrders,
                    style: GoogleFonts.roboto(
                        fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => notifier.loadOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _buildOrderCard(orders[i], context),
          ),
        );
    }
  }

  Widget _buildOrderCard(OrderModel order, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToDetail(context, order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order.orderNumber,
                      style: GoogleFonts.roboto(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  _statusBadge(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(order.customerName,
                      style: GoogleFonts.roboto(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('${order.items.length} ${StringConstants.frItemsCount}',
                      style: GoogleFonts.roboto(
                          fontSize: 13, color: Colors.grey[600])),
                  const Spacer(),
                  Text(
                    '${order.totalAmount > 0 ? order.totalAmount.toStringAsFixed(0) : order.calculatedTotal.toStringAsFixed(0)} XAF',
                    style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(order.createdAt),
                style: GoogleFonts.roboto(
                    fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(OrderStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _statusColor(status),
        ),
      ),
    );
  }

  Color _statusColor(OrderStatus? status) {
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
      default:
        return Colors.grey;
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} ${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrderCreateScreen()),
    );
  }

  void _navigateToDetail(BuildContext context, OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(order: order),
      ),
    );
  }
}
