import 'package:flutter/material.dart';
import 'package:closr_app/theme.dart';

enum CircleIconButtonVariant { filled, outlined }

enum CircleIconButtonShape { circle, squircle }

/// Figma icon button: p-10 + 20px icon → 40px, radius 99, 1px
/// action/subtle stroke on both variants, no shadow.
/// filled = ember bg + white icon · outlined = white bg + ink icon.
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final CircleIconButtonVariant variant;
  final CircleIconButtonShape shape;
  final double size;
  final double? iconSize;
  final Color? iconColor;

  const CircleIconButton({
    Key? key,
    required this.icon,
    this.onTap,
    this.variant = CircleIconButtonVariant.outlined,
    this.shape = CircleIconButtonShape.circle,
    this.size = 40,
    this.iconSize,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filled = variant == CircleIconButtonVariant.filled;

    final bg = filled ? ClosrColors.ember : theme.colorScheme.surface;
    final fg = iconColor ??
        (filled ? Colors.white : theme.colorScheme.onSurface);
    final border = isDark ? ClosrColors.darkEmberSubtle : ClosrColors.emberSoft;
    final radius = shape == CircleIconButtonShape.circle
        ? BorderRadius.circular(size)
        : BorderRadius.circular(14);

    return Material(
      color: bg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return ClosrColors.emberHover.withAlpha(filled ? 60 : 30);
          }
          return null;
        }),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: border, width: 1),
          ),
          child: Icon(icon, size: iconSize ?? size * 0.5, color: fg),
        ),
      ),
    );
  }
}
