import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/license_service.dart';
import '../../../core/theme/app_theme.dart';

class LicenseDialog extends ConsumerStatefulWidget {
  final bool trialExpired;

  const LicenseDialog({super.key, this.trialExpired = false});

  @override
  ConsumerState<LicenseDialog> createState() => _LicenseDialogState();
}

class _LicenseDialogState extends ConsumerState<LicenseDialog> {
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _copyDeviceId() async {
    final deviceId = ref.read(licenseServiceProvider).deviceId;
    await Clipboard.setData(ClipboardData(text: deviceId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ID de l\'appareil copié'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final deviceId = ref.read(licenseServiceProvider).deviceId;
    final message =
        'Bonjour, voici mon ID d\'appareil pour la licence : $deviceId';
    final uri = Uri.parse(
        'https://wa.me/${AppConstants.whatsAppNumber}?text=${Uri.encodeComponent(message)}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Aucune application pour ouvrir ce lien.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = ref.read(licenseServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.trialExpired
                        ? Icons.lock_outline
                        : Icons.workspace_premium,
                    size: 56,
                    color: widget.trialExpired
                        ? AppTheme.errorColor
                        : AppTheme.secondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.trialExpired
                        ? 'Période d\'essai expirée'
                        : 'Mettre à niveau',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.trialExpired
                        ? 'Votre période d\'essai de ${AppConstants.trialDays} jours est terminée. Activez l\'application pour continuer à utiliser toutes les fonctionnalités.'
                        : 'Activez toutes les fonctionnalités avec une licence permanente.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ID de l\'appareil',
                              style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy, size: 12, color: Colors.grey),
                          ],
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _copyDeviceId,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              license.deviceId,
                              style: GoogleFonts.roboto(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Appuyez sur l\'ID pour le copier',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Envoyez cet ID au ${AppConstants.whatsAppContact} pour obtenir votre clé de licence.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _openWhatsApp,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF128C7E),
                              side: const BorderSide(color: Color(0xFF25D366)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.chat,
                                size: 18, color: Color(0xFF25D366)),
                            label: Text(
                              'Contacter via WhatsApp',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _keyController,
                    maxLength: 64,
                    decoration: InputDecoration(
                      labelText: 'Clé de licence',
                      hintText: 'Collez votre clé de 64 caractères',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: GoogleFonts.roboto(
                          color: AppTheme.errorColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final navigator = Navigator.of(context);
                              setState(() {
                                _loading = true;
                                _error = null;
                              });
                              final ok = await license
                                  .activate(_keyController.text);
                              if (!mounted) return;
                              setState(() => _loading = false);
                              if (ok) {
                                navigator.pop(true);
                              } else {
                                setState(() => _error =
                                    'Clé de licence invalide.');
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Activer',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!widget.trialExpired)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: Icon(Icons.close, size: 20, color: Colors.grey.shade600),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Fermer',
              ),
            ),
        ],
      ),
    );
  }
}
