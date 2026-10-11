import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../../../providers/driver_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../providers/route_provider.dart';

class RouteFormScreen extends ConsumerStatefulWidget {
  const RouteFormScreen({super.key});

  @override
  ConsumerState<RouteFormScreen> createState() => _RouteFormScreenState();
}

class _RouteFormScreenState extends ConsumerState<RouteFormScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _selectedOrderIds = <String>{};

  DateTime _date = DateTime.now();
  String? _driverId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Tournée ${_formatDate(_date)}';
    Future.microtask(() {
      ref.read(driverProvider.notifier).loadDrivers();
      ref.read(orderProvider.notifier).loadOrders();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final driverState = ref.watch(driverProvider);
    final orderState = ref.watch(orderProvider);

    // Only orders that still need a run: not delivered, not cancelled.
    final assignable = orderState.orders
        .where((o) =>
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(StringConstants.frCreateRoute)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: StringConstants.frRouteName,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _buildDateField(),
          const SizedBox(height: 16),
          _buildDriverField(driverState),
          const SizedBox(height: 24),
          Text('${StringConstants.frRouteOrders} (${assignable.length})',
              style: GoogleFonts.roboto(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (assignable.isEmpty)
            Text(StringConstants.frNoOrders,
                style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey))
          else
            ...assignable.map(_buildOrderTile),
          const SizedBox(height: 24),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: StringConstants.frNotes,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check),
              label: Text(StringConstants.frSave),
              onPressed: _saving ? null : () => _save(assignable),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _date,
          firstDate: DateTime.now().subtract(const Duration(days: 30)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          setState(() {
            _date = picked;
            if (_nameController.text.startsWith('Tournée ')) {
              _nameController.text = 'Tournée ${_formatDate(picked)}';
            }
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: StringConstants.frRouteDate,
          border: OutlineInputBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDate(_date), style: GoogleFonts.roboto(fontSize: 15)),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverField(DriversState driverState) {
    final drivers = driverState.drivers;
    return DropdownButtonFormField<String>(
      key: ValueKey(_driverId),
      initialValue: _driverId,
      decoration: const InputDecoration(
        labelText: StringConstants.frAddDriver,
        border: OutlineInputBorder(),
      ),
      items: drivers
          .map((d) => DropdownMenuItem(
                value: d.id,
                child: Text(d.name, style: GoogleFonts.roboto(fontSize: 14)),
              ))
          .toList(),
      onChanged: (val) => setState(() => _driverId = val),
    );
  }

  Widget _buildOrderTile(OrderModel order) {
    final selected = _selectedOrderIds.contains(order.id);
    return CheckboxListTile(
      value: selected,
      dense: true,
      onChanged: (val) => setState(() {
        if (val == true) {
          _selectedOrderIds.add(order.id);
        } else {
          _selectedOrderIds.remove(order.id);
        }
      }),
      title: Text(order.orderNumber,
          style: GoogleFonts.roboto(
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${order.customerName} • ${_totalOf(order).toStringAsFixed(0)} XAF',
        style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[600]),
      ),
    );
  }

  static double _totalOf(OrderModel order) =>
      order.totalAmount > 0 ? order.totalAmount : order.calculatedTotal;

  Future<void> _save(List<OrderModel> assignable) async {
    final driverState = ref.read(driverProvider);
    final driver = driverState.drivers
        .where((d) => d.id == _driverId)
        .firstOrNull;

    if (_nameController.text.trim().isEmpty ||
        _selectedOrderIds.isEmpty ||
        driver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Renseignez un nom, un conducteur et au moins une commande.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final route = await ref.read(routeProvider.notifier).createRoute(
          name: _nameController.text.trim(),
          date: _date,
          driverId: driver.id,
          driverName: driver.name,
          orderIds: _selectedOrderIds.toList(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (route != null) {
      // Keep the order list fresh: their driverId changed.
      await ref.read(orderProvider.notifier).loadOrders();
      messenger.showSnackBar(
        const SnackBar(content: Text(StringConstants.frRouteSaved)),
      );
      navigator.pop();
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
