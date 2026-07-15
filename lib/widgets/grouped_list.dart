import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/theme.dart';

/// Section title above a [GroupedSection] — Figma: Poppins SemiBold 17,
/// primary text at 40% opacity ("Payments", "Security").
class SectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionTitle(
    this.text, {
    Key? key,
    this.padding = const EdgeInsets.only(top: 18, bottom: 8),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(102),
          height: 1,
        ),
      ),
    );
  }
}

/// iOS-style grouped table view (Figma "Grouped Table View"):
/// plain white card, radius 14, no border, no shadow, inset hairlines.
class GroupedSection extends StatelessWidget {
  final List<Widget> children;

  const GroupedSection({Key? key, required this.children}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final separator = isDark ? ClosrColors.darkSeparator : ClosrColors.separator;

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        // Inset: 16 padding + 16 icon + 14 gap
        rows.add(Divider(height: 1, thickness: 1, indent: 46, color: separator));
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// A row inside a [GroupedSection] — Figma "Row": h48, px-16, 16px icon,
/// gap 14, Poppins Medium 14 label, 16px chevron-right.
class GroupedRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  const GroupedRow({
    Key? key,
    required this.icon,
    required this.label,
    this.onTap,
    this.trailing,
    this.destructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = destructive ? ClosrColors.rose : theme.colorScheme.onSurface;
    final iconColor = destructive ? ClosrColors.rose : theme.colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(color: labelColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null)
                trailing!
              else if (!destructive)
                Icon(LucideIcons.chevronRight,
                    size: 16, color: theme.colorScheme.onSurface),
            ],
          ),
        ),
      ),
    );
  }
}
