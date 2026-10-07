import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/driver_model.dart';
import '../../../providers/driver_provider.dart';
import 'driver_form_screen.dart';
import 'driver_detail_screen.dart';

class DriverListScreen extends ConsumerStatefulWidget {
  const DriverListScreen({super.key});

  @override
  ConsumerState<DriverListScreen> createState() => _DriverListScreenState();
}

class _DriverListScreenState extends ConsumerState<DriverListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(driverProvider.notifier).loadDrivers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverProvider);
    final notifier = ref.read(driverProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frDrivers),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher un conducteur...',
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

  Widget _buildBody(DriversState state, DriverNotifier notifier) {
    switch (state.status) {
      case DriversStatus.initial:
      case DriversStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case DriversStatus.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text(state.error ?? StringConstants.frErrorGeneral),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => notifier.loadDrivers(),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        );
      case DriversStatus.loaded:
        var drivers = state.drivers;
        if (_searchQuery.isNotEmpty) {
          drivers = notifier.search(_searchQuery);
        }
        if (drivers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(StringConstants.frNoDrivers,
                    style: GoogleFonts.roboto(
                        fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => notifier.loadDrivers(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: drivers.length,
            itemBuilder: (_, i) => _buildDriverCard(drivers[i], context),
          ),
        );
    }
  }

  Widget _buildDriverCard(DriverModel driver, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _navigateToDetail(context, driver),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Icon(Icons.person, color: AppTheme.primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name,
                        style: GoogleFonts.roboto(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(driver.phone.isEmpty ? 'N/A' : driver.phone,
                            style: GoogleFonts.roboto(
                                fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                    if (driver.vehicle.type.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.directions_car,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                              '${driver.vehicle.type} • ${driver.vehicle.plateNumber}',
                              style: GoogleFonts.roboto(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: driver.availability.isAvailable
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      driver.availability.isAvailable
                          ? StringConstants.frAvailable
                          : StringConstants.frNotAvailable,
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: driver.availability.isAvailable
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${driver.performance.totalDeliveries} livr.',
                    style: GoogleFonts.roboto(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToForm(BuildContext context, [DriverModel? driver]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverFormScreen(existingDriver: driver),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, DriverModel driver) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DriverDetailScreen(driver: driver),
      ),
    );
  }
}
