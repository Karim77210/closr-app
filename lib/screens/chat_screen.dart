import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/screens/media_viewer_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:closr_app/models/message_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/storage_service.dart';
import 'package:closr_app/widgets/circle_icon_button.dart';
import 'package:closr_app/widgets/closr_avatar.dart';
import 'package:closr_app/widgets/message_bubble.dart';
import 'package:closr_app/theme.dart';

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
  AppUser? _me;

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
    final me = _isCreator
        ? creator
        : await _firestoreService.getUser(_currentUserUid);
    if (!mounted) return;
    setState(() {
      _creator = creator;
      _otherUser = other;
      _me = me;
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

  Future<void> _pickAndPreviewMedia() async {
    final files = await _imagePicker.pickMultipleMedia();
    if (files.isEmpty || !mounted) return;

    const maxBytes = 250 * 1024 * 1024;
    for (final f in files) {
      if (await f.length() > maxBytes) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.name} is too large (max 250 MB)')),
        );
        return;
      }
    }

    final caption = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => _MultiMediaPreviewSheet(files: files),
    );
    if (caption == null || !mounted) return;

    setState(() => _isUploading = true);
    try {
      for (final file in files) {
        final type = _isVideo(file) ? 'video' : 'image';
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
      }
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  bool _isVideo(XFile file) {
    final ext = file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v'].contains(ext);
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) =>
          Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, size: 24),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            ClosrAvatar(
              photoUrl: _otherUser?.photoUrl?.isNotEmpty == true ? _otherUser!.photoUrl : null,
              initialSource: otherName,
              size: 40,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(otherName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.1)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ONLINE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: ClosrColors.green,
                          ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: ClosrColors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInput(),
        ],
      ),
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
                const Icon(LucideIcons.messageCircle, size: 48, color: ClosrColors.emberSoft),
                const SizedBox(height: 12),
                Text(
                  _isCreator ? 'Start the conversation' : 'Send your first message',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
            final isMe = msg.senderId == _currentUserUid;
            final sender = isMe ? _me : _otherUser;
            final showDate = index == 0 ||
                !_sameDay(messages[index - 1].timestamp, msg.timestamp);
            final showCaption = _shouldShowCaption(messages, index);

            return Column(
              children: [
                if (showDate) _DateSeparator(date: msg.timestamp),
                MessageBubble(
                  message: msg,
                  isMe: isMe,
                  showCaption: showCaption,
                  avatar: ClosrAvatar(
                    photoUrl: sender?.photoUrl?.isNotEmpty == true ? sender!.photoUrl : null,
                    initialSource: sender?.displayName ?? '?',
                    size: 24,
                  ),
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
    final canSend = _isCreator || _canSend();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isCreator && _creator != null) _buildSubscriberStatus(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_isCreator) ...[
                  CircleIconButton(
                    icon: LucideIcons.imagePlus,
                    shape: CircleIconButtonShape.squircle,
                    size: 42,
                    iconSize: 20,
                    onTap: _isUploading ? null : _pickAndPreviewMedia,
                  ),
                  const SizedBox(width: 8),
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
                      enabled: canSend,
                      decoration: InputDecoration(
                        hintText: _isCreator
                            ? 'Message…'
                            : _cooldownRemaining > 0
                                ? 'Wait ${_cooldownRemaining}s…'
                                : _messagesRemainingToday <= 0
                                    ? 'Daily limit reached'
                                    : 'Message…',
                        contentPadding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                        counterText: '',
                        // Ember send button embedded inside the field (Figma)
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: ClosrColors.ember),
                                  ),
                                )
                              : GestureDetector(
                                  onTap: canSend ? _sendText : null,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: canSend
                                          ? ClosrColors.ember
                                          : ClosrColors.ember.withAlpha(80),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.send,
                                        color: Colors.white, size: 16),
                                  ),
                                ),
                        ),
                        suffixIconConstraints:
                            const BoxConstraints(minWidth: 42, minHeight: 34),
                      ),
                    ),
                  ),
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
            const Icon(LucideIcons.timer, size: 14, color: ClosrColors.ember),
            const SizedBox(width: 4),
            const Text(
              'Wait',
              style: TextStyle(fontSize: 12, color: ClosrColors.ember),
            ),
            Text(
              ' ${_cooldownRemaining}s',
              style: const TextStyle(fontSize: 12, color: ClosrColors.ember),
            ),
            const SizedBox(width: 16),
          ],
          Icon(LucideIcons.messageCircle, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            '$_messagesRemainingToday / ${_creator!.maxMessagesPerDay} messages left today',
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Show caption only on the first media of a group with the same caption/sender
bool _shouldShowCaption(List<Message> messages, int i) {
  final msg = messages[i];
  if (!msg.isMedia || msg.content.isEmpty) return msg.content.isNotEmpty;
  if (i == 0) return true;
  final prev = messages[i - 1];
  return !(prev.senderId == msg.senderId && prev.content == msg.content && prev.isMedia);
}

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

  String _timeLabel(DateTime d) => DateFormat('h:mm a').format(d).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          '${_label.toUpperCase()} · ${_timeLabel(date)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ─── Multi-media preview sheet ───────────────────────────────────────────────

class _MultiMediaPreviewSheet extends StatefulWidget {
  final List<XFile> files;
  const _MultiMediaPreviewSheet({required this.files});

  @override
  State<_MultiMediaPreviewSheet> createState() => _MultiMediaPreviewSheetState();
}

class _MultiMediaPreviewSheetState extends State<_MultiMediaPreviewSheet> {
  final _captionController = TextEditingController();
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _send() => Navigator.of(context).pop(_captionController.text.trim());

  @override
  Widget build(BuildContext context) {
    final count = widget.files.length;
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
                  icon: const Icon(LucideIcons.x, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
                const Spacer(),
                Text(
                  count > 1 ? '${_currentPage + 1} / $count' : 'Preview',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Media PageView with arrows
          Flexible(
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) => _MediaPage(file: widget.files[i]),
                ),
                if (_currentPage > 0)
                  Positioned(
                    left: 8, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _pageController.previousPage(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                if (_currentPage < count - 1)
                  Positioned(
                    right: 8, top: 0, bottom: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 250), curve: Curves.easeInOut),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Dots indicator (only if multiple files)
          if (count > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _currentPage ? 10 : 6,
                  height: i == _currentPage ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == _currentPage ? Colors.white : Colors.white38,
                  ),
                )),
              ),
            ),

          // Caption + send
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
                        _send();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _captionController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: count > 1 ? 'Add a caption for all…' : 'Add a caption…',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: false,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey[700]!)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey[700]!)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: Colors.white54)),
                        contentPadding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
                        // Embedded ember send circle, same pattern as the chat input
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: GestureDetector(
                            onTap: _send,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: const BoxDecoration(
                                color: ClosrColors.ember,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.send, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                        suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 34),
                      ),
                    ),
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

