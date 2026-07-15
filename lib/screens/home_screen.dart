import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/widgets/circle_icon_button.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/page_heading.dart';
import 'broadcast_screen.dart';
import 'discussions_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final AppUser user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  String get _publicLink {
    final origin = kIsWeb ? Uri.base.origin : 'https://closr.app';
    return '$origin/${user.username}';
  }

  Future<void> _copyPublicLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _publicLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your paid link has been copied!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = user.role == UserRole.creator;

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
                          icon: Icons.share_outlined,
                          variant: CircleIconButtonVariant.filled,
                          size: 40,
                          onTap: () => _copyPublicLink(context),
                        ),
                        const SizedBox(width: 10),
                        CircleIconButton(
                          icon: Icons.campaign_outlined,
                          size: 40,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BroadcastScreen(creator: user),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      ClosrAvatar(
                        photoUrl: user.photoUrl?.isNotEmpty == true ? user.photoUrl : null,
                        initialSource: user.displayName,
                        size: 40,
                        ring: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ProfileScreen(user: user)),
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

                Expanded(child: DiscussionsScreen(user: user)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
