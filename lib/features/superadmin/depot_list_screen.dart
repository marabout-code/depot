import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../models/depot_model.dart';
import '../../providers/depot_provider.dart';
import 'depot_detail_screen.dart';
import 'depot_form_screen.dart';

/// Superadmin-only list of every depot, with edit / activate / delete actions.
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

  Future<void> _reload() => ref.read(depotProvider.notifier).loadDepots();

  Future<void> _openForm({DepotModel? depot}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DepotFormScreen(existing: depot)),
    );
    await _reload();
  }

  Future<void> _openDetail(DepotModel depot) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DepotDetailScreen(depot: depot)),
    );
    await _reload();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${depot.name} supprimé.'),
        backgroundColor: error != null ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depotProvider);
    final busy = state.isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Dépôts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: busy ? null : () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Créer un dépôt'),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: state.depots.isEmpty
            ? _buildEmpty(state)
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
                itemCount: state.depots.length,
                itemBuilder: (context, index) => _buildCard(
                  state.depots[index],
                  busy: busy,
                ),
              ),
      ),
    );
  }

  Widget _buildCard(DepotModel depot, {required bool busy}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: depot.isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.grey.withValues(alpha: 0.2),
          child: Icon(
            Icons.warehouse,
            color: depot.isActive ? AppTheme.primaryColor : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                depot.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            _StatusChip(active: depot.isActive),
          ],
        ),
        subtitle: Text(
          [
            if (depot.city.isNotEmpty) depot.city,
            if (depot.address.isNotEmpty) depot.address,
          ].join(' · '),
        ),
        trailing: PopupMenuButton<String>(
          enabled: !busy,
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _openForm(depot: depot);
              case 'toggle':
                _toggleStatus(depot);
              case 'delete':
                _confirmDelete(depot);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.edit_outlined),
                title: Text('Modifier'),
              ),
            ),
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
                leading: Icon(Icons.delete_outline, color: AppTheme.errorColor),
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ),
          ],
        ),
        onTap: () => _openDetail(depot),
      ),
    );
  }

  Widget _buildEmpty(DepotsState state) {
    if (state.status == DepotsStatus.error) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Impossible de charger les dépôts : ${state.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 120),
        Icon(Icons.warehouse_outlined, size: 64, color: Colors.grey),
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primaryColor : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        active ? 'Actif' : 'Inactif',
        style: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