// ─── Single media page (image or video) ──────────────────────────────────────

class _MediaPage extends StatefulWidget {
  final XFile file;
  const _MediaPage({required this.file});

  @override
  State<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends State<_MediaPage> {
  late Future<Uint8List> _bytesFuture;
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool get _isVideo {
    final ext = widget.file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v'].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.file.path))
        ..initialize().then((_) { if (mounted) setState(() => _videoInitialized = true); });
      _videoController!.addListener(() { if (mounted) setState(() {}); });
    } else {
      _bytesFuture = widget.file.readAsBytes();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) return _buildVideo();
    return FutureBuilder<Uint8List>(
      future: _bytesFuture,
      builder: (_, snap) => snap.hasData
          ? InteractiveViewer(child: Center(child: Image.memory(snap.data!, fit: BoxFit.contain)))
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }

  Widget _buildVideo() {
    final ctrl = _videoController;
    if (ctrl == null || !_videoInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => ctrl.value.isPlaying ? ctrl.pause() : ctrl.play()),
      child: Stack(alignment: Alignment.center, children: [
        Center(child: AspectRatio(aspectRatio: ctrl.value.aspectRatio, child: IgnorePointer(child: VideoPlayer(ctrl)))),
        AnimatedOpacity(
          opacity: ctrl.value.isPlaying ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.black.withAlpha(140), shape: BoxShape.circle),
            child: const Icon(LucideIcons.play, color: Colors.white, size: 40),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: VideoProgressIndicator(ctrl, allowScrubbing: true,
          colors: VideoProgressColors(playedColor: Colors.white, bufferedColor: Colors.white38, backgroundColor: Colors.white12))),
      ]),
    );
  }
}
