import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field with its label ABOVE the input (Figma input pattern),
/// instead of a Material floating label.
///
/// Single-line fields keep the theme's pill shape; multiline fields
/// switch to radius 16 (Figma Bio textarea). When [maxLength] is set a
/// "n/max" counter renders below-right.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final String? prefixText;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;

  const LabeledField({
    Key? key,
    required this.label,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.prefixText,
    this.enabled = true,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.suffixIcon,
    this.autofillHints,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multiline = maxLines > 1;

    InputBorder roundedBorder(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color, width: width),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Figma "Input with label": Poppins Regular 14, gap 6
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            suffixIcon: suffixIcon,
            // Multiline fields use radius 16 instead of the pill shape.
            enabledBorder: multiline
                ? roundedBorder(theme.colorScheme.outline, 1)
                : null,
            focusedBorder: multiline
                ? roundedBorder(theme.colorScheme.primary, 1.5)
                : null,
            border: multiline
                ? roundedBorder(theme.colorScheme.outline, 1)
                : null,
          ),
        ),
      ],
    );
  }
}
