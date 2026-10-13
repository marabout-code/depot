import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/depot_model.dart';
import '../../providers/depot_provider.dart';
import '../auth/pin_entry_field.dart';

/// Creates a depot (optionally with its first administrator) or edits an
/// existing one. Creation runs online (`depot_create` + `admin_create_user`);
/// editing runs online too, because the authoritative `depots` table must change
/// alongside the synced row.
class DepotFormScreen extends ConsumerStatefulWidget {
  /// When non-null the screen edits this depot; otherwise it creates a new one.
  final DepotModel? existing;

  const DepotFormScreen({super.key, this.existing});

  @override
  ConsumerState<DepotFormScreen> createState() => _DepotFormScreenState();
}

class _DepotFormScreenState extends ConsumerState<DepotFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _adminNameController = TextEditingController();
  String _adminPin = '';
  String _adminPinConfirm = '';
  bool _withAdmin = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final depot = widget.existing;
    if (depot != null) {
      _nameController.text = depot.name;
      _cityController.text = depot.city;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _adminNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEditing && _withAdmin && _adminPin != _adminPinConfirm) {
      _showError('Les codes PIN ne correspondent pas');
      return;
    }

    final notifier = ref.read(depotProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isEditing) {
      final error = await notifier.updateDepot(
        id: widget.existing!.id,
        name: _nameController.text,
        city: _cityController.text,
      );
      if (!mounted) return;
      if (error != null) {
        _showError(error);
        return;
      }
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Dépôt modifié.'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
      return;
    }

    final result = await notifier.createDepot(
      name: _nameController.text,
      city: _cityController.text,
      adminName: _withAdmin ? _adminNameController.text : null,
      adminPin: _withAdmin ? _adminPin : null,
    );

    if (!mounted) return;
    if (result == null) {
      _showError(ref.read(depotProvider).error ?? 'Échec de la création.');
      return;
    }

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(result.warning ?? 'Dépôt créé.'),
        backgroundColor:
            result.warning != null ? Colors.orange.shade800 : AppTheme.primaryColor,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(depotProvider).isBusy;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le dépôt' : 'Créer un dépôt'),
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
                    labelText: 'Quartier',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                if (!_isEditing) ...[
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
                ],
                const SizedBox(height: 32),
                LoadingButton(
                  label: _isEditing ? 'Enregistrer' : 'Créer le dépôt',
                  isLoading: isBusy,
                  onPressed: _submit,
                  backgroundColor: AppTheme.primaryColor,
                  textColor: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cette opération nécessite une connexion.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
