import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/message_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/storage_service.dart';
import 'package:closr_app/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String creatorUid;
  final String subscriberUid;

  const ChatScreen({
    Key? key,
    required this.creatorUid,
    required this.subscriberUid,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  late final String _currentUserUid;
  late final bool _isCreator;
  late final String _conversationId;

  AppUser? _creator;
  AppUser? _otherUser;

  int _messagesRemainingToday = 0;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    _isCreator = _currentUserUid == widget.creatorUid;
    _conversationId = _firestoreService.conversationId(
        widget.subscriberUid, widget.creatorUid);
    _loadProfiles();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final creator = await _firestoreService.getUser(widget.creatorUid);
    final other = await _firestoreService.getUser(
        _isCreator ? widget.subscriberUid : widget.creatorUid);
    if (!mounted) return;
    setState(() {
      _creator = creator;
      _otherUser = other;
    });
    if (!_isCreator && creator != null) await _loadSubscriberLimits(creator);
  }

  Future<void> _loadSubscriberLimits(AppUser creator) async {
    final count = await _firestoreService.getTodayMessageCount(
        _conversationId, widget.subscriberUid);
    final lastTime = await _firestoreService.getLastMessageTime(
        _conversationId, widget.subscriberUid);

    if (!mounted) return;
    setState(() {
      _messagesRemainingToday =
          (creator.maxMessagesPerDay - count).clamp(0, creator.maxMessagesPerDay);
    });

    if (lastTime != null) {
      final elapsed = DateTime.now().difference(lastTime).inSeconds;
      final remaining = creator.messageCooldownSeconds - elapsed;
      if (remaining > 0) _startCooldown(remaining);
    }
  }

  void _startCooldown(int seconds) {
    _cooldownRemaining = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldownRemaining <= 0) {
        t.cancel();
        if (mounted) setState(() => _cooldownRemaining = 0);
      } else {
        if (mounted) setState(() => _cooldownRemaining--);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    if (!_isCreator && !_canSend()) return;

    final message = Message(
      id: '',
      senderId: _currentUserUid,
      senderRole: _isCreator ? 'creator' : 'subscriber',
      type: 'text',
      content: text,
      timestamp: DateTime.now(),
    );

    _textController.clear();
    await _firestoreService.sendMessage(
      _conversationId, message,
      subscriberUid: widget.subscriberUid,
      creatorUid: widget.creatorUid,
    );

    if (!_isCreator && _creator != null) {
      _startCooldown(_creator!.messageCooldownSeconds);
      setState(() => _messagesRemainingToday =
          (_messagesRemainingToday - 1).clamp(0, _creator!.maxMessagesPerDay));
    }
  }

  Future<void> _sendMedia(String type) async {
    XFile? file;
    if (type == 'image') {
      file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    } else {
      file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    }
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final url = await _storageService.uploadChatMedia(_conversationId, file);
      final message = Message(
        id: '',
        senderId: _currentUserUid,
        senderRole: 'creator',
        type: type,
        content: '',
        mediaUrl: url,
        timestamp: DateTime.now(),
      );
      await _firestoreService.sendMessage(
        _conversationId, message,
        subscriberUid: widget.subscriberUid,
        creatorUid: widget.creatorUid,
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  bool _canSend() {
    if (_creator == null) return false;
    if (_messagesRemainingToday <= 0) return false;
    if (_cooldownRemaining > 0) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final otherName = _otherUser?.displayName ?? '...';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue[100],
              backgroundImage: _otherUser?.photoUrl != null
                  ? NetworkImage(_otherUser!.photoUrl!) as ImageProvider
                  : null,
              child: _otherUser?.photoUrl == null
                  ? Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(otherName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return StreamBuilder<List<Message>>(
      stream: _firestoreService.streamMessages(_conversationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                  _isCreator ? 'Start the conversation' : 'Send your first message',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return MessageBubble(
              message: msg,
              isMe: msg.senderId == _currentUserUid,
            );
          },
        );
      },
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isCreator && _creator != null) _buildSubscriberStatus(),
            Row(
              children: [
                if (_isCreator) ...[
                  _MediaButton(
                    icon: Icons.image_outlined,
                    onTap: _isUploading ? null : () => _sendMedia('image'),
                  ),
                  _MediaButton(
                    icon: Icons.videocam_outlined,
                    onTap: _isUploading ? null : () => _sendMedia('video'),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: _isCreator ? null : _creator?.messageCharacterLimit,
                    maxLines: null,
                    enabled: _isCreator || _canSend(),
                    decoration: InputDecoration(
                      hintText: _isCreator
                          ? 'Message…'
                          : _cooldownRemaining > 0
                              ? 'Wait ${_cooldownRemaining}s…'
                              : _messagesRemainingToday <= 0
                                  ? 'Daily limit reached'
                                  : 'Message…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isUploading)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Colors.blue[600],
                    onPressed: (_isCreator || _canSend()) ? _sendText : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriberStatus() {
    if (_creator == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Row(
        children: [
          if (_cooldownRemaining > 0) ...[
            Icon(Icons.timer_outlined, size: 14, color: Colors.orange[700]),
            const SizedBox(width: 4),
            Text(
              'Cooldown : ${_cooldownRemaining}s',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
            const SizedBox(width: 16),
          ],
          Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '$_messagesRemainingToday / ${_creator!.maxMessagesPerDay} messages restants aujourd\'hui',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MediaButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      color: onTap != null ? Colors.grey[700] : Colors.grey[300],
      onPressed: onTap,
    );
  }
}
