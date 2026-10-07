import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/driver_model.dart';
import '../../../providers/driver_provider.dart';
import 'driver_form_screen.dart';

class DriverDetailScreen extends ConsumerWidget {
  final DriverModel driver;

  const DriverDetailScreen({super.key, required this.driver});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverProvider);
    final current = state.drivers.firstWhere(
      (d) => d.id == driver.id,
      orElse: () => driver,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DriverFormScreen(existingDriver: current),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(current),
          const SizedBox(height: 20),
          _buildAvailabilityCard(current, ref),
          const SizedBox(height: 20),
          _buildVehicleCard(current),
          const SizedBox(height: 20),
          _buildPerformanceCard(current),
          const SizedBox(height: 20),
          _buildInfoCard(current),
          const SizedBox(height: 24),
          _buildDeleteButton(current, ref, context),
        ],
      ),
    );
  }

  Widget _buildHeader(DriverModel driver) {
    return Row(
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, size: 40, color: AppTheme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(driver.name,
                  style: GoogleFonts.roboto(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(driver.email,
                  style: GoogleFonts.roboto(
                      fontSize: 14, color: Colors.grey[600])),
              if (driver.phone.isNotEmpty)
                Text(driver.phone,
                    style: GoogleFonts.roboto(
                        fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityCard(DriverModel driver, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(StringConstants.frAvailability,
                    style: GoogleFonts.roboto(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      driver.availability.isAvailable
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 18,
                      color: driver.availability.isAvailable
                          ? Colors.green
                          : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      driver.availability.isAvailable
                          ? StringConstants.frAvailable
                          : StringConstants.frNotAvailable,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: driver.availability.isAvailable
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Switch(
              value: driver.availability.isAvailable,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (v) {
                ref
                    .read(driverProvider.notifier)
                    .toggleAvailability(driver.id, v);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard(DriverModel driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(StringConstants.frVehicle,
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (driver.vehicle.type.isEmpty)
              Text('Aucun véhicule assigné',
                  style: GoogleFonts.roboto(color: Colors.grey))
            else ...[
              _infoRow(Icons.directions_car, 'Type', driver.vehicle.type),
              _infoRow(Icons.confirmation_number,
                  StringConstants.frPlateNumber, driver.vehicle.plateNumber),
              _infoRow(Icons.palette, StringConstants.frVehicleColor,
                  driver.vehicle.color),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard(DriverModel driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance',
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _statItem(
                    Icons.local_shipping,
                    '${driver.performance.totalDeliveries}',
                    StringConstants.frTotalDeliveries),
                _divider(),
                _statItem(
                    Icons.check_circle,
                    '${driver.performance.completedOrders}',
                    StringConstants.frCompletedOrders),
                _divider(),
                _statItem(
                    Icons.star,
                    driver.performance.averageRating.toStringAsFixed(1),
                    StringConstants.frAverageRating),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on,
                    size: 20, color: AppTheme.secondaryColor),
                const SizedBox(width: 8),
                Text(
                  '${StringConstants.frTotalEarnings}: ${driver.performance.totalEarnings.toStringAsFixed(0)} XAF',
                  style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(DriverModel driver) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informations',
                style: GoogleFonts.roboto(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _infoRow(Icons.pin, StringConstants.frDriverPin, '••••'),
            _infoRow(Icons.percent, StringConstants.frCommissionRate,
                '${driver.commissionRate}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(
      DriverModel driver, WidgetRef ref, BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.delete_outline),
      label: Text(StringConstants.frDelete),
      onPressed: () => _confirmDelete(context, ref, driver),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.errorColor,
        side: const BorderSide(color: AppTheme.errorColor),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, DriverModel driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringConstants.frDeleteConfirm),
        content: const Text('Voulez-vous vraiment supprimer ce conducteur ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringConstants.frCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(driverProvider.notifier).deleteDriver(driver.id);
              Navigator.of(context).pop();
            },
            child: Text(StringConstants.frDelete,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.roboto(color: Colors.grey[600])),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                style: GoogleFonts.roboto(fontWeight: FontWeight.w500)),
          ),
        ],
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
