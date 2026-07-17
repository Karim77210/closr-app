import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/models/message_model.dart';

class MediaViewerScreen extends StatefulWidget {
  final List<Message> messages;
  final int initialIndex;

  const MediaViewerScreen({
    Key? key,
    required this.messages,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.messages.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.messages.length}',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: Listener(
        // Mouse wheel → navigate pages on web
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (event.scrollDelta.dy > 0) {
              _goTo(_currentIndex + 1);
            } else {
              _goTo(_currentIndex - 1);
            }
          }
        },
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: widget.messages.length,
          onPageChanged: (i) => setState(() => _currentIndex = i),
          itemBuilder: (context, index) {
            final msg = widget.messages[index];
            return msg.type == 'video'
                ? _VideoPage(message: msg, isActive: index == _currentIndex)
                : _ImagePage(message: msg);
          },
        ),
      ),
    );
  }
}

// ─── Image page ──────────────────────────────────────────────────────────────

class _ImagePage extends StatelessWidget {
  final Message message;
  const _ImagePage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Image.network(
            message.mediaUrl!,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Center(child: CircularProgressIndicator(color: Colors.white)),
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(LucideIcons.imageOff, color: Colors.white54, size: 64)),
          ),
        ),
        if (message.content.isNotEmpty)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(200), Colors.transparent],
                ),
              ),
              child: Text(
                message.content,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Video page ──────────────────────────────────────────────────────────────

class _VideoPage extends StatefulWidget {
  final Message message;
  final bool isActive;
  const _VideoPage({required this.message, required this.isActive});

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.message.mediaUrl!))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          if (widget.isActive) _controller.play();
        }
      });
    _controller.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _controller.play();
    } else if (!widget.isActive && old.isActive) {
      _controller.pause();
      _controller.seekTo(Duration.zero);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video — IgnorePointer so HTML element doesn't absorb taps
        if (_initialized)
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: IgnorePointer(child: VideoPlayer(_controller)),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Tap zone for play/pause — covers everything above the controls bar
        if (_initialized)
          Positioned(
            top: 0, left: 0, right: 0, bottom: 90,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _controller.value.isPlaying ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.play, color: Colors.white, size: 44),
                  ),
                ),
              ),
            ),
          ),

        // Bottom controls bar
        if (_initialized)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withAlpha(200), Colors.transparent],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message.content.isNotEmpty) ...[
                    Text(
                      widget.message.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                  ],
                  VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: Colors.white,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                  Row(
                    children: [
                      // Play/Pause button
                      IconButton(
                        icon: Icon(
                          _controller.value.isPlaying ? LucideIcons.pause : LucideIcons.play,
                          color: Colors.white,
                        ),
                        onPressed: _togglePlay,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      // Time
                      Text(
                        '${_fmt(_controller.value.position)} / ${_fmt(_controller.value.duration)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      // Volume
                      IconButton(
                        icon: Icon(
                          _controller.value.volume > 0 ? LucideIcons.volume2 : LucideIcons.volumeOff,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: () => setState(() {
                          _controller.setVolume(_controller.value.volume > 0 ? 0 : 1);
                        }),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
