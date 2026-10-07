import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/string_constants.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _showError = false;

  static const _pinLength = LocalFirstAuthService.pinLength;

  @override
  void initState() {
    super.initState();
    _pinFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _onDigitTap(String digit) {
    if (_pinController.text.length < _pinLength) {
      setState(() {
        _showError = false;
        _pinController.text += digit;
      });
      if (_pinController.text.length == _pinLength) {
        _submitPin();
      }
    }
  }

  void _onDeleteTap() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(
            0, _pinController.text.length - 1);
        _showError = false;
      });
    }
  }

  void _submitPin() {
    _pinFocusNode.unfocus();
    ref.read(authProvider.notifier).loginWithPin(_pinController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        setState(() => _showError = true);
        _pinController.clear();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_drink,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  StringConstants.frAppName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Entrez votre code PIN',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                // PIN dots display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pinLength, (i) {
                    final filled = i < _pinController.text.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled
                            ? AppTheme.primaryColor
                            : Colors.grey[300],
                      ),
                    );
                  }),
                ),
                if (_showError && authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    style: GoogleFonts.roboto(
                      color: AppTheme.errorColor,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                // Numeric keypad
                _buildNumericKeypad(authState.isLoading),
                const SizedBox(height: 24),
                // Admin fallback for a forgotten PIN.
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                    icon: const Icon(Icons.admin_panel_settings),
                    label: Text(StringConstants.frAdminLogin),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Works without a connection, so it is worth saying so.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.offline_bolt_outlined,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Connexion hors ligne · $_pinLength chiffres',
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad(bool isLoading) {
    return Column(
      children: [
        _buildRow(['1', '2', '3'], isLoading),
        _buildRow(['4', '5', '6'], isLoading),
        _buildRow(['7', '8', '9'], isLoading),
        _buildRow(['', '0', 'del'], isLoading),
      ],
    );
  }

  Widget _buildRow(List<String> keys, bool isLoading) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key == 'del') {
          return _buildKey(
            child: const Icon(Icons.backspace_outlined, size: 28),
            onTap: isLoading ? null : _onDeleteTap,
          );
        }
        if (key.isEmpty) {
          return const SizedBox(width: 80, height: 64);
        }
        return _buildKey(
          child: Text(
            key,
            style: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.w500),
          ),
          onTap: isLoading ? null : () => _onDigitTap(key),
        );
      }).toList(),
    );
  }

  Widget _buildKey({required Widget child, VoidCallback? onTap}) {
    return Container(
      width: 80,
      height: 64,
      margin: const EdgeInsets.all(4),
      child: Material(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Center(child: child),
        ),
      ),
    );
  }
}
