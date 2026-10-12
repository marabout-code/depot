import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/demo_data_service.dart';
import '../../../core/services/license_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/demo_data_provider.dart';
import '../../../providers/theme_provider.dart';
import 'license_dialog.dart';
import 'category_settings_screen.dart';
import 'user_manual_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final demoData = ref.watch(demoDataProvider);
    final license = ref.watch(licenseServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Licence ---
          Card(
            color: bgColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        license.isActivated
                            ? Icons.verified
                            : Icons.info_outline,
                        size: 20,
                        color: license.isActivated
                            ? AppTheme.primaryColor
                            : AppTheme.errorColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Licence',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: Text(
                    license.isActivated
                        ? 'Activée'
                        : license.status == LicenseStatus.trialExpired
                            ? 'Essai expiré'
                            : 'Essai (${license.remainingDays} jours restants)',
                    style: GoogleFonts.roboto(),
                  ),
                  subtitle: Text(
                    'ID: ${license.deviceId.substring(0, 12)}...',
                    style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: license.isActivated
                      ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                      : TextButton(
                          onPressed: () async {
                            final result = await showDialog<bool>(
                              context: context,
                              barrierDismissible: true,
                              builder: (_) => const LicenseDialog(
                                trialExpired: false,
                              ),
                            );
                            if (result == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'Licence activée avec succès !'),
                                  backgroundColor: AppTheme.primaryColor,
                                ),
                              );
                            }
                          },
                          child: Text(
                            license.status == LicenseStatus.trialExpired
                                ? 'Activer'
                                : 'Mettre à niveau',
                            style: GoogleFonts.roboto(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Synchronisation ---
          const _SyncStatusCard(),
          const SizedBox(height: 16),

          // --- Apparence ---
          Card(
            color: bgColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.palette, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Apparence',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: Text('Mode sombre', style: GoogleFonts.roboto()),
                  subtitle: Text(
                    themeMode == ThemeMode.dark ? 'Activé' : 'Désactivé',
                    style: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (_) {
                    ref.read(themeModeProvider.notifier).toggle();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Démonstration ---
          Card(
            color: bgColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.science_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Démonstration',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: Text(
                    'Données de démonstration',
                    style: GoogleFonts.roboto(),
                  ),
                  subtitle: Text(
                    demoData.enabled
                        ? 'Des exemples de produits, commandes et tournées sont affichés.'
                        : 'Ajouter des exemples pour présenter l\'application.',
                    style: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                  value: demoData.enabled,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: demoData.busy
                      ? null
                      : (value) => _toggleDemoData(context, ref, value),
                ),
                if (demoData.enabled) _demoAccountsSection(context),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Catégories ---
          Card(
            color: bgColor,
            child: ListTile(
              leading: const Icon(Icons.category, size: 20),
              title:
                  Text('Catégories', style: GoogleFonts.roboto()),
              subtitle: Text(
                'Gérer les catégories de produits',
                style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CategorySettingsScreen(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // --- Sauvegarde & Restauration ---
          Card(
            color: bgColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.backup, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Sauvegarde & Restauration',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload_outlined),
                  title:
                      Text('Exporter les données', style: GoogleFonts.roboto()),
                  subtitle: Text(
                    'Choisir l\'emplacement du fichier JSON',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  onTap: () => _exportBackup(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined),
                  title:
                      Text('Restaurer les données', style: GoogleFonts.roboto()),
                  subtitle: Text(
                    'Choisir un fichier JSON',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  onTap: () => _pickAndRestore(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Aide & Support ---
          Card(
            color: bgColor,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Aide & Support',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text('Guide d\'utilisation',
                      style: GoogleFonts.roboto()),
                  subtitle: Text(
                    'Apprendre à utiliser l\'application',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const UserManualScreen(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: Text(AppConstants.supportEmail,
                      style: GoogleFonts.roboto()),
                  subtitle: Text(
                    'E-mail du support',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  onTap: () => _openEmail(context),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(AppConstants.supportPhone,
                      style: GoogleFonts.roboto()),
                  subtitle: Text(
                    'Téléphone / WhatsApp',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  onTap: () => _openPhone(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Informations ---
          Card(
            color: bgColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Informations',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(authState.user?.name ?? ''),
                  subtitle: Text(authState.user?.email ?? ''),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Application'),
                  subtitle: Text(
                    '${StringConstants.frAppName} v${AppConstants.appVersion}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // --- Déconnexion ---
          Card(
            color: bgColor,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.errorColor),
              title: Text(
                StringConstants.frLogout,
                style: GoogleFonts.roboto(color: AppTheme.errorColor),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(StringConstants.frLogout),
                    content: const Text(
                        'Voulez-vous vraiment vous déconnecter ?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref.read(authProvider.notifier).logout();
                          // Leaving the depot device signed in would expose the
                          // next user's data, so logout closes the app outright
                          // rather than dropping back to the PIN screen.
                          await SystemNavigator.pop();
                        },
                        child: Text(
                          StringConstants.frLogout,
                          style: GoogleFonts.roboto(
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDemoData(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(demoDataProvider.notifier).setEnabled(value);
    final error = ref.read(demoDataProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error != null
              ? 'Erreur : $error'
              : value
                  ? 'Données de démonstration activées.'
                  : 'Données de démonstration supprimées.',
        ),
        backgroundColor:
            error != null ? AppTheme.errorColor : AppTheme.primaryColor,
      ),
    );
  }

  Widget _demoAccountsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Comptes de démonstration',
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Déconnectez-vous, puis connectez-vous avec l\'un de ces codes PIN '
            'pour voir ce que chaque rôle peut faire.',
            style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          for (final account in DemoDataService.accounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      account.label,
                      style: GoogleFonts.roboto(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      account.pin,
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      final backup = ref.read(backupServiceProvider);
      final json = await backup.exportRawJsonString();
      final fileName =
          'sauvegarde_${DateTime.now().millisecondsSinceEpoch}.json';
      final bytes = Uint8List.fromList(utf8.encode(json));

      // Opens the system "save as" dialog so the user chooses the destination.
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Enregistrer la sauvegarde',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (path == null) return; // Cancelled by the user.

      // Some platforms only return the chosen path and leave the write to us.
      try {
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes, flush: true);
        }
      } catch (_) {
        // Android already wrote the bytes; a content:// path is not directly
        // writable, which is fine here.
      }

      scaffold.showSnackBar(
        SnackBar(
          content: Text('Sauvegarde enregistrée'),
          backgroundColor: AppTheme.primaryColor,
        ),
      );
    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Erreur : $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Future<void> _pickAndRestore(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;
      if (!File(filePath).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fichier introuvable.'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
        return;
      }

      final backup = ref.read(backupServiceProvider);
      final count = await backup.importFromFile(filePath);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count documents restaurés.'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: 'subject=${Uri.encodeComponent('Support Dépôt Distribution')}',
    );
    await _launchSupport(context, uri);
  }

  Future<void> _openPhone(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/${AppConstants.whatsAppNumber}');
    await _launchSupport(context, uri);
  }

  Future<void> _launchSupport(BuildContext context, Uri uri) async {
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

/// Live sync state for a depot operator on an unreliable link: whether the app
/// is online, how many local changes are still queued, when the last pass
/// succeeded, and a button to force one now.
class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final status =
        ref.watch(syncStatusProvider).valueOrNull ?? const SyncStatus();

    final pending = status.pendingWrites;
    final syncing = status.running;
    final hasError = !syncing && status.online && status.lastError != null;

    final IconData icon;
    final Color color;
    if (syncing) {
      icon = Icons.sync;
      color = AppTheme.primaryColor;
    } else if (!status.online) {
      icon = Icons.cloud_off;
      color = AppTheme.secondaryColor;
    } else if (hasError) {
      icon = Icons.error_outline;
      color = AppTheme.errorColor;
    } else if (pending > 0) {
      icon = Icons.cloud_upload;
      color = AppTheme.secondaryColor;
    } else {
      icon = Icons.cloud_done;
      color = AppTheme.primaryColor;
    }

    final String stateLabel = syncing
        ? StringConstants.frSyncSyncing
        : status.online
            ? StringConstants.frSyncOnline
            : StringConstants.frSyncOffline;

    final String detail;
    if (pending > 0) {
      detail = '$pending ${StringConstants.frSyncQueued}';
    } else if (hasError) {
      detail = status.lastError!;
    } else {
      detail = StringConstants.frSyncAllSynced;
    }

    final lastAt = status.lastSyncedAt;

    return Card(
      color: bgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync, size: 20),
                const SizedBox(width: 8),
                Text(
                  StringConstants.frSyncTitle,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  stateLabel,
                  style: GoogleFonts.roboto(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(detail, style: GoogleFonts.roboto(fontSize: 14)),
            subtitle: Text(
              lastAt == null
                  ? StringConstants.frSyncNever
                  : '${StringConstants.frSyncLastAt} ${_formatTime(lastAt)}',
              style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey),
            ),
            trailing: syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: StringConstants.frSyncNow,
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.read(syncServiceProvider).syncNow(),
                  ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
