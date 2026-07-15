import 'package:flutter/material.dart';

/// Big page title (Figma "Heading" — Poppins 34/w600/lh1.1).
/// Defaults to the primary text color; pass [color] for the ember variant
/// used on onboarding greetings.
class PageHeading extends StatelessWidget {
  final String text;
  final Color? color;
  final TextAlign? textAlign;

  const PageHeading(
    this.text, {
    Key? key,
    this.color,
    this.textAlign,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: textAlign,
      style: theme.textTheme.headlineLarge?.copyWith(color: color),
    );
  }
}
