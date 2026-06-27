import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String senderRole; // 'creator' | 'subscriber'
  final String type;       // 'text' | 'image' | 'video'
  final String content;
  final String? mediaUrl;
  final DateTime timestamp;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.type,
    required this.content,
    this.mediaUrl,
    required this.timestamp,
  });

  bool get isMedia => type == 'image' || type == 'video';

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderRole': senderRole,
        'type': type,
        'content': content,
        'mediaUrl': mediaUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };

  factory Message.fromJson(String id, Map<String, dynamic> json) {
    return Message(
      id: id,
      senderId: json['senderId'] as String,
      senderRole: json['senderRole'] as String,
      type: json['type'] as String? ?? 'text',
      content: json['content'] as String? ?? '',
      mediaUrl: json['mediaUrl'] as String?,
      timestamp: json['timestamp'] == null
          ? DateTime.now()
          : (json['timestamp'] as Timestamp).toDate(),
    );
  }
}
