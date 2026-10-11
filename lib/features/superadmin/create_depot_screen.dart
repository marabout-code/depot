import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/loading_button.dart';
import '../../providers/depot_provider.dart';
import '../auth/pin_entry_field.dart';

/// Creates a depot and, optionally, its first administrator in one flow. Both
/// writes run online (`depot_create` + `admin_create_user`).
class CreateDepotScreen extends ConsumerStatefulWidget {
  const CreateDepotScreen({super.key});

  @override
  ConsumerState<CreateDepotScreen> createState() => _CreateDepotScreenState();
}

class _CreateDepotScreenState extends ConsumerState<CreateDepotScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _adminNameController = TextEditingController();
  String _adminPin = '';
  String _adminPinConfirm = '';
  bool _withAdmin = false;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _adminNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_withAdmin && _adminPin != _adminPinConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les codes PIN ne correspondent pas'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final result = await ref.read(depotProvider.notifier).createDepot(
          name: _nameController.text,
          city: _cityController.text,
          address: _addressController.text,
          adminName: _withAdmin ? _adminNameController.text : null,
          adminPin: _withAdmin ? _adminPin : null,
        );

    if (!mounted) return;
    if (result == null) {
      final error = ref.read(depotProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Échec de la création du dépôt.'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.warning ?? 'Dépôt créé.',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor:
            result.warning != null ? Colors.orange.shade800 : Colors.green.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = ref.watch(depotProvider).isCreating;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer un dépôt'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Informations du dépôt',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nom du dépôt *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Le nom du dépôt est requis.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cityController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ville',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  value: _withAdmin,
                  onChanged: (value) => setState(() => _withAdmin = value),
                  title: const Text("Créer l'administrateur du dépôt"),
                  subtitle: const Text(
                    "Recommandé : le premier administrateur local du dépôt.",
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_withAdmin) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: "Nom de l'administrateur *",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    validator: (value) => _withAdmin &&
                            (value == null || value.trim().isEmpty)
                        ? "Le nom de l'administrateur est requis."
                        : null,
                  ),
                  const SizedBox(height: 16),
                  PinEntryField(
                    label:
                        'Code PIN (${LocalFirstAuthService.pinLength} chiffres)',
                    length: LocalFirstAuthService.pinLength,
                    onChanged: (value) => setState(() => _adminPin = value),
                  ),
                  const SizedBox(height: 16),
                  PinEntryField(
                    label: 'Confirmer le code PIN',
                    length: LocalFirstAuthService.pinLength,
                    onChanged: (value) =>
                        setState(() => _adminPinConfirm = value),
                  ),
                ],
                const SizedBox(height: 32),
                LoadingButton(
                  label: 'Créer le dépôt',
                  isLoading: isCreating,
                  onPressed: _submit,
                  backgroundColor: AppTheme.primaryColor,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette création nécessite une connexion.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}