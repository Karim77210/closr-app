import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/screens/media_viewer_screen.dart';
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
  late final Stream<List<Message>> _messagesStream;

  AppUser? _creator;
  AppUser? _otherUser;

  int _messagesRemainingToday = 0;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;
  bool _isUploading = false;
  bool _initialScrollDone = false;

  @override
  void initState() {
    super.initState();
    _currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    _isCreator = _currentUserUid == widget.creatorUid;
    _conversationId = _firestoreService.conversationId(
        widget.subscriberUid, widget.creatorUid);
    _messagesStream = _firestoreService.streamMessages(_conversationId);
    _loadProfiles();
    _firestoreService.resetUnreadCount(_conversationId, isCreator: _isCreator);
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
      // Initialize to max so UI doesn't flash "0 remaining" before count loads
      if (!_isCreator && creator != null) {
        _messagesRemainingToday = creator.maxMessagesPerDay;
      }
    });
    if (!_isCreator && creator != null) await _loadSubscriberLimits(creator);
  }

  Future<void> _loadSubscriberLimits(AppUser creator) async {
    try {
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
    } catch (_) {
      // If query fails (e.g. missing index), keep the max value
      if (mounted) setState(() => _messagesRemainingToday = creator.maxMessagesPerDay);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _pickAndPreviewMedia(String type) async {
    XFile? file;
    if (type == 'image') {
      file = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } else {
      file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    }
    if (file == null || !mounted) return;

    // Check file size (100 MB limit on web due to in-memory upload)
    final bytes = await file.length();
    const maxBytes = 250 * 1024 * 1024; // 250 MB
    if (bytes > maxBytes && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large. Maximum size is 250 MB.')),
      );
      return;
    }

    final caption = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _MediaPreviewSheet(file: file!, type: type),
    );

    if (caption == null) return; // dismissed

    setState(() => _isUploading = true);
    try {
      final url = await _storageService.uploadChatMedia(_conversationId, file);
      final message = Message(
        id: '',
        senderId: _currentUserUid,
        senderRole: 'creator',
        type: type,
        content: caption,
        mediaUrl: url,
        timestamp: DateTime.now(),
      );
      await _firestoreService.sendMessage(
        _conversationId, message,
        subscriberUid: widget.subscriberUid,
        creatorUid: widget.creatorUid,
      );
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
      stream: _messagesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];

        // Scroll to bottom on first load
        if (!_initialScrollDone && messages.isNotEmpty) {
          _initialScrollDone = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        }

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

        final mediaMessages = messages.where((m) => m.isMedia).toList();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final showDate = index == 0 ||
                !_sameDay(messages[index - 1].timestamp, msg.timestamp);

            return Column(
              children: [
                if (showDate) _DateSeparator(date: msg.timestamp),
                MessageBubble(
                  message: msg,
                  isMe: msg.senderId == _currentUserUid,
                  onMediaTap: msg.isMedia
                      ? () {
                          final mediaIndex = mediaMessages.indexOf(msg);
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => MediaViewerScreen(
                              messages: mediaMessages,
                              initialIndex: mediaIndex,
                            ),
                          ));
                        }
                      : null,
                ),
              ],
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
                    onTap: _isUploading ? null : () => _pickAndPreviewMedia('image'),
                  ),
                  _MediaButton(
                    icon: Icons.videocam_outlined,
                    onTap: _isUploading ? null : () => _pickAndPreviewMedia('video'),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _sendText();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
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
                    ),
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
              'Wait ${_cooldownRemaining}s',
              style: TextStyle(fontSize: 12, color: Colors.orange[700]),
            ),
            const SizedBox(width: 16),
          ],
          Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '$_messagesRemainingToday / ${_creator!.maxMessagesPerDay} messages left today',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day} ${_month(date.month)} ${date.year}';
  }

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey[300])),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label,
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey[300])),
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

class _MediaPreviewSheet extends StatefulWidget {
  final XFile file;
  final String type;

  const _MediaPreviewSheet({required this.file, required this.type});

  @override
  State<_MediaPreviewSheet> createState() => _MediaPreviewSheetState();
}

class _MediaPreviewSheetState extends State<_MediaPreviewSheet> {
  final _captionController = TextEditingController();
  late Future<Uint8List> _bytesFuture;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _bytesFuture = widget.file.readAsBytes();
    if (widget.type == 'video') {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.file.path))
        ..initialize().then((_) {
          if (mounted) setState(() => _videoInitialized = true);
        });
      _videoController!.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleVideoPlay() {
    if (_videoController == null) return;
    setState(() {
      _videoController!.value.isPlaying
          ? _videoController!.pause()
          : _videoController!.play();
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                const Spacer(),
                const Text(
                  'Preview',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Media preview
          Flexible(
            child: widget.type == 'image'
                ? FutureBuilder<Uint8List>(
                    future: _bytesFuture,
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      }
                      return InteractiveViewer(
                        child: Center(child: Image.memory(snap.data!, fit: BoxFit.contain)),
                      );
                    },
                  )
                : _buildVideoPreview(),
          ),

          // Caption input + send button
          Container(
            color: Colors.black,
            padding: EdgeInsets.only(
              left: 12, right: 8, top: 8,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Focus(
                    onKeyEvent: (_, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.enter &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        Navigator.of(context).pop(_captionController.text.trim());
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption…',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[700]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: Colors.white54),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                  ),
                  onPressed: () => Navigator.of(context).pop(_captionController.text.trim()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    final ctrl = _videoController;
    if (ctrl == null || !_videoInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      onTap: _toggleVideoPlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: ctrl.value.aspectRatio,
            child: VideoPlayer(ctrl),
          ),
          // Play/pause overlay
          AnimatedOpacity(
            opacity: ctrl.value.isPlaying ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(140),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          ),
          // Progress bar at bottom
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VideoProgressIndicator(
                  ctrl,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white12,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(ctrl.value.position),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const Spacer(),
                      Text(
                        _formatDuration(ctrl.value.duration),
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
