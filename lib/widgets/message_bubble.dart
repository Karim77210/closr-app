import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const MessageBubble({Key? key, required this.message, required this.isMe}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          color: isMe ? Colors.blue[600] : Colors.grey[100],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (message.type) {
      case 'image':
        return _ImageMessage(url: message.mediaUrl!, isMe: isMe);
      case 'video':
        return _VideoMessage(url: message.mediaUrl!, isMe: isMe);
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.content,
            style: TextStyle(
              color: isMe ? Colors.white : Colors.black87,
              fontSize: 15,
            ),
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
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox(
          width: 200,
          height: 150,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 48),
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
                  child: VideoPlayer(_controller),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
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
