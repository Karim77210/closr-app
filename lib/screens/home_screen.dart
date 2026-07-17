import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/widgets/circle_icon_button.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'broadcast_screen.dart';
import 'discussions_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppUser user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _firestoreService = FirestoreService();
  late AppUser _user;
  StreamSubscription<AppUser?>? _userSub;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    // The initial `user` is a one-time snapshot from AuthWrapper — stream it
    // live so things like `stripeConnectOnboarded` update immediately after
    // e.g. connecting Stripe, instead of needing an app restart to notice.
    _userSub = _firestoreService.streamUser(widget.user.uid).listen((u) {
      if (u != null && mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  String get _publicLink {
    final origin = kIsWeb ? Uri.base.origin : 'https://closr.app';
    return '$origin/${_user.username}';
  }

  Future<void> _copyPublicLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _publicLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your paid link has been copied!')),
    );
  }

  void _handleShareTap(BuildContext context) {
    if (_user.stripeConnectOnboarded) {
      _copyPublicLink(context);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect Stripe first'),
        content: const Text(
          'You need to set up your Stripe account before you can share your paid link and start receiving subscriptions. Go to your profile → Wallet to connect it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WalletScreen(creator: _user)),
              );
            },
            child: const Text('Go to Wallet'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = _user.role == UserRole.creator;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── Top actions (share · broadcast · avatar) ─────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isCreator) ...[
                        CircleIconButton(
                          icon: LucideIcons.share2,
                          variant: CircleIconButtonVariant.filled,
                          onTap: () => _handleShareTap(context),
                        ),
                        const SizedBox(width: 10),
                        CircleIconButton(
                          icon: LucideIcons.megaphone,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BroadcastScreen(creator: _user),
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                      ],
                      ClosrAvatar(
                        photoUrl: _user.photoUrl?.isNotEmpty == true ? _user.photoUrl : null,
                        initialSource: _user.displayName,
                        size: 42,
                        ring: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProfileScreen(user: _user)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ─── Page title ───────────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: PageHeading('Conversations'),
                ),
                const SizedBox(height: 16),

                Expanded(child: DiscussionsScreen(user: _user)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
