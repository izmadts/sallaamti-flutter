import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/wall_repository.dart';
import 'wall_media_viewer_screen.dart';

// A swipeable gallery for a post's full media set, same as an Instagram/
// Facebook carousel — one or more photos and/or videos with dot indicators.
// The caller only needs this when there's more than one item; a single
// photo/video keeps using the simpler existing rendering.
class WallMediaCarousel extends StatefulWidget {
  final List<WallMediaItem> media;
  const WallMediaCarousel({super.key, required this.media});

  @override
  State<WallMediaCarousel> createState() => _WallMediaCarouselState();
}

class _WallMediaCarouselState extends State<WallMediaCarousel> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openViewer(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WallMediaViewerScreen(media: widget.media, initialIndex: index),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.media.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) {
              final item = widget.media[index];
              return item.isVideo
                  ? _WallVideoPlayer(url: item.url, onExpand: () => _openViewer(context, index))
                  : _WallImage(url: item.url, onTap: () => _openViewer(context, index));
            },
          ),
        ),
        if (widget.media.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.media.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _page ? Colors.white : Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WallImage extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  const _WallImage({required this.url, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // BoxFit.cover inside this fixed-height box used to crop the top/bottom
    // off any photo that wasn't exactly this aspect ratio — the common case
    // for a portrait phone screenshot or tall graphic. contain shows the
    // whole image (letterboxed on a dark background, same treatment the
    // video player below already uses) instead of cutting content off.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: Image.network(
          url,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stack) => Container(color: Colors.grey.shade100),
        ),
      ),
    );
  }
}

class _WallVideoPlayer extends StatefulWidget {
  final String url;
  final VoidCallback onExpand;
  const _WallVideoPlayer({required this.url, required this.onExpand});

  @override
  State<_WallVideoPlayer> createState() => _WallVideoPlayerState();
}

class _WallVideoPlayerState extends State<_WallVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  // Without this, a video that fails to load (bad URL, unreachable host,
  // unsupported codec) left the page stuck on the loading spinner forever —
  // initialize() rejecting was never caught, so neither _initialized nor
  // any error state was ever set. From the member's side this looked
  // exactly like "the video doesn't play": a permanent spinner with no
  // feedback and nothing to retry.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (mounted) setState(() => _initialized = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  Future<void> _retry() async {
    setState(() {
      _failed = false;
      _initialized = false;
    });
    await _controller.dispose();
    _startLoading();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 36),
              const SizedBox(height: 8),
              const Text('Could not load this video', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              TextButton(onPressed: _retry, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.black87,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: _toggle,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!_controller.value.isPlaying)
              const Icon(Icons.play_circle_fill, color: Colors.white70, size: 56),
            Positioned(
              right: 8,
              top: 8,
              child: Material(
                color: Colors.black45,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  tooltip: 'Expand',
                  onPressed: widget.onExpand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
