import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Digit-only PIN entry with a dot indicator.
///
/// Digits are filtered as they are typed and the field is capped at [length], so
/// the value can never hold anything a PIN login would reject.
class PinEntryField extends StatelessWidget {
  const PinEntryField({
    super.key,
    required this.label,
    required this.length,
    required this.onChanged,
  });

  final String label;
  final int length;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        _PinDots(length: length, onChanged: onChanged),
      ],
    );
  }
}

class _PinDots extends StatefulWidget {
  const _PinDots({required this.length, required this.onChanged});

  final int length;
  final ValueChanged<String> onChanged;

  @override
  State<_PinDots> createState() => _PinDotsState();
}

class _PinDotsState extends State<_PinDots> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: widget.length,
      obscuringCharacter: '●',
      showCursor: false,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(widget.length),
      ],
      onChanged: (next) {
        setState(() {});
        widget.onChanged(next);
      },
      style: const TextStyle(
        letterSpacing: 24,
        fontSize: 18,
        height: 1.6,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: '•' * widget.length,
        hintStyle: const TextStyle(letterSpacing: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}