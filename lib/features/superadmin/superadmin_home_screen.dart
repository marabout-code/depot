import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/string_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/sync_status_icon.dart';
import '../../providers/auth_provider.dart';
import '../admin/products/product_list_screen.dart';
import '../admin/orders/order_list_screen.dart';
import '../admin/drivers/driver_list_screen.dart';
import '../admin/inventory/inventory_list_screen.dart';
import '../admin/reports/reports_screen.dart';
import '../admin/settings/settings_screen.dart';
import '../admin/routes/route_list_screen.dart';
import 'depot_list_screen.dart';

/// The superadmin's workspace: the full admin dashboard plus depot management.
/// There is no depot filter here by design — the superadmin is global and every
/// screen it opens spans all depots.
class SuperadminHomeScreen extends ConsumerWidget {
  const SuperadminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépôt Distribution'),
        automaticallyImplyLeading: false,
        actions: [
          const SyncStatusIcon(),
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
                        style:
                            const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Superadmin',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _DashboardCard(
                    icon: Icons.storefront,
                    label: 'Dépôts',
                    color: Colors.brown,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DepotListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.inventory_2,
                    label: 'Produits',
                    color: AppTheme.primaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.shopping_cart,
                    label: 'Commandes',
                    color: AppTheme.secondaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OrderListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.local_shipping,
                    label: 'Conducteurs',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DriverListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.route,
                    label: 'Tournées',
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RouteListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.warehouse,
                    label: 'Inventaire',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const InventoryListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.assessment,
                    label: 'Rapports',
                    color: Colors.teal,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReportsScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.settings,
                    label: 'Paramètres',
                    color: Colors.grey,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.color,
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
              Icon(icon, size: 48, color: color),
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
