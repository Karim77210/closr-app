import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/theme.dart';

/// Circular avatar with the Closr treatments: optional ember ring,
/// online dot, and edit-pencil badge (Figma UI kit avatars).
///
/// Falls back to the first letter of [initialSource] on an ember-subtle
/// background when [photoUrl] is null.
class ClosrAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initialSource;
  final double size;
  final bool ring;
  final bool onlineDot;
  final bool editBadge;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;

  const ClosrAvatar({
    Key? key,
    this.photoUrl,
    this.initialSource = '?',
    this.size = 44,
    this.ring = false,
    this.onlineDot = false,
    this.editBadge = false,
    this.onTap,
    this.onEditTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fallbackBg =
        isDark ? ClosrColors.darkEmberSubtle : ClosrColors.emberSoft;
    final initial =
        initialSource.isNotEmpty ? initialSource[0].toUpperCase() : '?';

    Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: fallbackBg,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
      child: photoUrl == null
          ? Text(
              initial,
              style: TextStyle(
                color: ClosrColors.ember,
                fontWeight: FontWeight.w600,
                fontSize: size * 0.4,
              ),
            )
          : null,
    );

    if (ring) {
      // Figma "PP button": 2px ember border with 4px inset gap
      avatar = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ClosrColors.ember, width: 2),
        ),
        child: avatar,
      );
    }

    if (onlineDot || editBadge) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          if (onlineDot)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: ClosrColors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
          if (editBadge)
            // Figma edit badge: white circle, action/subtle stroke,
            // 20px lucide pencil, overlapping the bottom-right corner.
            Positioned(
              right: -4,
              bottom: -4,
              child: GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? ClosrColors.darkEmberSubtle
                          : ClosrColors.emberSoft,
                    ),
                  ),
                  child: const Icon(
                    LucideIcons.pencil,
                    size: 20,
                    color: ClosrColors.ember,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (onTap == null) return avatar;
    return GestureDetector(onTap: onTap, child: avatar);
  }
}
