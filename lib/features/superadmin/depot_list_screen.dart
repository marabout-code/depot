import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/depot_model.dart';
import '../../providers/depot_provider.dart';
import '../auth/pin_entry_field.dart';
import 'create_depot_screen.dart';

class DepotListScreen extends ConsumerStatefulWidget {
  const DepotListScreen({super.key});

  @override
  ConsumerState<DepotListScreen> createState() => _DepotListScreenState();
}

class _DepotListScreenState extends ConsumerState<DepotListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(depotProvider.notifier).loadDepots();
    });
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateDepotScreen()),
    );
    ref.read(depotProvider.notifier).loadDepots();
  }

  void _showDetails(DepotModel depot) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(depot.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (depot.city.isNotEmpty)
              Text('Ville : ${depot.city}'),
            if (depot.address.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Adresse : ${depot.address}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreateAdmin(DepotModel depot) async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateAdminDialog(depot: depot),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Administrateur créé pour ${depot.name}.",
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depotProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépôts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add),
        label: const Text('Créer un dépôt'),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(depotProvider.notifier).loadDepots(),
        child: state.depots.isEmpty
            ? _buildEmpty(context, state)
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: state.depots.length,
                itemBuilder: (context, index) {
                  final depot = state.depots[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryColor.withValues(
                          alpha: 0.12,
                        ),
                        child: Icon(
                          Icons.warehouse,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        depot.name,
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        [
                          if (depot.city.isNotEmpty) depot.city,
                          if (depot.address.isNotEmpty) depot.address,
                        ].join(' · '),
                      ),
                      trailing: IconButton(
                        tooltip: "Créer l'administrateur du dépôt",
                        icon: const Icon(Icons.person_add_alt),
                        onPressed: () => _showCreateAdmin(depot),
                      ),
                      onTap: () => _showDetails(depot),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, DepotsState state) {
    if (state.status == DepotsStatus.error) {
      return Center(
        child: Text(
          'Impossible de charger les dépôts : ${state.error}',
          style: const TextStyle(color: AppTheme.errorColor),
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(
          Icons.warehouse_outlined,
          size: 64,
          color: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          'Aucun dépôt pour le moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
        SizedBox(height: 8),
        Text(
          'Créez un dépôt puis son administrateur local.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }
}

class _CreateAdminDialog extends ConsumerStatefulWidget {
  const _CreateAdminDialog({required this.depot});

  final DepotModel depot;

  @override
  ConsumerState<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends ConsumerState<_CreateAdminDialog> {
  final _nameController = TextEditingController();
  String _pin = '';

  bool get _valid =>
      _nameController.text.trim().isNotEmpty &&
      _pin.length == LocalFirstAuthService.pinLength;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(depotProvider.notifier);
    final error = await notifier.createDepotAdmin(
      depotId: widget.depot.id,
      name: _nameController.text,
      pin: _pin,
    );
    if (error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final creating = ref.watch(depotProvider).isCreating;

    return AlertDialog(
      title: Text("Créer l'administrateur"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Dépôt : ${widget.depot.name}",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: "Nom de l'administrateur",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          PinEntryField(
            label: 'Code PIN (${LocalFirstAuthService.pinLength} chiffres)',
            length: LocalFirstAuthService.pinLength,
            onChanged: (value) => setState(() => _pin = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: creating ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _valid && !creating ? _submit : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}