import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/string_constants.dart';
import '../../core/services/local_first_auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class PinLoginScreen extends ConsumerStatefulWidget {
  const PinLoginScreen({super.key});

  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen> {
  final _pinController = TextEditingController();
  final _pinFocusNode = FocusNode();
  bool _showError = false;
  bool _obscurePin = true;
  // Hidden until we know the device has no accounts yet, so the bootstrap
  // button never appears on an installation that already has a superadmin.
  bool _showRegister = false;

  static const _pinLength = LocalFirstAuthService.pinLength;

  @override
  void initState() {
    super.initState();
    _pinFocusNode.requestFocus();
    _checkForExistingAccounts();
  }

  Future<void> _checkForExistingAccounts() async {
    final hasCredentials =
        await ref.read(authServiceProvider).hasLocalCredentials();
    if (!mounted) return;
    setState(() => _showRegister = !hasCredentials);
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

  Widget _buildPinDisplay() {
    final pin = _pinController.text;
    if (!_obscurePin) {
      return Text(
        pin.isEmpty ? '····' : pin,
        textAlign: TextAlign.center,
        style: GoogleFonts.roboto(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 16,
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < pin.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppTheme.primaryColor : Colors.grey[300],
          ),
        );
      }),
    );
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Entrez votre code PIN',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    IconButton(
                      tooltip: _obscurePin
                          ? 'Afficher le code'
                          : 'Masquer le code',
                      icon: Icon(
                        _obscurePin
                            ? Icons.visibility_off
                            : Icons.visibility,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                      onPressed: () =>
                          setState(() => _obscurePin = !_obscurePin),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // PIN display: dots, or the digits themselves when revealed.
                _buildPinDisplay(),
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
                // Only on a fresh installation: creates the first superadmin.
                if (_showRegister) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RegisterScreen()),
                    ),
                    child: Text(
                      StringConstants.frCreateAccount,
                      style: GoogleFonts.roboto(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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
