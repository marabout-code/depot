import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/services/local_first_auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/driver_model.dart';
import '../../../providers/driver_provider.dart';

/// Kept in one place so the admin form and the login keypad cannot disagree.
const int pinLength = LocalFirstAuthService.pinLength;

class DriverFormScreen extends ConsumerStatefulWidget {
  final DriverModel? existingDriver;

  const DriverFormScreen({super.key, this.existingDriver});

  @override
  ConsumerState<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends ConsumerState<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  final _commissionController = TextEditingController();

  String _vehicleType = 'Motorcycle';
  bool _isEditing = false;

  static const _vehicleTypes = ['Car', 'Motorcycle', 'Truck'];

  @override
  void initState() {
    super.initState();
    if (widget.existingDriver != null) {
      _isEditing = true;
      final d = widget.existingDriver!;
      _nameController.text = d.name;
      _emailController.text = d.email;
      _phoneController.text = d.phone;
      // The plaintext PIN is never persisted or synced, so it cannot be shown
      // back to the form. An empty field means "keep the current PIN".
      _vehicleType = d.vehicle.type.isNotEmpty
          ? d.vehicle.type
          : 'Motorcycle';
      _plateController.text = d.vehicle.plateNumber;
      _colorController.text = d.vehicle.color;
      _commissionController.text = d.commissionRate.toStringAsFixed(1);
    } else {
      _commissionController.text = '10.0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vehicle = Vehicle(
      type: _vehicleType,
      plateNumber: _plateController.text.trim(),
      color: _colorController.text.trim(),
    );

    final driver = DriverModel(
      id: _isEditing
          ? widget.existingDriver!.id
          : const Uuid().v4(),
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      pinCode: _pinController.text.trim(),
      vehicle: vehicle,
      commissionRate: double.tryParse(_commissionController.text) ?? 10.0,
      createdAt: _isEditing ? widget.existingDriver!.createdAt : null,
    );

    if (_isEditing) {
      await ref.read(driverProvider.notifier).updateDriver(
            driver.id,
            driver.toMap(),
          );
    } else {
      await ref.read(driverProvider.notifier).saveDriver(driver);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.frDriverSaved),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(driverProvider);
    final isLoading = state.status == DriversStatus.loading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? StringConstants.frEditDriver
            : StringConstants.frAddDriver),
        actions: [
          TextButton(
            onPressed: isLoading ? null : _save,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(StringConstants.frSave,
                    style: GoogleFonts.roboto(
                        color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Informations personnelles'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: StringConstants.frDriverName,
                prefixIcon: const Icon(Icons.person),
              ),
              validator: (v) => v?.isEmpty == true ? 'Nom requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: StringConstants.frDriverEmail,
                prefixIcon: const Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v?.isEmpty == true) return 'Email requis';
                if (!v!.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: StringConstants.frDriverPhone,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pinController,
              decoration: InputDecoration(
                labelText: _isEditing
                    ? 'Nouveau PIN (vide = inchangé)'
                    : StringConstants.frDriverPin,
                prefixIcon: const Icon(Icons.pin),
                hintText: '$pinLength chiffres',
              ),
              keyboardType: TextInputType.number,
              maxLength: pinLength,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (_isEditing && (v?.isEmpty ?? true)) return null;
                if (v?.isEmpty == true) return 'PIN requis';
                if (!LocalFirstAuthService.isValidPin(v!)) {
                  return '$pinLength chiffres requis';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle(StringConstants.frVehicle),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _vehicleType,
              decoration: InputDecoration(
                labelText: StringConstants.frVehicleType,
                prefixIcon: const Icon(Icons.directions_car),
              ),
              items: _vehicleTypes.map((t) {
                final label = t == 'Car'
                    ? StringConstants.frCar
                    : t == 'Motorcycle'
                        ? StringConstants.frMotorcycle
                        : StringConstants.frTruck;
                return DropdownMenuItem(value: t, child: Text(label));
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _vehicleType = v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateController,
              decoration: InputDecoration(
                labelText: StringConstants.frPlateNumber,
                prefixIcon: const Icon(Icons.confirmation_number),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _colorController,
              decoration: InputDecoration(
                labelText: StringConstants.frVehicleColor,
                prefixIcon: const Icon(Icons.palette),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Commission'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _commissionController,
              decoration: InputDecoration(
                labelText: StringConstants.frCommissionRate,
                prefixIcon: const Icon(Icons.percent),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.roboto(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor));
  }
}
