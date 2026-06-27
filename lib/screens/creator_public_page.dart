import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:closr_app/main.dart' show PendingNavigation;
import 'package:closr_app/screens/chat_screen.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/stripe_service.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/models/subscription_model.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        elevation: 0,
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.blue[100],
                      backgroundImage: creator.photoUrl != null && creator.photoUrl!.isNotEmpty
                          ? NetworkImage(creator.photoUrl!) as ImageProvider
                          : null,
                      child: creator.photoUrl == null || creator.photoUrl!.isEmpty
                          ? Text(
                              creator.displayName.isNotEmpty
                                  ? creator.displayName[0].toUpperCase()
                                  : widget.username[0].toUpperCase(),
                              style: const TextStyle(fontSize: 40, color: Colors.white),
                            )
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${widget.username} invites you to chat privately.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Bio',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(shortBio, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subscription',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          priceLabel,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildActionSection(context, creator, isFull),
                    const SizedBox(height: 32),
                    _buildStatTile(
                      context,
                      'Subscribers',
                      '${creator.subscriberCount} / ${creator.subscriberLimit > 0 ? creator.subscriberLimit : '∞'}',
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
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildFullBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Full',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54),
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Creator not found', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'No active creator matches this username.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.red[700]),
        ),
      ),
    );
  }
}
