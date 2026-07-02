import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:closr_app/models/message_model.dart';
import 'package:closr_app/models/user_model.dart';
import 'package:closr_app/services/firestore_service.dart';
import 'package:closr_app/services/storage_service.dart';
import 'package:closr_app/theme.dart';

class BroadcastScreen extends StatefulWidget {
  final AppUser creator;

  const BroadcastScreen({Key? key, required this.creator}) : super(key: key);

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();
  final _textController = TextEditingController();

  List<XFile> _mediaFiles = [];
  int _previewIndex = 0;
  Uint8List? _firstPreviewBytes;
  VideoPlayerController? _firstVideoController;
  bool _firstVideoInitialized = false;

  bool _isSending = false;
  bool _isUploading = false;
  int _sentCount = 0;
  int _totalCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    _firstVideoController?.dispose();
    super.dispose();
  }

  bool _isVideoFile(XFile f) {
    final ext = f.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v'].contains(ext);
  }

  Future<void> _pickMedia() async {
    final files = await _imagePicker.pickMultipleMedia();
    if (files.isEmpty) return;

    _firstVideoController?.dispose();
    _firstVideoController = null;
    _firstVideoInitialized = false;

    setState(() {
      _mediaFiles = files;
      _previewIndex = 0;
      _firstPreviewBytes = null;
    });

    final first = files.first;
    if (!_isVideoFile(first)) {
      final bytes = await first.readAsBytes();
      if (mounted) setState(() => _firstPreviewBytes = bytes);
    } else {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(first.path))
        ..initialize().then((_) {
          if (mounted) setState(() => _firstVideoInitialized = true);
        });
      setState(() => _firstVideoController = ctrl);
    }
  }

  void _removeMedia() {
    _firstVideoController?.dispose();
    setState(() {
      _mediaFiles = [];
      _firstPreviewBytes = null;
      _firstVideoController = null;
      _firstVideoInitialized = false;
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _mediaFiles.isEmpty) return;

    setState(() { _isSending = true; _sentCount = 0; _totalCount = 0; });

    try {
      if (_mediaFiles.isEmpty) {
        // Text only
        final message = Message(id: '', senderId: widget.creator.uid, senderRole: 'creator',
            type: 'text', content: text, timestamp: DateTime.now());
        await _firestoreService.broadcastMessage(
          creatorUid: widget.creator.uid, message: message,
          onProgress: (sent, total) { if (mounted) setState(() { _sentCount = sent; _totalCount = total; }); },
        );
      } else {
        // Upload each file once, broadcast to all subscribers per file
        for (final file in _mediaFiles) {
          setState(() => _isUploading = true);
          final url = await _storageService.uploadChatMedia('broadcast_${widget.creator.uid}', file);
          setState(() => _isUploading = false);
          final type = _isVideoFile(file) ? 'video' : 'image';
          final message = Message(id: '', senderId: widget.creator.uid, senderRole: 'creator',
              type: type, content: text, mediaUrl: url, timestamp: DateTime.now());
          await _firestoreService.broadcastMessage(
            creatorUid: widget.creator.uid, message: message,
            onProgress: (sent, total) { if (mounted) setState(() { _sentCount = sent; _totalCount = total; }); },
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast sent to $_totalCount subscribers')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast'),
        elevation: 0,
        actions: [
          if (_isSending)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '$_sentCount / $_totalCount',
                style: const TextStyle(color: ClosrColors.ember, fontWeight: FontWeight.bold),
              ),
            )
          else
            TextButton(
              onPressed: (_textController.text.trim().isEmpty && _mediaFiles.isEmpty)
                  ? null
                  : _send,
              child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
        ],
      ),
      body: _isSending
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _isUploading
                        ? 'Uploading media…'
                        : 'Sending to $_sentCount / $_totalCount subscribers…',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Media preview
                if (_mediaFiles.isNotEmpty) _buildMediaPreview(),

                // Recipient badge
                Container(
                  width: double.infinity,
                  color: ClosrColors.emberSoft.withAlpha(90),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: const [
                      Icon(Icons.group_outlined, size: 18, color: ClosrColors.ember),
                      SizedBox(width: 8),
                      Text(
                        'All active subscribers',
                        style: TextStyle(color: ClosrColors.ember, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Text input
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
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
                        controller: _textController,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: 'Write a message to all your subscribers…',
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ),

                // Media buttons
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.perm_media_outlined),
                          color: ClosrColors.ember,
                          onPressed: _pickMedia,
                          tooltip: 'Add photos / videos',
                        ),
                        if (_mediaFiles.isNotEmpty)
                          Text(
                            '${_mediaFiles.length} file${_mediaFiles.length > 1 ? 's' : ''} selected',
                            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMediaPreview() {
    final count = _mediaFiles.length;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      color: Colors.black,
      child: Stack(
        children: [
          // Current file preview — key forces rebuild when index changes
          Center(child: _BroadcastMediaTile(key: ValueKey(_previewIndex), file: _mediaFiles[_previewIndex])),

          // Left arrow
          if (_previewIndex > 0)
            Positioned(
              left: 8, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _previewIndex--),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),

          // Right arrow
          if (_previewIndex < count - 1)
            Positioned(
              right: 8, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _previewIndex++),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),

          // Counter badge
          Positioned(
            top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Text('${_previewIndex + 1} / $count', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),

          // Close button
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: _removeMedia,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Broadcast media tile (loads preview per file) ────────────────────────────

class _BroadcastMediaTile extends StatefulWidget {
  final XFile file;
  _BroadcastMediaTile({super.key, required this.file});

  @override
  State<_BroadcastMediaTile> createState() => _BroadcastMediaTileState();
}

class _BroadcastMediaTileState extends State<_BroadcastMediaTile> {
  Uint8List? _bytes;
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;
  bool get _isVideo {
    final ext = widget.file.name.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'webm', 'mkv', 'm4v'].contains(ext);
  }

  @override
  void initState() {
    super.initState();
    if (_isVideo) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.file.path))
        ..initialize().then((_) { if (mounted) setState(() => _videoReady = true); });
    } else {
      widget.file.readAsBytes().then((b) { if (mounted) setState(() => _bytes = b); });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) {
      if (!_videoReady || _videoCtrl == null) return const CircularProgressIndicator(color: Colors.white);
      return GestureDetector(
        onTap: () => setState(() => _videoCtrl!.value.isPlaying ? _videoCtrl!.pause() : _videoCtrl!.play()),
        child: Stack(alignment: Alignment.center, children: [
          AspectRatio(aspectRatio: _videoCtrl!.value.aspectRatio, child: IgnorePointer(child: VideoPlayer(_videoCtrl!))),
          if (!_videoCtrl!.value.isPlaying)
            const Icon(Icons.play_arrow, color: Colors.white, size: 48),
        ]),
      );
    }
    if (_bytes == null) return const CircularProgressIndicator(color: Colors.white);
    return Image.memory(_bytes!, fit: BoxFit.contain);
  }
}
