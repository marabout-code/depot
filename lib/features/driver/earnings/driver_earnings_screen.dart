import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/delivery_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../models/driver_model.dart';
import '../../../models/order_status.dart';

class DriverEarningsScreen extends ConsumerStatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  ConsumerState<DriverEarningsScreen> createState() =>
      _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends ConsumerState<DriverEarningsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) {
        ref.read(driverDeliveriesProvider.notifier).loadDriverData(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverDeliveriesProvider);
    final profile = state.driverProfile;
    final fmt = NumberFormat('#,###', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frMyEarnings),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final userId = ref.read(authProvider).user?.id;
              if (userId != null) {
                ref
                    .read(driverDeliveriesProvider.notifier)
                    .loadDriverData(userId);
              }
            },
          ),
        ],
      ),
      body: state.status == DriverDeliveriesStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == DriverDeliveriesStatus.error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 12),
                      Text(state.error ?? StringConstants.frErrorGeneral),
                    ],
                  ),
                )
              : _buildBody(state, profile, fmt),
    );
  }

  Widget _buildBody(
      DriverDeliveriesState state, DriverModel? profile, NumberFormat fmt) {
    final totalEarnings = profile?.performance.totalEarnings ?? 0;
    final totalDeliveries = profile?.performance.totalDeliveries ?? 0;
    final completedOrders = profile?.performance.completedOrders ?? 0;
    final avgRating = profile?.performance.averageRating ?? 0;
    final commissionRate = profile?.commissionRate ?? 10;

    final deliveredOrders = state.orders
        .where((o) => o.status == OrderStatus.delivered)
        .toList();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDay =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    final todayDeliveries =
        deliveredOrders.where((o) => o.deliveredAt != null && o.deliveredAt!.isAfter(todayStart)).length;
    final weekDeliveries =
        deliveredOrders.where((o) => o.deliveredAt != null && o.deliveredAt!.isAfter(weekStartDay)).length;

    double todayEarnings = 0;
    double weekEarnings = 0;
    for (final o in deliveredOrders) {
      final rev = o.totalAmount > 0 ? o.totalAmount : o.calculatedTotal;
      final comm = rev * (commissionRate / 100);
      if (o.deliveredAt != null) {
        if (o.deliveredAt!.isAfter(todayStart)) todayEarnings += comm;
        if (o.deliveredAt!.isAfter(weekStartDay)) weekEarnings += comm;
      }
    }

    if (state.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(StringConstants.frNoEarningsYet,
                style: GoogleFonts.roboto(
                    fontSize: 16, color: Colors.grey)),
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Total earnings card
          Card(
            color: AppTheme.secondaryColor.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.monetization_on,
                      size: 48, color: AppTheme.secondaryColor),
                  const SizedBox(height: 12),
                  Text(StringConstants.frTotalEarningsLabel,
                      style: GoogleFonts.roboto(
                          fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('${fmt.format(totalEarnings.toInt())} XAF',
                      style: GoogleFonts.roboto(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Period earnings
          Row(
            children: [
              Expanded(
                child: _periodCard(
                  'Aujourd\'hui',
                  '${fmt.format(todayEarnings.toInt())} XAF',
                  '$todayDeliveries livr.',
                  Icons.today,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _periodCard(
                  StringConstants.frThisWeekEarnings,
                  '${fmt.format(weekEarnings.toInt())} XAF',
                  '$weekDeliveries livr.',
                  Icons.date_range,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _periodCard(
                  StringConstants.frThisMonthEarnings,
                  '${fmt.format((totalEarnings).toInt())} XAF',
                  '$completedOrders livr.',
                  Icons.calendar_month,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Statistiques',
                      style: GoogleFonts.roboto(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statItem(Icons.local_shipping,
                          '$totalDeliveries', StringConstants.frDeliveriesCount),
                      _divider(),
                      _statItem(Icons.check_circle,
                          '$completedOrders', StringConstants.frCompletedOrders),
                      _divider(),
                      _statItem(Icons.star,
                          avgRating.toStringAsFixed(1), StringConstants.frAverageRating),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.percent,
                          size: 20, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text('${StringConstants.frCommissionRate}: $commissionRate%',
                          style: GoogleFonts.roboto(fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _periodCard(
      String label, String amount, String subtitle, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryColor),
            const SizedBox(height: 8),
            Text(amount,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor)),
            const SizedBox(height: 4),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                    fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                    fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppTheme.primaryColor),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.roboto(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label,
              style: GoogleFonts.roboto(
                  fontSize: 11, color: Colors.grey[600]),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: Colors.grey[300]);
  }
}
