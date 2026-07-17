import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/widgets/closr_card.dart';
import 'package:closr_app/theme.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  final String creatorUsername;

  const SubscriptionSuccessScreen({Key? key, required this.creatorUsername}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ClosrCard(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: ClosrColors.green.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.circleCheck,
                        size: 48, color: ClosrColors.green),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Subscription active!',
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can now chat with $creatorUsername.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (_) => false,
                      ),
                      child: const Text('Go to my chats'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
