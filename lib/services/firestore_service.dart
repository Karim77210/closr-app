import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/models/subscription_model.dart';
import 'package:closr_app/models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String subscriptionsCollection = 'subscriptions';

  /// Create a new user document
  Future<void> createUser(AppUser user) async {
    try {
      await _db.collection(usersCollection).doc(user.uid).set(user.toJson());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  /// Get user by UID
  Future<AppUser?> getUser(String uid) async {
    try {
      final doc = await _db.collection(usersCollection).doc(uid).get();
      if (doc.exists) {
        return AppUser.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  /// Update user document
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _db.collection(usersCollection).doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  /// Stream user data (for real-time updates)
  Stream<AppUser?> streamUser(String uid) {
    return _db.collection(usersCollection).doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        return AppUser.fromJson(doc.data()!);
      }
      return null;
    });
  }

  /// Delete user document
  Future<void> deleteUser(String uid) async {
    try {
      await _db.collection(usersCollection).doc(uid).delete();
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }

  /// Get all creators (for discovery)
  Future<List<AppUser>> getCreators() async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .where('role', isEqualTo: 'creator')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs.map((doc) => AppUser.fromJson(doc.data())).toList();
    } catch (e) {
      throw Exception('Failed to get creators: $e');
    }
  }

  /// Find a creator by username
  Future<AppUser?> getCreatorByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .where('username', isEqualTo: username)
          .where('role', isEqualTo: 'creator')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return AppUser.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to find creator: $e');
    }
  }

  /// Find a user by username
  Future<AppUser?> getUserByUsername(String username) async {
    try {
      final snapshot = await _db
          .collection(usersCollection)
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      return AppUser.fromJson(snapshot.docs.first.data());
    } catch (e) {
      throw Exception('Failed to get user by username: $e');
    }
  }

  /// Check whether a username already exists, excluding a given UID
  Future<bool> usernameExists(String username, {String? excludeUid}) async {
    final existingUser = await getUserByUsername(username);
    if (existingUser == null) {
      return false;
    }
    if (excludeUid != null && existingUser.uid == excludeUid) {
      return false;
    }
    return true;
  }

  /// Stream creators for real-time discovery
  Stream<List<AppUser>> streamCreators() {
    return _db
        .collection(usersCollection)
        .where('role', isEqualTo: 'creator')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => AppUser.fromJson(doc.data())).toList();
    });
  }

  /// Stream active subscription between a subscriber and a creator
  Stream<Subscription?> streamSubscription(String subscriberUid, String creatorUid) {
    return _db
        .collection(subscriptionsCollection)
        .where('subscriberUid', isEqualTo: subscriberUid)
        .where('creatorUid', isEqualTo: creatorUid)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return Subscription.fromJson(snapshot.docs.first.id, snapshot.docs.first.data());
    });
  }

  /// Get all active subscriptions for a subscriber (for discussions list)
  Future<List<Subscription>> getActiveSubscriptions(String subscriberUid) async {
    try {
      final snapshot = await _db
          .collection(subscriptionsCollection)
          .where('subscriberUid', isEqualTo: subscriberUid)
          .where('status', isEqualTo: 'active')
          .get();
      return snapshot.docs
          .map((doc) => Subscription.fromJson(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get subscriptions: $e');
    }
  }

  /// Stream all active subscriptions for a subscriber
  Stream<List<Subscription>> streamSubscriberConversations(String subscriberUid) {
    return _db
        .collection(subscriptionsCollection)
        .where('subscriberUid', isEqualTo: subscriberUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map((d) => Subscription.fromJson(d.id, d.data())).toList());
  }

  /// Stream all active subscriptions for a creator
  Stream<List<Subscription>> streamCreatorConversations(String creatorUid) {
    return _db
        .collection(subscriptionsCollection)
        .where('creatorUid', isEqualTo: creatorUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((s) => s.docs.map((d) => Subscription.fromJson(d.id, d.data())).toList());
  }

  // ─── Messages ──────────────────────────────────────────────────────────────

  static const String conversationsCollection = 'conversations';

  String conversationId(String subscriberUid, String creatorUid) =>
      '${subscriberUid}_$creatorUid';

  /// Stream all messages in a conversation, oldest first
  Stream<List<Message>> streamMessages(String convId) {
    return _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((s) => s.docs.map((d) => Message.fromJson(d.id, d.data())).toList());
  }

  /// Send a message and update conversation metadata atomically
  Future<void> sendMessage(
    String convId,
    Message message, {
    required String subscriberUid,
    required String creatorUid,
  }) async {
    final batch = _db.batch();

    final msgRef = _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .doc();
    batch.set(msgRef, message.toJson());

    final preview = message.type == 'text' ? message.content : (message.type == 'image' ? '📷 Photo' : '🎬 Video');
    final convRef = _db.collection(conversationsCollection).doc(convId);
    final unreadField = message.senderRole == 'creator' ? 'unreadForSubscriber' : 'unreadForCreator';
    batch.set(convRef, {
      'subscriberUid': subscriberUid,
      'creatorUid': creatorUid,
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageType': message.type,
      'lastSenderId': message.senderId,
      'createdAt': FieldValue.serverTimestamp(),
      unreadField: FieldValue.increment(1),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Reset unread count when user opens a conversation
  Future<void> resetUnreadCount(String convId, {required bool isCreator}) async {
    final field = isCreator ? 'unreadForCreator' : 'unreadForSubscriber';
    await _db.collection(conversationsCollection).doc(convId).set(
      {field: 0},
      SetOptions(merge: true),
    );
  }

  /// Stream conversation metadata (live updates for unread badge)
  Stream<Map<String, dynamic>?> streamConversationMeta(String convId) {
    return _db
        .collection(conversationsCollection)
        .doc(convId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null);
  }

  /// Count messages sent by a user in the last 24 hours (no composite index needed)
  Future<int> getTodayMessageCount(String convId, String senderUid) async {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final snapshot = await _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .get();
    return snapshot.docs.where((doc) {
      final ts = doc.data()['timestamp'] as Timestamp?;
      return ts != null && ts.toDate().isAfter(cutoff);
    }).length;
  }

  /// Get timestamp of the last message sent by a user in a conversation
  Future<DateTime?> getLastMessageTime(String convId, String senderUid) async {
    final snapshot = await _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final times = snapshot.docs
        .map((d) => d.data()['timestamp'] as Timestamp?)
        .where((ts) => ts != null)
        .map((ts) => ts!.toDate())
        .toList()
      ..sort();
    return times.isEmpty ? null : times.last;
  }

  /// Get conversation metadata (last message preview)
  Future<Map<String, dynamic>?> getConversationMeta(String convId) async {
    final doc = await _db.collection(conversationsCollection).doc(convId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Stream creator conversations sorted by most recent activity (client-side sort)
  Stream<List<Map<String, dynamic>>> streamCreatorConversationsSorted(String creatorUid) {
    return _db
        .collection(conversationsCollection)
        .where('creatorUid', isEqualTo: creatorUid)
        .snapshots()
        .map((s) {
          final docs = s.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
          docs.sort((a, b) {
            final aTs = a['lastMessageAt'] as Timestamp?;
            final bTs = b['lastMessageAt'] as Timestamp?;
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return bTs.compareTo(aTs);
          });
          return docs;
        });
  }

  /// Send a broadcast message to all active subscribers
  Future<void> broadcastMessage({
    required String creatorUid,
    required Message message,
    void Function(int sent, int total)? onProgress,
  }) async {
    final subscSnapshot = await _db
        .collection(subscriptionsCollection)
        .where('creatorUid', isEqualTo: creatorUid)
        .where('status', isEqualTo: 'active')
        .get();

    final subs = subscSnapshot.docs;
    final total = subs.length;

    for (var i = 0; i < total; i++) {
      final data = subs[i].data();
      final subscriberUid = data['subscriberUid'] as String;
      final convId = conversationId(subscriberUid, creatorUid);
      await sendMessage(
        convId,
        message,
        subscriberUid: subscriberUid,
        creatorUid: creatorUid,
      );
      onProgress?.call(i + 1, total);
    }
  }
}
