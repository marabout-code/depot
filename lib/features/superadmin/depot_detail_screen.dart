import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/depot_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../providers/depot_provider.dart';
import '../auth/pin_entry_field.dart';
import 'depot_form_screen.dart';

/// Everything the superadmin can see and do with one depot: its details,
/// headline counts, administrator accounts and assigned drivers.
class DepotDetailScreen extends ConsumerStatefulWidget {
  const DepotDetailScreen({super.key, required this.depot});

  final DepotModel depot;

  @override
  ConsumerState<DepotDetailScreen> createState() => _DepotDetailScreenState();
}

class _DepotDetailScreenState extends ConsumerState<DepotDetailScreen> {
  String get _depotId => widget.depot.id;

  Future<void> _openEdit(DepotModel depot) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DepotFormScreen(existing: depot)),
    );
  }

  Future<void> _toggleStatus(DepotModel depot) async {
    final next = depot.isActive
        ? DepotModel.statusInactive
        : DepotModel.statusActive;
    final error = await ref.read(depotProvider.notifier).setDepotStatus(
          depot.id,
          next,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ??
            (next == DepotModel.statusActive
                ? '${depot.name} activé.'
                : '${depot.name} désactivé.')),
        backgroundColor: error != null ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _confirmDelete(DepotModel depot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le dépôt'),
        content: Text(
          'Supprimer définitivement "${depot.name}" ?\n\n'
          'Un dépôt ne peut être supprimé que s\'il ne contient plus aucun '
          'compte ni donnée. Sinon, désactivez-le.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await ref.read(depotProvider.notifier).deleteDepot(depot.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${depot.name} supprimé.'),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  void _refresh() {
    ref.invalidate(depotUsersProvider(_depotId));
    ref.invalidate(depotStatsProvider(_depotId));
  }

  Future<void> _addAdmin() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateAdminDialog(depot: widget.depot),
    );
    if (created == true) _refresh();
  }

  Future<void> _resetPin(UserModel user) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ResetPinDialog(user: user),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depotProvider);
    DepotModel depot = widget.depot;
    for (final d in state.depots) {
      if (d.id == widget.depot.id) {
        depot = d;
        break;
      }
    }
    final busy = state.isBusy;

    return Scaffold(
      appBar: AppBar(
        title: Text(depot.name),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: busy ? null : () => _openEdit(depot),
          ),
          PopupMenuButton<String>(
            enabled: !busy,
            onSelected: (value) {
              if (value == 'toggle') _toggleStatus(depot);
              if (value == 'delete') _confirmDelete(depot);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    depot.isActive ? Icons.block : Icons.check_circle_outline,
                  ),
                  title: Text(depot.isActive ? 'Désactiver' : 'Activer'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.delete_outline, color: AppTheme.errorColor),
                  title: Text(
                    'Supprimer',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(depot: depot),
          const SizedBox(height: 16),
          _StatsCard(depotId: _depotId),
          const SizedBox(height: 16),
          _AccountsCard(
            depotId: _depotId,
            role: UserRole.admin,
            title: 'Administrateurs',
            emptyText: 'Aucun administrateur pour ce dépôt.',
            onAdd: _addAdmin,
            addLabel: 'Ajouter un administrateur',
            onResetPin: _resetPin,
          ),
          const SizedBox(height: 16),
          _AccountsCard(
            depotId: _depotId,
            role: UserRole.driver,
            title: 'Conducteurs',
            emptyText: 'Aucun conducteur affecté à ce dépôt.',
            onResetPin: _resetPin,
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.depot});

  final DepotModel depot;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Informations',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: (depot.isActive ? AppTheme.primaryColor : Colors.grey)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          depot.isActive ? 'Actif' : 'Inactif',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: depot.isActive ? AppTheme.primaryColor : Colors.grey,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            icon: Icons.place_outlined,
            label: 'Quartier',
            value: depot.city.isEmpty ? '—' : depot.city,
          ),
          _InfoRow(
            icon: Icons.event,
            label: 'Créé le',
            value: _formatDate(depot.createdAt),
          ),
        ],
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.depotId});

  final String depotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(depotStatsProvider(depotId));

    return _SectionCard(
      title: 'Aperçu',
      child: stats.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Statistiques indisponibles. Une connexion est nécessaire.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton.icon(
              onPressed: () => ref.invalidate(depotStatsProvider(depotId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
        data: (data) => GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            _StatTile(
              icon: Icons.admin_panel_settings,
              label: 'Admins',
              value: data.admins,
              color: AppTheme.primaryColor,
            ),
            _StatTile(
              icon: Icons.local_shipping,
              label: 'Conducteurs',
              value: data.drivers,
              color: Colors.blue,
            ),
            _StatTile(
              icon: Icons.inventory_2,
              label: 'Produits',
              value: data.products,
              color: AppTheme.secondaryColor,
            ),
            _StatTile(
              icon: Icons.category,
              label: 'Catégories',
              value: data.categories,
              color: Colors.teal,
            ),
            _StatTile(
              icon: Icons.shopping_cart,
              label: 'Commandes',
              value: data.orders,
              color: Colors.deepOrange,
            ),
            _StatTile(
              icon: Icons.local_shipping_outlined,
              label: 'Livraisons',
              value: data.deliveries,
              color: Colors.indigo,
            ),
            _StatTile(
              icon: Icons.route,
              label: 'Tournées',
              value: data.routes,
              color: Colors.purple,
            ),
            _StatTile(
              icon: Icons.warehouse,
              label: 'Stock',
              value: data.inventory,
              color: Colors.brown,
            ),
            _StatTile(
              icon: Icons.swap_vert,
              label: 'Mouvements',
              value: data.movements,
              color: Colors.cyan,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountsCard extends ConsumerWidget {
  const _AccountsCard({
    required this.depotId,
    required this.role,
    required this.title,
    required this.emptyText,
    required this.onResetPin,
    this.onAdd,
    this.addLabel,
  });

  final String depotId;
  final UserRole role;
  final String title;
  final String emptyText;
  final void Function(UserModel user) onResetPin;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(depotUsersProvider(depotId));

    return _SectionCard(
      title: title,
      trailing: onAdd == null
          ? null
          : TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(addLabel ?? 'Ajouter'),
            ),
      child: users.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Text(
          'Erreur : $e',
          style: const TextStyle(color: AppTheme.errorColor),
        ),
        data: (list) {
          final filtered =
              list.where((u) => u.role == role).toList()
                ..sort((a, b) => a.name.compareTo(b.name));
          if (filtered.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(emptyText, style: const TextStyle(color: Colors.grey)),
            );
          }
          return Column(
            children: [
              for (final user in filtered)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: Icon(
                      role == UserRole.admin
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    user.displayName,
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    [user.phone, user.email]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: 'Réinitialiser le PIN',
                    icon: const Icon(Icons.lock_reset, size: 20),
                    onPressed: () => onResetPin(user),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.roboto(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
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
    final error = await ref.read(depotProvider.notifier).createDepotAdmin(
          depotId: widget.depot.id,
          name: _nameController.text,
          pin: _pin,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(depotProvider).isBusy;

    return AlertDialog(
      title: const Text("Créer l'administrateur"),
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
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _valid && !busy ? _submit : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class _ResetPinDialog extends ConsumerStatefulWidget {
  const _ResetPinDialog({required this.user});

  final UserModel user;

  @override
  ConsumerState<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends ConsumerState<_ResetPinDialog> {
  String _pin = '';
  String _confirm = '';

  bool get _valid =>
      _pin.length == LocalFirstAuthService.pinLength && _pin == _confirm;

  Future<void> _submit() async {
    final error = await ref.read(depotProvider.notifier).resetUserPin(
          userId: widget.user.id,
          pin: _pin,
        );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.errorColor),
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(depotProvider).isBusy;

    return AlertDialog(
      title: const Text('Réinitialiser le PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.user.displayName,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            PinEntryField(
              label: 'Nouveau code PIN',
              length: LocalFirstAuthService.pinLength,
              onChanged: (value) => setState(() => _pin = value),
            ),
            const SizedBox(height: 16),
            PinEntryField(
              label: 'Confirmer le code PIN',
              length: LocalFirstAuthService.pinLength,
              onChanged: (value) => setState(() => _confirm = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: _valid && !busy ? _submit : null,
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
