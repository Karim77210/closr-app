import 'package:flutter/material.dart';
import 'package:closr_app/models/subscription_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/screens/chat_screen.dart';
import 'package:intl/intl.dart';

class DiscussionsScreen extends StatelessWidget {
  final AppUser user;

  const DiscussionsScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isCreator = user.role == UserRole.creator;
    final stream = isCreator
        ? FirestoreService().streamCreatorConversations(user.uid)
        : FirestoreService().streamSubscriberConversations(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('closr'),
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<List<Subscription>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final subscriptions = snapshot.data ?? [];

          if (subscriptions.isEmpty) {
            return _buildEmpty(context, isCreator);
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: subscriptions.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final sub = subscriptions[index];
              return _ConversationTile(
                subscription: sub,
                currentUserIsCreator: isCreator,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, bool isCreator) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No discussions yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isCreator ? 'Your subscribers will appear here' : 'Subscribe to a creator to start chatting',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Subscription subscription;
  final bool currentUserIsCreator;

  const _ConversationTile({
    required this.subscription,
    required this.currentUserIsCreator,
  });

  @override
  Widget build(BuildContext context) {
    final otherUid = currentUserIsCreator
        ? subscription.subscriberUid
        : subscription.creatorUid;

    final convId = '${subscription.subscriberUid}_${subscription.creatorUid}';

    return FutureBuilder<AppUser?>(
      future: FirestoreService().getUser(otherUid),
      builder: (context, userSnap) {
        final otherUser = userSnap.data;
        final name = otherUser?.displayName ?? '...';
        final photoUrl = otherUser?.photoUrl;

        return FutureBuilder<Map<String, dynamic>?>(
          future: FirestoreService().getConversationMeta(convId),
          builder: (context, convSnap) {
            final meta = convSnap.data;
            final lastMessage = meta?['lastMessage'] as String? ?? 'No messages yet';
            final lastAt = meta?['lastMessageAt'];
            String? timeLabel;
            if (lastAt != null) {
              try {
                final dt = (lastAt as dynamic).toDate() as DateTime;
                final now = DateTime.now();
                if (now.difference(dt).inHours < 24) {
                  timeLabel = DateFormat('HH:mm').format(dt);
                } else {
                  timeLabel = DateFormat('dd/MM').format(dt);
                }
              } catch (_) {}
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.blue[100],
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) as ImageProvider : null,
                child: photoUrl == null
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      )
                    : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              trailing: timeLabel != null
                  ? Text(timeLabel, style: TextStyle(color: Colors.grey[500], fontSize: 12))
                  : null,
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
