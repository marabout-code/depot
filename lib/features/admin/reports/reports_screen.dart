import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/report_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() {
      ref.read(reportProvider.notifier).loadReports();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frReports),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Vue'),
            Tab(icon: Icon(Icons.trending_up), text: 'Ventes'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Stock'),
            Tab(icon: Icon(Icons.people), text: 'Chauffeurs'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(reportProvider.notifier).loadReports(),
          ),
        ],
      ),
      body: state.status == ReportsStatus.loading
          ? const Center(child: CircularProgressIndicator())
          : state.status == ReportsStatus.error
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 12),
                      Text(state.error ?? StringConstants.frErrorGeneral),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref
                            .read(reportProvider.notifier)
                            .loadReports(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(data: state.data),
                    _SalesTab(data: state.data),
                    _InventoryTab(data: state.data),
                    _DriversTab(data: state.data),
                  ],
                ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Text(label,
                    style: GoogleFonts.roboto(
                        fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: GoogleFonts.roboto(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: GoogleFonts.roboto(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.roboto(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final ReportData data;

  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final curFmt = NumberFormat('#,###', 'fr_FR');

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _KpiCard(
                label: StringConstants.frTotalOrders,
                value: '${data.totalOrders}',
                icon: Icons.shopping_cart,
                color: AppTheme.primaryColor,
              ),
              _KpiCard(
                label: StringConstants.frRevenue,
                value: '${curFmt.format(data.totalRevenue.toInt())} XAF',
                icon: Icons.monetization_on,
                color: AppTheme.secondaryColor,
              ),
              _KpiCard(
                label: StringConstants.frActiveDrivers,
                value: '${data.availableDrivers}/${data.totalDrivers}',
                icon: Icons.local_shipping,
                color: Colors.blue,
                subtitle: data.totalDrivers > 0
                    ? '${(data.availableDrivers / data.totalDrivers * 100).toInt()}%'
                    : null,
              ),
              _KpiCard(
                label: 'Stock faible',
                value: '${data.lowStockItems}',
                icon: Icons.warning_amber,
                color: data.lowStockItems > 0
                    ? AppTheme.secondaryColor
                    : Colors.green,
                subtitle: '${data.outOfStockItems} en rupture',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SectionHeader(
              title: StringConstants.frRevenue,
              icon: Icons.trending_up),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'Aujourd\'hui',
                  value: '${curFmt.format(data.todayRevenue.toInt())} XAF',
                  icon: Icons.today,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: 'Cette semaine',
                  value: '${curFmt.format(data.weekRevenue.toInt())} XAF',
                  icon: Icons.date_range,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KpiCard(
            label: 'Ce mois',
            value: '${curFmt.format(data.monthRevenue.toInt())} XAF',
            icon: Icons.calendar_month,
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          _SectionHeader(
              title: StringConstants.frOrderStats,
              icon: Icons.pie_chart),
          _buildStatusBar(),
          const SizedBox(height: 8),
          _buildStatusRow('En attente', data.pendingOrders, data.totalOrders,
              AppTheme.secondaryColor),
          _buildStatusRow('Confirmée', data.confirmedOrders, data.totalOrders,
              Colors.blue),
          _buildStatusRow('En livraison', data.outForDeliveryOrders,
              data.totalOrders, Colors.purple),
          _buildStatusRow(
              'Livrée', data.deliveredOrders, data.totalOrders, Colors.green),
          _buildStatusRow('Annulée', data.cancelledOrders, data.totalOrders,
              AppTheme.errorColor),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    if (data.totalOrders == 0) return const SizedBox();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            _barSegment(data.pendingOrders, AppTheme.secondaryColor),
            _barSegment(data.confirmedOrders, Colors.blue),
            _barSegment(data.outForDeliveryOrders, Colors.purple),
            _barSegment(data.deliveredOrders, Colors.green),
            _barSegment(data.cancelledOrders, AppTheme.errorColor),
          ],
        ),
      ),
    );
  }

  Widget _barSegment(int count, Color color) {
    if (data.totalOrders == 0 || count == 0) return const SizedBox();
    return Expanded(
      flex: count,
      child: Container(color: color),
    );
  }

  Widget _buildStatusRow(
      String label, int count, int total, Color color) {
    final pct = total > 0 ? (count / total * 100).toInt() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: GoogleFonts.roboto(fontSize: 13)),
          ),
          Text('$count',
              style: GoogleFonts.roboto(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text('$pct%',
                style: GoogleFonts.roboto(
                    fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _SalesTab extends StatelessWidget {
  final ReportData data;

  const _SalesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final curFmt = NumberFormat('#,###', 'fr_FR');

    if (data.totalOrders == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(StringConstants.frNoOrdersYet,
                style: GoogleFonts.roboto(
                    fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
              onPressed: () {},
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(
              title: StringConstants.frRevenue,
              icon: Icons.monetization_on),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frRevenueToday,
                  value: '${curFmt.format(data.todayRevenue.toInt())} XAF',
                  icon: Icons.today,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frRevenueThisWeek,
                  value: '${curFmt.format(data.weekRevenue.toInt())} XAF',
                  icon: Icons.date_range,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KpiCard(
            label: StringConstants.frRevenueThisMonth,
            value: '${curFmt.format(data.monthRevenue.toInt())} XAF',
            icon: Icons.calendar_month,
            color: Colors.teal,
          ),
          const SizedBox(height: 24),
          _SectionHeader(
              title: StringConstants.frOrderStats,
              icon: Icons.pie_chart),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _statusRow(Icons.hourglass_empty, 'En attente',
                      '${data.pendingOrders}', AppTheme.secondaryColor),
                  const Divider(),
                  _statusRow(Icons.check_circle_outline, 'Confirmée',
                      '${data.confirmedOrders}', Colors.blue),
                  const Divider(),
                  _statusRow(Icons.local_shipping, 'En livraison',
                      '${data.outForDeliveryOrders}', Colors.purple),
                  const Divider(),
                  _statusRow(Icons.thumb_up, 'Livrée',
                      '${data.deliveredOrders}', Colors.green),
                  const Divider(),
                  _statusRow(Icons.cancel, 'Annulée',
                      '${data.cancelledOrders}', AppTheme.errorColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (data.topProducts.isNotEmpty) ...[
            _SectionHeader(
                title: StringConstants.frTopProducts,
                icon: Icons.star),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: data.topProducts.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final p = e.value;
                    final rev = p.totalRevenue;
                    double pct = 0;
                    if (data.topProducts.isNotEmpty) {
                      pct = p.totalQuantity /
                          data.topProducts
                                  .fold<int>(
                                      0, (s, tp) => s + tp.totalQuantity)
                                  .toDouble() *
                          100;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('$rank',
                                style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500])),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.productName,
                                    style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text(
                                    '${p.totalQuantity} unités • ${curFmt.format(rev.toInt())} XAF',
                                    style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          Text('${pct.toInt()}%',
                              style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.roboto(fontSize: 14))),
          Text(value,
              style: GoogleFonts.roboto(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  final ReportData data;

  const _InventoryTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final curFmt = NumberFormat('#,###', 'fr_FR');

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(
              title: StringConstants.frStockOverview,
              icon: Icons.warehouse),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frStockValue,
                  value: '${curFmt.format(data.totalStockValue.toInt())} XAF',
                  icon: Icons.monetization_on,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: 'Articles',
                  value: '${data.totalInventoryItems}',
                  icon: Icons.inventory_2,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frItemsLowStock,
                  value: '${data.lowStockItems}',
                  icon: Icons.warning_amber,
                  color: data.lowStockItems > 0
                      ? AppTheme.secondaryColor
                      : Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frItemsOutOfStock,
                  value: '${data.outOfStockItems}',
                  icon: Icons.highlight_off,
                  color: data.outOfStockItems > 0
                      ? AppTheme.errorColor
                      : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(
              title: StringConstants.frMovementSummary,
              icon: Icons.swap_horiz),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _movementRow(Icons.add_circle_outline,
                      StringConstants.frStockIn, '${data.stockInTotal}',
                      Colors.green),
                  const Divider(),
                  _movementRow(Icons.remove_circle_outline,
                      StringConstants.frStockOut, '${data.stockOutTotal}',
                      AppTheme.errorColor),
                  const Divider(),
                  _movementRow(Icons.warning_amber,
                      StringConstants.frDamage, '${data.damageTotal}',
                      AppTheme.secondaryColor),
                ],
              ),
            ),
          ),
          if (data.totalInventoryItems > 0) ...[
            const SizedBox(height: 24),
            _SectionHeader(
                title: 'Santé du stock', icon: Icons.health_and_safety),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _healthRow(
                        'En stock',
                        data.totalInventoryItems -
                            data.lowStockItems -
                            data.outOfStockItems,
                        data.totalInventoryItems,
                        Colors.green),
                    const SizedBox(height: 8),
                    _healthRow(
                        'Stock faible',
                        data.lowStockItems,
                        data.totalInventoryItems,
                        AppTheme.secondaryColor),
                    const SizedBox(height: 8),
                    _healthRow('Rupture', data.outOfStockItems,
                        data.totalInventoryItems, AppTheme.errorColor),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _movementRow(
      IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: GoogleFonts.roboto(fontSize: 14))),
          Text(value,
              style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _healthRow(String label, int count, int total, Color color) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(label,
                    style: GoogleFonts.roboto(fontSize: 13))),
            Text('$count',
                style: GoogleFonts.roboto(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            SizedBox(
              width: 40,
              child: Text('${(pct * 100).toInt()}%',
                  style: GoogleFonts.roboto(
                      fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

class _DriversTab extends StatelessWidget {
  final ReportData data;

  const _DriversTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final curFmt = NumberFormat('#,###', 'fr_FR');

    if (data.totalDrivers == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(StringConstants.frNoDriversYet,
                style: GoogleFonts.roboto(
                    fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Actualiser'),
              onPressed: () {},
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(
              title: StringConstants.frDriverStats,
              icon: Icons.people),
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frActiveDrivers,
                  value:
                      '${data.availableDrivers}/${data.totalDrivers}',
                  icon: Icons.local_shipping,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: StringConstants.frAverageRating,
                  value: data.averageDriverRating.toStringAsFixed(1),
                  icon: Icons.star,
                  color: AppTheme.secondaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _KpiCard(
            label: StringConstants.frTotalEarnings,
            value: '${curFmt.format(data.totalDriverEarnings.toInt())} XAF',
            icon: Icons.monetization_on,
            color: Colors.teal,
          ),
          if (data.topDrivers.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
                title: StringConstants.frTopDrivers,
                icon: Icons.leaderboard),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: data.topDrivers.asMap().entries.map((e) {
                    final rank = e.key + 1;
                    final d = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text('$rank',
                                style: GoogleFonts.roboto(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500])),
                          ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryColor
                                .withValues(alpha: 0.1),
                            child: Icon(Icons.person,
                                size: 18,
                                color: AppTheme.primaryColor),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(d.driverName,
                                    style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                    '${d.deliveries} livr. • ${d.rating.toStringAsFixed(1)} ★',
                                    style: GoogleFonts.roboto(
                                        fontSize: 12,
                                        color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          Text(
                              '${curFmt.format(d.earnings.toInt())} XAF',
                              style: GoogleFonts.roboto(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.secondaryColor)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
