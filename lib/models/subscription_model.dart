import 'package:cloud_firestore/cloud_firestore.dart';

class Subscription {
  final String id;
  final String subscriberUid;
  final String creatorUid;
  final String stripeSubscriptionId;
  final String stripeCustomerId;
  final String stripePriceId;
  final String status;
  final DateTime currentPeriodEnd;
  final String type;
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.subscriberUid,
    required this.creatorUid,
    required this.stripeSubscriptionId,
    required this.stripeCustomerId,
    required this.stripePriceId,
    required this.status,
    required this.currentPeriodEnd,
    required this.type,
    required this.createdAt,
  });

  bool get isActive => status == 'active';

  factory Subscription.fromJson(String id, Map<String, dynamic> json) {
    return Subscription(
      id: id,
      subscriberUid: json['subscriberUid'] as String,
      creatorUid: json['creatorUid'] as String,
      stripeSubscriptionId: json['stripeSubscriptionId'] as String,
      stripeCustomerId: json['stripeCustomerId'] as String,
      stripePriceId: json['stripePriceId'] as String,
      status: json['status'] as String,
      currentPeriodEnd: (json['currentPeriodEnd'] as Timestamp).toDate(),
      type: json['type'] as String? ?? 'direct_message',
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
