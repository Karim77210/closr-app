import 'package:flutter/material.dart';
import 'package:closr_app/theme.dart';

class SubscriptionSuccessScreen extends StatelessWidget {
  final String creatorUsername;

  const SubscriptionSuccessScreen({Key? key, required this.creatorUsername}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: ClosrColors.green.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 48, color: ClosrColors.green),
                ),
                const SizedBox(height: 24),
                Text(
                  'Subscription active!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can now chat with $creatorUsername.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/',
                      (_) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Go to my chats', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                if (creatorUsername.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                      '/$creatorUsername',
                      (_) => false,
                    ),
                    child: Text('Back to @$creatorUsername'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
