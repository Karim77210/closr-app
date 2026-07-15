import 'package:flutter/material.dart';
import 'package:closr_app/theme.dart';

/// Inline error banner (rose border on a card surface).
class ErrorBanner extends StatelessWidget {
  final String message;

  const ErrorBanner(this.message, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClosrColors.rose),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(color: ClosrColors.rose),
      ),
    );
  }
}
