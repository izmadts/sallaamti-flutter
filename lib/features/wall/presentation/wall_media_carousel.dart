import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../data/wall_repository.dart';

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
              return item.isVideo ? _WallVideoPlayer(url: item.url) : _WallImage(url: item.url);
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
  const _WallImage({required this.url});

  @override
  Widget build(BuildContext context) {
    // BoxFit.cover inside this fixed-height box used to crop the top/bottom
    // off any photo that wasn't exactly this aspect ratio — the common case
    // for a portrait phone screenshot or tall graphic. contain shows the
    // whole image (letterboxed on a dark background, same treatment the
    // video player below already uses) instead of cutting content off.
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: Image.network(
        url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => Container(color: Colors.grey.shade100),
      ),
    );
  }
}

class _WallVideoPlayer extends StatefulWidget {
  final String url;
  const _WallVideoPlayer({required this.url});

  @override
  State<_WallVideoPlayer> createState() => _WallVideoPlayerState();
}

class _WallVideoPlayerState extends State<_WallVideoPlayer> {
  late final VideoPlayerController _controller;
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

  void _toggle() {
    setState(() => _controller.value.isPlaying ? _controller.pause() : _controller.play());
  }

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
