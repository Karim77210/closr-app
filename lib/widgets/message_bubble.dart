import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/models/message_model.dart';
import 'package:closr_app/theme.dart';

/// Chat bubble (Figma conversation): outgoing = ember with white text,
/// incoming = white with shadow-xs. A 24px mini avatar sits at the outer
/// bottom corner of the bubble when [avatar] is provided.
class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showCaption;
  final VoidCallback? onMediaTap;
  final Widget? avatar;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isMe,
    this.showCaption = true,
    this.onMediaTap,
    this.avatar,
  }) : super(key: key);

  BorderRadius _bubbleRadius() {
    // Outgoing (isMe): (20,20,20,6) · Incoming: (20,20,6,20)
    return BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMe ? 20 : 6),
      bottomRight: Radius.circular(isMe ? 6 : 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final incomingColor = theme.colorScheme.surface;
    final radius = _bubbleRadius();

    final bubble = Container(
      decoration: BoxDecoration(
        color: isMe ? ClosrColors.ember : incomingColor,
        borderRadius: radius,
        boxShadow: !isMe && !isDark ? ClosrColors.shadowXs : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: _buildContent(context),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 64 : 12,
        right: isMe ? 12 : 64,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && avatar != null) ...[avatar!, const SizedBox(width: 6)],
          Flexible(child: bubble),
          if (isMe && avatar != null) ...[const SizedBox(width: 6), avatar!],
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;
    switch (message.type) {
      case 'image':
        return GestureDetector(
          onTap: onMediaTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImageMessage(url: message.mediaUrl!, isMe: isMe),
              if (showCaption && message.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Text(message.content,
                      style: TextStyle(color: textColor, fontSize: 14)),
                ),
            ],
          ),
        );
      case 'video':
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onMediaTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _VideoMessage(url: message.mediaUrl!, isMe: isMe),
              if (showCaption && message.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  child: Text(message.content,
                      style: TextStyle(color: textColor, fontSize: 14)),
                ),
            ],
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.content,
            style: TextStyle(color: textColor, fontSize: 14, height: 1.35),
          ),
        );
    }
  }
}

class _ImageMessage extends StatelessWidget {
  final String url;
  final bool isMe;

  const _ImageMessage({required this.url, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
      child: Image.network(
        url,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : const SizedBox(
                width: 200, height: 150,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
        errorBuilder: (_, __, ___) => const SizedBox(
          width: 80, height: 80,
          child: Center(child: Icon(LucideIcons.imageOff, size: 40, color: ClosrColors.muted)),
        ),
      ),
    );
  }
}

class _VideoMessage extends StatefulWidget {
  final String url;
  final bool isMe;

  const _VideoMessage({required this.url, required this.isMe});

  @override
  State<_VideoMessage> createState() => _VideoMessageState();
}

class _VideoMessageState extends State<_VideoMessage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 320),
      child: _initialized
          ? Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: IgnorePointer(child: VideoPlayer(_controller)),
                ),
                // Thumbnail overlay — tap handled by parent GestureDetector
                Container(
                  decoration: const BoxDecoration(
                    color: ClosrColors.ink,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: const Icon(LucideIcons.play, color: Colors.white, size: 32),
                ),
              ],
            )
          : const SizedBox(
              width: 200,
              height: 150,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
    );
  }
}
