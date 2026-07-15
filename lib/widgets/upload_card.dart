import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/theme.dart';
import 'package:closr_app/widgets/closr_card.dart';

/// Figma upload widget: grey avatar circle preview next to a
/// "Click to upload" card.
class UploadCard extends StatelessWidget {
  final VoidCallback? onTap;
  final ImageProvider? preview;
  final String subtitle;

  const UploadCard({
    Key? key,
    this.onTap,
    this.preview,
    this.subtitle = 'SVG, PNG, JPG or GIF\n(max. 800x400px)',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final placeholderBg =
        isDark ? ClosrColors.darkSurfaceElevated : ClosrColors.line;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: placeholderBg,
            backgroundImage: preview,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: ClosrCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(LucideIcons.cloudUpload,
                    size: 20, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  'Click to upload',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: ClosrColors.ember,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
