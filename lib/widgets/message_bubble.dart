import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/models/message_model.dart';
import 'package:closr_app/theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool showCaption;
  final VoidCallback? onMediaTap;

  const MessageBubble({Key? key, required this.message, required this.isMe, this.showCaption = true, this.onMediaTap}) : super(key: key);

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
    // Incoming bubble surface: cream (light) / plum surface (dark)
    final incomingColor = isDark ? theme.colorScheme.surface : ClosrColors.cream;
    final radius = _bubbleRadius();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 64 : 12,
          right: isMe ? 12 : 64,
        ),
        decoration: BoxDecoration(
          color: isMe ? ClosrColors.ember : incomingColor,
          borderRadius: radius,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildContent(context),
              Padding(
                padding: const EdgeInsets.only(right: 10, bottom: 5, left: 10),
                child: Text(
                  DateFormat('HH:mm').format(message.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe
                        ? ClosrColors.paper.withAlpha(180)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isMe ? ClosrColors.paper : theme.colorScheme.onSurface;
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
            style: TextStyle(color: textColor, fontSize: 15),
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
        errorBuilder: (_, __, ___) => SizedBox(
          width: 80, height: 80,
          child: Center(child: Icon(Icons.broken_image, size: 40, color: ClosrColors.muted)),
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
                  child: const Icon(Icons.play_arrow, color: ClosrColors.paper, size: 36),
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
