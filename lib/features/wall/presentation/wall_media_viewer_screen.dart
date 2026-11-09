import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/wall_repository.dart';

// Full-screen, swipeable, pinch-to-zoom view of a post's media — what
// tapping a photo (or the expand button on a video) in the feed opens.
// InteractiveViewer is Flutter's own built-in pinch/pan/double-tap-zoom
// widget, so this needs no extra image-viewer package.
class WallMediaViewerScreen extends StatefulWidget {
  final List<WallMediaItem> media;
  final int initialIndex;
  const WallMediaViewerScreen({super.key, required this.media, this.initialIndex = 0});

  @override
  State<WallMediaViewerScreen> createState() => _WallMediaViewerScreenState();
}

class _WallMediaViewerScreenState extends State<WallMediaViewerScreen> {
  late final _pageController = PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.media.length > 1 ? Text('${_page + 1} / ${widget.media.length}') : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        onPageChanged: (index) => setState(() => _page = index),
        itemBuilder: (context, index) {
          final item = widget.media[index];
          return item.isVideo ? _FullscreenVideo(url: item.url) : _ZoomableImage(url: item.url);
        },
      ),
    );
  }
}

class _ZoomableImage extends StatelessWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 5,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
          loadingBuilder: (context, child, progress) =>
              progress == null ? child : const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}

class _FullscreenVideo extends StatefulWidget {
  final String url;
  const _FullscreenVideo({required this.url});

  @override
  State<_FullscreenVideo> createState() => _FullscreenVideoState();
}

class _FullscreenVideoState extends State<_FullscreenVideo> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
      _controller.play();
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() => setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(child: Icon(Icons.error_outline, color: Colors.white38, size: 48));
    }

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return GestureDetector(
      onTap: _toggle,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)),
            if (!_controller.value.isPlaying) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 64),
          ],
        ),
      ),
    );
  }
}
