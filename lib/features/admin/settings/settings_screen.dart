import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/string_constants.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/services/license_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/theme_provider.dart';
import 'license_dialog.dart';
import 'category_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
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
                              barrierDismissible: false,
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
                    'Partager la sauvegarde JSON',
                    style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey),
                  ),
                  onTap: () async {
                    final backup = ref.read(backupServiceProvider);
                    final scaffold = ScaffoldMessenger.of(context);
                    try {
                      final dir = await getApplicationDocumentsDirectory();
                      final fileName =
                          'sauvegarde_${DateTime.now().millisecondsSinceEpoch}.json';
                      final file = File('${dir.path}/$fileName');
                      final json = await backup.exportRawJsonString();
                      await file.writeAsString(json);
                      if (context.mounted) {
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Sauvegarde enregistrée'),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        scaffold.showSnackBar(
                          SnackBar(
                            content: Text('Erreur : $e'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
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
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          ref.read(authProvider.notifier).logout();
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
}
