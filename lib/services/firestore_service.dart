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

    final preview = message.type == 'text' ? message.content : (message.type == 'image' ? '📷 Photo' : '🎬 Vidéo');
    final convRef = _db.collection(conversationsCollection).doc(convId);
    batch.set(convRef, {
      'subscriberUid': subscriberUid,
      'creatorUid': creatorUid,
      'lastMessage': preview,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessageType': message.type,
      'lastSenderId': message.senderId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Count today's messages sent by a specific user in a conversation
  Future<int> getTodayMessageCount(String convId, String senderUid) async {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final snapshot = await _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .get();
    return snapshot.docs.length;
  }

  /// Get timestamp of the last message sent by a user in a conversation
  Future<DateTime?> getLastMessageTime(String convId, String senderUid) async {
    final snapshot = await _db
        .collection(conversationsCollection)
        .doc(convId)
        .collection('messages')
        .where('senderId', isEqualTo: senderUid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final ts = snapshot.docs.first.data()['timestamp'] as Timestamp?;
    return ts?.toDate();
  }

  /// Get conversation metadata (last message preview)
  Future<Map<String, dynamic>?> getConversationMeta(String convId) async {
    final doc = await _db.collection(conversationsCollection).doc(convId).get();
    return doc.exists ? doc.data() : null;
  }
}
