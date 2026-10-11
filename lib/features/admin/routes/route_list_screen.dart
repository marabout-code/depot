import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/route_model.dart';
import '../../../models/route_status.dart';
import '../../../providers/route_provider.dart';
import 'route_detail_screen.dart';
import 'route_form_screen.dart';

class RouteListScreen extends ConsumerStatefulWidget {
  const RouteListScreen({super.key});

  @override
  ConsumerState<RouteListScreen> createState() => _RouteListScreenState();
}

class _RouteListScreenState extends ConsumerState<RouteListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(routeProvider.notifier).loadRoutes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(routeProvider);
    final notifier = ref.read(routeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(StringConstants.frRoutes)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'routes_fab',
        tooltip: StringConstants.frCreateRoute,
        onPressed: () => _navigateToCreate(context),
        child: const Icon(Icons.add),
      ),
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(RoutesState state, RouteNotifier notifier) {
    switch (state.status) {
      case RoutesStatus.initial:
      case RoutesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case RoutesStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? StringConstants.frErrorGeneral),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => notifier.loadRoutes(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case RoutesStatus.loaded:
        final routes = state.routes;
        if (routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.route_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(StringConstants.frNoRoutes,
                    style:
                        GoogleFonts.roboto(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => notifier.loadRoutes(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: routes.length,
            itemBuilder: (_, i) => _buildRouteCard(routes[i], context),
          ),
        );
    }
  }

  Widget _buildRouteCard(RouteModel route, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToDetail(context, route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(route.name,
                        style: GoogleFonts.roboto(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  _statusBadge(route.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.local_shipping, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(route.driverName.isEmpty ? '—' : route.driverName,
                      style: GoogleFonts.roboto(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(_formatDate(route.date),
                      style: GoogleFonts.roboto(
                          fontSize: 13, color: Colors.grey[600])),
                  const Spacer(),
                  Text(
                    '${route.orderCount} ${StringConstants.frRouteOrders}',
                    style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryColor),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(RouteStatus status) {
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

  static Color _statusColor(RouteStatus status) {
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

  static String _statusLabel(RouteStatus status) {
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

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  void _navigateToCreate(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const RouteFormScreen()));
  }

  void _navigateToDetail(BuildContext context, RouteModel route) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)),
    );
  }
}
