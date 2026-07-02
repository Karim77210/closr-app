import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { creator, subscriber }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? photoUrl;
  final String username;
  final String bio;
  final int subscriptionPriceCents;
  final int subscriberLimit;
  final int subscriberCount;
  final int messageCharacterLimit;
  final int messageCooldownSeconds;
  final int maxMessagesPerDay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? stripeCustomerId;
  final String? stripePriceId;
  final String? stripeConnectAccountId;
  final bool stripeConnectOnboarded;
  final bool autoPayoutEnabled;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.username = '',
    this.bio = '',
    this.subscriptionPriceCents = 0,
    this.subscriberLimit = 0,
    this.subscriberCount = 0,
    this.messageCharacterLimit = 300,
    this.messageCooldownSeconds = 20,
    this.maxMessagesPerDay = 10,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.stripeCustomerId,
    this.stripeConnectAccountId,
    this.stripeConnectOnboarded = false,
    this.autoPayoutEnabled = false,
    this.stripePriceId,
  });

  /// Convert AppUser to Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last, // 'creator' or 'subscriber'
      'photoUrl': photoUrl,
      'username': username,
      'bio': bio,
      'subscriptionPriceCents': subscriptionPriceCents,
      'subscriberLimit': subscriberLimit,
      'subscriberCount': subscriberCount,
      'messageCharacterLimit': messageCharacterLimit,
      'messageCooldownSeconds': messageCooldownSeconds,
      'maxMessagesPerDay': maxMessagesPerDay,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      if (stripeCustomerId != null) 'stripeCustomerId': stripeCustomerId,
      if (stripePriceId != null) 'stripePriceId': stripePriceId,
      if (stripeConnectAccountId != null) 'stripeConnectAccountId': stripeConnectAccountId,
      'stripeConnectOnboarded': stripeConnectOnboarded,
      'autoPayoutEnabled': autoPayoutEnabled,
    };
  }

  /// Create AppUser from Firestore document
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      role: json['role'] == 'creator' ? UserRole.creator : UserRole.subscriber,
      photoUrl: json['photoUrl'] as String?,
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      subscriptionPriceCents: json['subscriptionPriceCents'] as int? ?? 0,
      subscriberLimit: json['subscriberLimit'] as int? ?? 0,
      subscriberCount: json['subscriberCount'] as int? ?? 0,
      messageCharacterLimit: json['messageCharacterLimit'] as int? ?? 300,
      messageCooldownSeconds: json['messageCooldownSeconds'] as int? ?? 20,
      maxMessagesPerDay: json['maxMessagesPerDay'] as int? ?? 10,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
      stripeCustomerId: json['stripeCustomerId'] as String?,
      stripePriceId: json['stripePriceId'] as String?,
      stripeConnectAccountId: json['stripeConnectAccountId'] as String?,
      stripeConnectOnboarded: json['stripeConnectOnboarded'] as bool? ?? false,
      autoPayoutEnabled: json['autoPayoutEnabled'] as bool? ?? false,
    );
  }

  /// Create a copy with modified fields
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    UserRole? role,
    String? photoUrl,
    String? username,
    String? bio,
    int? subscriptionPriceCents,
    int? subscriberLimit,
    int? subscriberCount,
    int? messageCharacterLimit,
    int? messageCooldownSeconds,
    int? maxMessagesPerDay,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? stripeCustomerId,
    String? stripePriceId,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      subscriptionPriceCents: subscriptionPriceCents ?? this.subscriptionPriceCents,
      subscriberLimit: subscriberLimit ?? this.subscriberLimit,
      subscriberCount: subscriberCount ?? this.subscriberCount,
      messageCharacterLimit: messageCharacterLimit ?? this.messageCharacterLimit,
      messageCooldownSeconds: messageCooldownSeconds ?? this.messageCooldownSeconds,
      maxMessagesPerDay: maxMessagesPerDay ?? this.maxMessagesPerDay,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      stripePriceId: stripePriceId ?? this.stripePriceId,
    );
  }

  @override
  String toString() => 'AppUser(uid: $uid, email: $email, role: ${role.name})';
}
