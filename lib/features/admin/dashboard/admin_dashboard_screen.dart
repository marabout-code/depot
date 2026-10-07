import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/services/license_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../products/product_list_screen.dart';
import '../orders/order_list_screen.dart';
import '../drivers/driver_list_screen.dart';
import '../inventory/inventory_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/license_dialog.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final license = ref.watch(licenseServiceProvider);
    final userName = authState.user?.name ?? 'Admin';
    final locked = !license.isActivated &&
        license.status == LicenseStatus.trialExpired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépôt Distribution'),
        automaticallyImplyLeading: false,
        actions: [
          if (!license.isActivated)
            IconButton(
              icon: const Icon(Icons.verified_outlined),
              tooltip: license.status == LicenseStatus.trialExpired
                  ? 'Activer la licence'
                  : '${license.remainingDays} jours restants',
              onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => LicenseDialog(
                  trialExpired:
                      license.status == LicenseStatus.trialExpired,
                ),
              );
              },
            ),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Bonjour, $userName',
                    style: GoogleFonts.roboto(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!license.isActivated)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: license.status == LicenseStatus.trialExpired
                          ? AppTheme.errorColor
                          : AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      license.status == LicenseStatus.trialExpired
                          ? 'Expiré'
                          : '${license.remainingDays}j',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              StringConstants.enAdminDashboard,
              style: GoogleFonts.roboto(
                fontSize: 16,
                color: Colors.grey,
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
                    icon: Icons.inventory_2,
                    label: 'Produits',
                    color: AppTheme.primaryColor,
                    locked: locked,
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
                    locked: locked,
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
                    locked: locked,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DriverListScreen(),
                        ),
                      );
                    },
                  ),
                  _DashboardCard(
                    icon: Icons.warehouse,
                    label: 'Inventaire',
                    color: Colors.purple,
                    locked: locked,
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
                    locked: locked,
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
                    locked: false,
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
  final bool locked;

  const _DashboardCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Stack(
        children: [
          InkWell(
            onTap: locked ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Opacity(
              opacity: locked ? 0.5 : 1.0,
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
          ),
          if (locked)
            Positioned.fill(
              child: Center(
                child: Icon(
                  Icons.lock,
                  size: 32,
                  color: Colors.grey[600],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
