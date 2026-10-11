import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

/// In-app user guide. Every section lists the steps for one part of the app,
/// and the contact card at the bottom exposes the support credentials.
class UserManualScreen extends StatelessWidget {
  const UserManualScreen({super.key});

  static const List<_ManualSectionData> _sections = [
    _ManualSectionData(
      icon: Icons.info_outline,
      color: AppTheme.primaryColor,
      title: 'Présentation',
      steps: [
        'Dépôt Distribution gère les produits, commandes, conducteurs et '
            'tournées de votre dépôt.',
        'L\'application fonctionne hors ligne : les données sont stockées '
            'localement puis synchronisées dès que le réseau revient.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.lock_outline,
      color: Colors.blue,
      title: 'Connexion & sécurité',
      steps: [
        'Connectez-vous avec votre e-mail et votre mot de passe.',
        'Sans réseau, utilisez votre code PIN à 4 chiffres.',
        'Le bouton de déconnexion se trouve en haut à droite de l\'écran.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.dashboard_outlined,
      color: Colors.indigo,
      title: 'Tableau de bord',
      steps: [
        'Accédez à chaque module depuis les cartes : Produits, Commandes, '
            'Conducteurs, Tournées, Inventaire, Rapports et Paramètres.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.inventory_2_outlined,
      color: AppTheme.secondaryColor,
      title: 'Produits',
      steps: [
        'Appuyez sur + pour ajouter un produit (nom, catégorie, prix, unité).',
        'Appuyez sur un produit pour le modifier ou le supprimer.',
        'Gérez les catégories depuis Paramètres puis Catégories.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.shopping_cart_outlined,
      color: Colors.orange,
      title: 'Commandes',
      steps: [
        'Créez une commande avec le bouton + : choisissez le client puis '
            'ajoutez les articles.',
        'Suivez le statut : En attente, Confirmée, En préparation, '
            'En livraison, Livrée, Annulée.',
        'Assignez un conducteur depuis le détail d\'une commande.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.local_shipping_outlined,
      color: Colors.purple,
      title: 'Conducteurs & Tournées',
      steps: [
        'Ajoutez un conducteur depuis le module Conducteurs.',
        'Créez une tournée : nom, date, conducteur et commandes à livrer.',
        'Le conducteur démarre la tournée en un geste; chaque commande passe '
            'alors en « En livraison ».',
      ],
    ),
    _ManualSectionData(
      icon: Icons.warehouse_outlined,
      color: Colors.brown,
      title: 'Inventaire',
      steps: [
        'Mettez à jour la quantité en stock de chaque produit.',
        'Les mouvements d\'entrée et de sortie sont enregistrés '
            'automatiquement.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.bar_chart_outlined,
      color: Colors.teal,
      title: 'Rapports',
      steps: [
        'Consultez les ventes, les livraisons et la performance des '
            'conducteurs.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.backup_outlined,
      color: Colors.blueGrey,
      title: 'Sauvegarde & restauration',
      steps: [
        'Exportez une sauvegarde JSON depuis Paramètres.',
        'Restaurez vos données à partir d\'un fichier de sauvegarde.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.verified_outlined,
      color: AppTheme.primaryColor,
      title: 'Licence',
      steps: [
        'L\'application est en essai gratuit pendant ${AppConstants.trialDays} '
            'jours.',
        'Pour activer, copiez votre ID d\'appareil puis contactez le support.',
        'Saisissez ensuite la clé de 64 caractères dans le champ d\'activation.',
      ],
    ),
    _ManualSectionData(
      icon: Icons.cloud_off_outlined,
      color: Colors.grey,
      title: 'Mode hors ligne',
      steps: [
        'Une bannière indique l\'état hors ligne; vos modifications sont '
            'conservées.',
        'À la reconnexion, tout est synchronisé automatiquement.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guide d\'utilisation')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in _sections) _ManualSection(data: section),
          const SizedBox(height: 8),
          _buildContactCard(context),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildContactCard(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.support_agent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Support & contact',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text(AppConstants.supportEmail),
            subtitle:
                Text('E-mail', style: GoogleFonts.roboto(fontSize: 13)),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _contactEmail(context),
          ),
          ListTile(
            leading: const Icon(Icons.phone_outlined),
            title: const Text(AppConstants.supportPhone),
            subtitle:
                Text('Téléphone / WhatsApp',
                    style: GoogleFonts.roboto(fontSize: 13)),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _contactPhone(context),
          ),
        ],
      ),
    );
  }

  Future<void> _contactEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=${Uri.encodeComponent('Support Dépôt Distribution')}',
    );
    await _launch(context, uri);
  }

  Future<void> _contactPhone(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/${AppConstants.whatsAppNumber}');
    await _launch(context, uri);
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) {
        await Clipboard.setData(ClipboardData(text: uri.path));
        messenger.showSnackBar(
          const SnackBar(content: Text('Information copiée')),
        );
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: uri.path));
      messenger.showSnackBar(
        const SnackBar(content: Text('Information copiée')),
      );
    }
  }
}

class _ManualSection extends StatelessWidget {
  final _ManualSectionData data;

  const _ManualSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: data.title == 'Présentation',
          leading: CircleAvatar(
            backgroundColor: data.color.withValues(alpha: 0.12),
            child: Icon(data.icon, size: 20, color: data.color),
          ),
          title: Text(
            data.title,
            style: GoogleFonts.roboto(fontWeight: FontWeight.bold),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final step in data.steps)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 16, color: data.color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step,
                        style: GoogleFonts.roboto(fontSize: 14, height: 1.4),
                      ),
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

class _ManualSectionData {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> steps;

  const _ManualSectionData({
    required this.icon,
    required this.color,
    required this.title,
    required this.steps,
  });
}
