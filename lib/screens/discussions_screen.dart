import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/subscription_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/screens/broadcast_screen.dart';
import 'package:closr_app/screens/chat_screen.dart';
import 'package:closr_app/theme.dart';
import 'package:intl/intl.dart';

class DiscussionsScreen extends StatelessWidget {
  final AppUser user;

  const DiscussionsScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCreator = user.role == UserRole.creator;

    return Scaffold(
      floatingActionButton: isCreator
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BroadcastScreen(creator: user),
              )),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Broadcast'),
            )
          : null,
      body: isCreator
          ? _CreatorInbox(creator: user)
          : _SubscriberInbox(subscriber: user),
    );
  }
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
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
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
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
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
    final convId = '${subscriberUid}_$creatorUid';
    final lastMessage = conversationMeta?['lastMessage'] as String? ?? 'No messages yet';
    final unreadCount = (conversationMeta?['unreadForCreator'] as int?) ?? 0;
    final hasUnread = unreadCount > 0;

    String? timeLabel;
    final lastAt = conversationMeta?['lastMessageAt'];
    if (lastAt != null) {
      try {
        final dt = (lastAt as Timestamp).toDate();
        final now = DateTime.now();
        timeLabel = now.difference(dt).inHours < 24
            ? DateFormat('HH:mm').format(dt)
            : DateFormat('dd/MM').format(dt);
      } catch (_) {}
    }

    return FutureBuilder<AppUser?>(
      future: FirestoreService().getUser(subscriberUid),
      builder: (context, snap) {
        final name = snap.data?.displayName ?? '...';
        final photoUrl = snap.data?.photoUrl;

        final scheme = Theme.of(context).colorScheme;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: ClosrColors.emberSoft,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) as ImageProvider : null,
            child: photoUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: ClosrColors.ink, fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(name,
              style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600)),
          subtitle: Text(
            lastMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasUnread ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
              fontSize: 13,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (timeLabel != null)
                Text(timeLabel,
                    style: TextStyle(
                      color: hasUnread ? ClosrColors.ember : scheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    )),
              if (hasUnread) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClosrColors.ember, borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(color: ClosrColors.paper, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
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
            final hasUnread = unreadCount > 0;
            final lastAt = meta?['lastMessageAt'];
            String? timeLabel;
            if (lastAt != null) {
              try {
                final dt = (lastAt as dynamic).toDate() as DateTime;
                final now = DateTime.now();
                timeLabel = now.difference(dt).inHours < 24
                    ? DateFormat('HH:mm').format(dt)
                    : DateFormat('dd/MM').format(dt);
              } catch (_) {}
            }

            final scheme = Theme.of(context).colorScheme;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: ClosrColors.emberSoft,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) as ImageProvider : null,
                child: photoUrl == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: ClosrColors.ink, fontWeight: FontWeight.bold))
                    : null,
              ),
              title: Text(name,
                  style: TextStyle(fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasUnread ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeLabel != null)
                    Text(timeLabel,
                        style: TextStyle(
                          color: hasUnread ? ClosrColors.ember : scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        )),
                  if (hasUnread) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ClosrColors.ember, borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(color: ClosrColors.paper, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
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
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.chat_outlined, size: 64, color: ClosrColors.emberSoft),
        const SizedBox(height: 16),
        Text('No discussions yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(
          isCreator ? 'Your subscribers will appear here' : 'Subscribe to a creator to start chatting',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    ),
  );
}
