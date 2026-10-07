import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/delivery_provider.dart';
import '../deliveries/delivery_list_screen.dart';
import '../earnings/driver_earnings_screen.dart';
import '../navigation/driver_navigation_screen.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
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
    final authState = ref.watch(authProvider);
    final deliveryState = ref.watch(driverDeliveriesProvider);
    final userName = authState.user?.name ?? 'Conducteur';
    final activeCount = deliveryState.activeOrders.length;
    final completedCount = deliveryState.completedOrders.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépôt Distribution'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(StringConstants.frLogout),
                  content: const Text(
                      'Voulez-vous vraiment vous déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authProvider.notifier).logout();
                      },
                      child: Text(
                        StringConstants.frLogout,
                        style: const TextStyle(
                            color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = ref.read(authProvider).user?.id;
          if (userId != null) {
            ref
                .read(driverDeliveriesProvider.notifier)
                .loadDriverData(userId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $userName',
                style: GoogleFonts.roboto(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Vos livraisons du jour',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const Spacer(),
                  if (activeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('$activeCount active(s)',
                          style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor)),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _DriverCard(
                      icon: Icons.route,
                      label: 'Mes livraisons',
                      color: AppTheme.primaryColor,
                      badge: activeCount > 0 ? '$activeCount' : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DeliveryListScreen(),
                          ),
                        );
                      },
                    ),
                    _DriverCard(
                      icon: Icons.navigation,
                      label: 'Navigation',
                      color: AppTheme.secondaryColor,
                      badge: null,
                      onTap: () {
                        final orders = deliveryState.activeOrders;
                        if (orders.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Aucune livraison active')),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DriverNavigationScreen(
                                order: orders.first),
                          ),
                        );
                      },
                    ),
                    _DriverCard(
                      icon: Icons.emoji_events,
                      label: 'Gains',
                      color: Colors.blue,
                      badge: null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DriverEarningsScreen(),
                          ),
                        );
                      },
                    ),
                    _DriverCard(
                      icon: Icons.person,
                      label: 'Mon profil',
                      color: Colors.purple,
                      badge: null,
                      onTap: () => _showProfile(context, authState),
                    ),
                  ],
                ),
              ),
              if (completedCount > 0) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text('$completedCount livraison(s) terminée(s)',
                      style: GoogleFonts.roboto(
                          fontSize: 13, color: Colors.grey[500])),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showProfile(BuildContext context, AuthState authState) {
    final user = authState.user;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final state = ref.read(driverDeliveriesProvider);
        final driver = state.driverProfile;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(Icons.person,
                        size: 40, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(user.name,
                      style: GoogleFonts.roboto(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                Center(
                  child: Text(user.email,
                      style: GoogleFonts.roboto(
                          fontSize: 14, color: Colors.grey[600])),
                ),
                const SizedBox(height: 24),
                Text(StringConstants.frPersonalInfo,
                    style: GoogleFonts.roboto(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (user.phone.isNotEmpty)
                  _profileRow(Icons.phone, user.phone),
                _profileRow(Icons.pin, 'PIN: ••••'),
                const SizedBox(height: 16),
                if (driver != null) ...[
                  Text(StringConstants.frMyVehicle,
                      style: GoogleFonts.roboto(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (driver.vehicle.type.isNotEmpty)
                    _profileRow(Icons.directions_car,
                        '${driver.vehicle.type} • ${driver.vehicle.plateNumber}'),
                  if (driver.vehicle.color.isNotEmpty)
                    _profileRow(
                        Icons.palette, driver.vehicle.color),
                  const SizedBox(height: 16),
                  Text(StringConstants.frMyPerformance,
                      style: GoogleFonts.roboto(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _profileRow(Icons.local_shipping,
                      '${driver.performance.totalDeliveries} livraisons'),
                  _profileRow(Icons.star,
                      '${driver.performance.averageRating.toStringAsFixed(1)} / 5'),
                  _profileRow(Icons.monetization_on,
                      '${driver.performance.totalEarnings.toStringAsFixed(0)} XAF'),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(text,
              style: GoogleFonts.roboto(fontSize: 14)),
        ],
      ),
    );
  }
}

class _DriverCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _DriverCard({
    required this.icon,
    required this.label,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Icon(icon, size: 48, color: color),
                  if (badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badge!,
                            style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
