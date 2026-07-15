import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:closr_app/main.dart' show PendingNavigation;
import 'package:closr_app/screens/chat_screen.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/models/subscription_model.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/closr_card.dart';
import 'package:closr_app/widgets/grouped_list.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'package:closr_app/theme.dart';

class CreatorPublicPage extends StatefulWidget {
  final String username;

  const CreatorPublicPage({Key? key, required this.username}) : super(key: key);

  @override
  State<CreatorPublicPage> createState() => _CreatorPublicPageState();
}

class _CreatorPublicPageState extends State<CreatorPublicPage> {
  final _firestoreService = FirestoreService();
  final _stripeService = StripeService();
  bool _isCheckoutLoading = false;

  Future<void> _handleSubscribe(AppUser creator) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    setState(() => _isCheckoutLoading = true);
    try {
      await _stripeService.startCheckout(creator.uid);
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isCheckoutLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClosrLogoMark(size: 28),
            const SizedBox(width: 10),
            Text('Closr', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
      body: FutureBuilder<AppUser?>(
        future: _firestoreService.getCreatorByUsername(widget.username),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildError(context, 'An error occurred while loading creator profile.');
          }

          final creator = snapshot.data;
          if (creator == null) {
            return _buildNotFound(context);
          }

          final shortBio = creator.bio.trim().isEmpty
              ? 'No bio yet. This creator will add a short introduction soon.'
              : creator.bio.length <= 100
                  ? creator.bio
                  : '${creator.bio.substring(0, 100).trim()}...';

          final isFull = creator.subscriberLimit > 0 && creator.subscriberCount >= creator.subscriberLimit;
          final priceLabel = creator.subscriptionPriceCents > 0
              ? '€${(creator.subscriptionPriceCents / 100).toStringAsFixed(0)} / month'
              : 'Free';

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClosrAvatar(
                      photoUrl: creator.photoUrl?.isNotEmpty == true ? creator.photoUrl : null,
                      initialSource: creator.displayName.isNotEmpty
                          ? creator.displayName
                          : widget.username,
                      size: 92,
                      ring: true,
                    ),
                    const SizedBox(height: 20),
                    PageHeading(
                      creator.displayName,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${widget.username}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: ClosrColors.ember,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.username} invites you to chat privately.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SectionTitle('Bio'),
                    ClosrCard(
                      child: Text(shortBio, style: theme.textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subscription',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(priceLabel, style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildActionSection(context, creator, isFull),
                    const SizedBox(height: 24),
                    ClosrCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subscribers', style: theme.textTheme.titleSmall),
                          Text(
                            '${creator.subscriberCount} / ${creator.subscriberLimit > 0 ? creator.subscriberLimit : '∞'}',
                            style: theme.textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, AppUser creator, bool isFull) {
    if (isFull) return _buildFullBadge();

    final currentUser = FirebaseAuth.instance.currentUser;

    // Creator viewing their own page
    if (currentUser != null && currentUser.uid == creator.uid) {
      return const SizedBox.shrink();
    }

    // Not logged in — store intent and redirect to login
    if (currentUser == null) {
      return _buildStartButton(
        label: 'Start chatting',
        onPressed: () {
          PendingNavigation.returnTo = '/${creator.username}';
          PendingNavigation.checkoutCreatorUid = creator.uid;
          Navigator.of(context).pushNamed('/login');
        },
      );
    }

    // Stream subscription status for the logged-in subscriber
    return StreamBuilder<Subscription?>(
      stream: _firestoreService.streamSubscription(currentUser.uid, creator.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 52,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final isActive = snapshot.data?.isActive ?? false;

        if (isActive) {
          return _buildStartButton(
            label: 'Open chat',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChatScreen(
                creatorUid: creator.uid,
                subscriberUid: currentUser.uid,
              ),
            )),
          );
        }

        // Auto-trigger checkout if returning from login with a pending intent
        if (PendingNavigation.checkoutCreatorUid == creator.uid) {
          PendingNavigation.checkoutCreatorUid = null;
          WidgetsBinding.instance.addPostFrameCallback((_) => _handleSubscribe(creator));
        }

        return _buildStartButton(
          label: 'Start chatting',
          isLoading: _isCheckoutLoading,
          onPressed: _isCheckoutLoading ? null : () => _handleSubscribe(creator),
        );
      },
    );
  }

  Widget _buildStartButton({
    required String label,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }

  Widget _buildFullBadge() {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Full',
        textAlign: TextAlign.center,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Creator not found',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'No active creator matches this username.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: ClosrColors.rose),
        ),
      ),
    );
  }
}
