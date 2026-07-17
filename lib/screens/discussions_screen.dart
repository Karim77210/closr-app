import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/subscription_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/screens/chat_screen.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/theme.dart';
import 'package:intl/intl.dart';

class DiscussionsScreen extends StatelessWidget {
  final AppUser user;

  const DiscussionsScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCreator = user.role == UserRole.creator;

    return isCreator
        ? _CreatorInbox(creator: user)
        : _SubscriberInbox(subscriber: user);
  }
}

/// Figma time label: "17:00" today, "SATURDAY" within a week, else "12/07".
String? conversationTimeLabel(DateTime? dt) {
  if (dt == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) return DateFormat('HH:mm').format(dt);
  if (daysAgo < 7) return DateFormat('EEEE').format(dt).toUpperCase();
  return DateFormat('dd/MM').format(dt);
}

// ─── Creator Inbox (sorted by most recent activity) ──────────────────────────

class _CreatorInbox extends StatelessWidget {
  final AppUser creator;
  const _CreatorInbox({required this.creator});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FirestoreService().streamCreatorConversationsSorted(creator.uid),
      builder: (context, convSnapshot) {
        // Also stream subscriptions to catch subscribers with no messages yet
        return StreamBuilder<List<Subscription>>(
          stream: FirestoreService().streamCreatorConversations(creator.uid),
          builder: (context, subSnapshot) {
            if (convSnapshot.connectionState == ConnectionState.waiting &&
                subSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final conversations = convSnapshot.data ?? [];
            final allSubscriptions = subSnapshot.data ?? [];

            // Subscribers who have exchanged messages (sorted by most recent)
            final convSubscriberUids = conversations
                .map((c) => c['subscriberUid'] as String?)
                .whereType<String>()
                .toSet();

            // Subscribers with no messages yet
            final noMessageSubs = allSubscriptions
                .where((s) => !convSubscriberUids.contains(s.subscriberUid))
                .toList();

            if (conversations.isEmpty && noMessageSubs.isEmpty) {
              return _buildEmpty(context, true);
            }

            final totalCount = conversations.length + noMessageSubs.length;

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: totalCount,
              separatorBuilder: (context, _) => Divider(
            height: 1,
            indent: 96,
            endIndent: 20,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(26),
          ),
              itemBuilder: (context, index) {
                if (index < conversations.length) {
                  final conv = conversations[index];
                  return _CreatorConversationTile(
                    creatorUid: creator.uid,
                    subscriberUid: conv['subscriberUid'] as String,
                    conversationMeta: conv,
                  );
                } else {
                  final sub = noMessageSubs[index - conversations.length];
                  return _CreatorConversationTile(
                    creatorUid: creator.uid,
                    subscriberUid: sub.subscriberUid,
                    conversationMeta: null,
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

// ─── Subscriber Inbox ─────────────────────────────────────────────────────────

class _SubscriberInbox extends StatelessWidget {
  final AppUser subscriber;
  const _SubscriberInbox({required this.subscriber});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Subscription>>(
      stream: FirestoreService().streamSubscriberConversations(subscriber.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final subscriptions = snapshot.data ?? [];

        if (subscriptions.isEmpty) return _buildEmpty(context, false);

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: subscriptions.length,
          separatorBuilder: (context, _) => Divider(
            height: 1,
            indent: 96,
            endIndent: 20,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(26),
          ),
          itemBuilder: (context, index) {
            final sub = subscriptions[index];
            return _ConversationTile(
              subscription: sub,
              currentUserUid: subscriber.uid,
              currentUserIsCreator: false,
            );
          },
        );
      },
    );
  }
}

// ─── Shared conversation row (Figma "Conversation item") ─────────────────────

class _ConversationRow extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String lastMessage;
  final String? timeLabel;
  final int unreadCount;
  final VoidCallback onTap;

  const _ConversationRow({
    required this.name,
    required this.photoUrl,
    required this.lastMessage,
    required this.timeLabel,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: onTap,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered)) {
          return ClosrColors.emberHover.withAlpha(20);
        }
        return null;
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClosrAvatar(
              photoUrl: photoUrl,
              initialSource: name,
              size: 64,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasUnread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 4),
                if (timeLabel != null)
                  Text(
                    timeLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: hasUnread
                          ? ClosrColors.ember
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (hasUnread) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: ClosrColors.ember,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Creator Conversation Tile (uses pre-loaded meta) ────────────────────────

class _CreatorConversationTile extends StatelessWidget {
  final String creatorUid;
  final String subscriberUid;
  final Map<String, dynamic>? conversationMeta;

  const _CreatorConversationTile({
    required this.creatorUid,
    required this.subscriberUid,
    required this.conversationMeta,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversationMeta?['lastMessage'] as String? ?? 'No messages yet';
    final unreadCount = (conversationMeta?['unreadForCreator'] as int?) ?? 0;

    String? timeLabel;
    final lastAt = conversationMeta?['lastMessageAt'];
    if (lastAt != null) {
      try {
        timeLabel = conversationTimeLabel((lastAt as Timestamp).toDate());
      } catch (_) {}
    }

    return FutureBuilder<AppUser?>(
      future: FirestoreService().getUser(subscriberUid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? '...';
        final photoUrl = snap.data?.photoUrl;

        return _ConversationRow(
          name: name,
          photoUrl: photoUrl,
          lastMessage: lastMessage,
          timeLabel: timeLabel,
          unreadCount: unreadCount,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChatScreen(creatorUid: creatorUid, subscriberUid: subscriberUid),
          )),
        );
      },
    );
  }
}

// ─── Subscriber Conversation Tile (streams live meta) ────────────────────────

class _ConversationTile extends StatelessWidget {
  final Subscription subscription;
  final String currentUserUid;
  final bool currentUserIsCreator;

  const _ConversationTile({
    required this.subscription,
    required this.currentUserUid,
    required this.currentUserIsCreator,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = currentUserIsCreator
        ? subscription.subscriberUid
        : subscription.creatorUid;
    final convId = '${subscription.subscriberUid}_${subscription.creatorUid}';
    final unreadField = currentUserIsCreator ? 'unreadForCreator' : 'unreadForSubscriber';

    return FutureBuilder<AppUser?>(
      future: FirestoreService().getUser(otherUid),
      builder: (context, userSnap) {
        final name = userSnap.data?.displayName ?? '...';
        final photoUrl = userSnap.data?.photoUrl;

        return StreamBuilder<Map<String, dynamic>?>(
          stream: FirestoreService().streamConversationMeta(convId),
          builder: (context, convSnap) {
            final meta = convSnap.data;
            final lastMessage = meta?['lastMessage'] as String? ?? 'No messages yet';
            final unreadCount = (meta?[unreadField] as int?) ?? 0;
            final lastAt = meta?['lastMessageAt'];
            String? timeLabel;
            if (lastAt != null) {
              try {
                timeLabel = conversationTimeLabel((lastAt as dynamic).toDate() as DateTime);
              } catch (_) {}
            }

            return _ConversationRow(
              name: name,
              photoUrl: photoUrl,
              lastMessage: lastMessage,
              timeLabel: timeLabel,
              unreadCount: unreadCount,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  creatorUid: subscription.creatorUid,
                  subscriberUid: subscription.subscriberUid,
                ),
              )),
            );
          },
        );
      },
    );
  }
}

Widget _buildEmpty(BuildContext context, bool isCreator) {
  final theme = Theme.of(context);
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.messageCircle, size: 64, color: ClosrColors.emberSoft),
        const SizedBox(height: 16),
        Text('No discussions yet',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(
          isCreator
              ? 'Your subscribers will appear here'
              : 'Subscribe to a creator to start chatting',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
