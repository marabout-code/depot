import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/string_constants.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/user_role.dart';
import '../../providers/auth_provider.dart';
import 'pin_entry_field.dart';

/// Admin account creation.
///
/// The PIN entered here becomes the account's only credential, so it is
/// confirmed once before submission and validated locally with the same rules
/// the login screen enforces.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  String _pin = '';
  String _confirmPin = '';

  void _handleRegister() {
    if (!_formKey.currentState!.validate()) return;

    if (_pin != _confirmPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Les codes PIN ne correspondent pas'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    ref.read(authProvider.notifier).register(
          email: 'admin_${DateTime.now().millisecondsSinceEpoch}@depot.local',
          name: 'Administrateur',
          pin: _pin,
          role: UserRole.admin,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(StringConstants.frCreateAccount),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.local_drink,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    StringConstants.frCreateAccount,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choisissez un code PIN de '
                    '${LocalFirstAuthService.pinLength} chiffres. '
                    'Ce code sera votre identifiant de connexion.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PinEntryField(
                    label: StringConstants.frDriverPin,
                    length: LocalFirstAuthService.pinLength,
                    onChanged: (value) => setState(() => _pin = value),
                  ),
                  const SizedBox(height: 20),
                  PinEntryField(
                    label: 'Confirmer le code PIN',
                    length: LocalFirstAuthService.pinLength,
                    onChanged: (value) => setState(() => _confirmPin = value),
                  ),
                  const SizedBox(height: 32),
                  LoadingButton(
                    label: StringConstants.frCreateAccount,
                    isLoading: authState.isLoading,
                    onPressed: _handleRegister,
                    backgroundColor: AppTheme.primaryColor,
                    textColor: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '${StringConstants.frAlreadyHaveAccount} ${StringConstants.frLoginButton}',
                      style: GoogleFonts.roboto(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}