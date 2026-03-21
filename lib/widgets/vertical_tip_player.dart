import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/tip.dart';
import '../../core/theme/app_colors.dart';
import 'course_preview_modal.dart';
import 'lesson/youtube_player_web_windows.dart';

class VerticalTipPlayer extends StatefulWidget {
  final List<Tip> tips;
  final int initialIndex;

  const VerticalTipPlayer({
    super.key,
    required this.tips,
    this.initialIndex = 0,
  });

  @override
  State<VerticalTipPlayer> createState() => _VerticalTipPlayerState();
}

class _VerticalTipPlayerState extends State<VerticalTipPlayer> {
  late PageController _pageController;
  int _currentIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.tips.length,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return TipPlayerItem(
            tip: widget.tips[index],
            isActive: _currentIndex == index,
          );
        },
      ),
    );
  }
}

class TipPlayerItem extends StatefulWidget {
  final Tip tip;
  final bool isActive;

  const TipPlayerItem({
    super.key,
    required this.tip,
    required this.isActive,
  });

  @override
  State<TipPlayerItem> createState() => _TipPlayerItemState();
}

class _TipPlayerItemState extends State<TipPlayerItem> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isInitialized = false;
  bool _isYouTube = false;
  String? _extractedVideoId;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _isYouTube = widget.tip.videoUrl.contains('youtube.com') || 
                 widget.tip.videoUrl.contains('youtu.be') ||
                 widget.tip.videoUrl.contains('shorts');
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    String? videoId = YoutubePlayer.convertUrlToId(widget.tip.videoUrl);
    
    // Manual fallback for Shorts or if library fails
    if (videoId == null && _isYouTube) {
      final regExp = RegExp(
        r'(?:youtube\.com\/shorts\/|youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
        caseSensitive: false,
      );
      final match = regExp.firstMatch(widget.tip.videoUrl);
      if (match != null && match.groupCount >= 1) {
        videoId = match.group(1);
      }
    }

    if (_isYouTube && videoId != null) {
      _extractedVideoId = videoId;
      if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            loop: true,
            mute: false,
            hideControls: true,
          ),
        );
      }
      if (mounted) setState(() => _isInitialized = true);
      return;
    }

    if (_isYouTube && videoId == null) {
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasLoadError = true;
        });
      }
      return;
    }

    final String sanitizedUrl = _sanitizeUrl(widget.tip.videoUrl);
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(sanitizedUrl),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': 'https://supabase.co',
      },
    );

    try {
      if (sanitizedUrl.isEmpty) throw 'Empty URL';
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (widget.isActive) {
        _videoController!.play();
      }
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          _hasLoadError = true;
        });
      }
    }
  }

  String _sanitizeUrl(String url) {
    if (url.isEmpty) return url;
    try {
      if (url.contains('%')) return url;
      final uri = Uri.parse(url);
      final encodedUri = uri.replace(
        path: _encodePath(uri.path),
        queryParameters: uri.queryParameters.isNotEmpty ? uri.queryParameters : null,
      );
      return encodedUri.toString();
    } catch (e) {
      return url.replaceAll(' ', '%20');
    }
  }

  String _encodePath(String path) {
    if (path.isEmpty) return path;
    return path.split('/').map((segment) => Uri.encodeComponent(segment)).join('/');
  }

  @override
  void didUpdateWidget(TipPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _isYouTube ? _youtubeController?.play() : _videoController?.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _isYouTube ? _youtubeController?.pause() : _videoController?.pause();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Thumbnail as placeholder
        if (widget.tip.effectiveThumbnailUrl != null)
          Positioned.fill(
            child: Image.network(
              widget.tip.effectiveThumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          )
        else
          Container(color: Colors.black),

        // Video Player
        if (_isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                if (_isYouTube) {
                  if (_youtubeController != null) {
                    _youtubeController!.value.isPlaying ? _youtubeController!.pause() : _youtubeController!.play();
                  }
                } else {
                  _videoController!.value.isPlaying ? _videoController!.pause() : _videoController!.play();
                }
              });
            },
            child: Center(
              child: _isYouTube 
                ? (kIsWeb || defaultTargetPlatform == TargetPlatform.windows
                    ? YoutubePlayerWebWindows(
                        videoId: _extractedVideoId ?? '',
                        height: MediaQuery.of(context).size.height,
                      )
                    : YoutubePlayer(
                        controller: _youtubeController!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: AppColors.primaryPurple,
                      ))
                : AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
            ),
          )
        else if (!_isInitialized && (widget.tip.videoUrl.isNotEmpty))
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Loading...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),

        // Error State
        if (!_isInitialized && widget.tip.videoUrl.isEmpty)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text('Video URL is unavailable', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),

        // Play/Pause Icon Overlay
        if (_isInitialized && !_isCurrentlyPlaying())
          const Center(
            child: Icon(Icons.play_arrow, size: 80, color: Colors.white54),
          ),

        if (_hasLoadError)
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white70, size: 48),
                SizedBox(height: 16),
                Text('تعذر تشغيل الفيديو', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),

        // Bottom Info & CTA
        Positioned(
          bottom: 40,
          left: 16,
          right: 80, // Leave room for side buttons
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tip.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                ),
              ),
              const SizedBox(height: 8),
              if (widget.tip.linkedCourse != null)
                GestureDetector(
                  onTap: () => _showCoursePreview(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'View course details',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Side Buttons (Share, Mute, Course)
        Positioned(
          bottom: 100,
          right: 16,
          child: Column(
            children: [
              _buildSideAction(
                icon: Icons.share,
                label: 'Share',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildSideAction(
                icon: _isMuted() ? Icons.volume_off : Icons.volume_up,
                label: 'Mute',
                onTap: _toggleMute,
              ),
              if (widget.tip.linkedCourse != null) ...[
                const SizedBox(height: 20),
                _buildSideAction(
                  icon: Icons.monitor,
                  label: 'Course',
                  onTap: () => _showCoursePreview(),
                  animate: true,
                ),
              ],
            ],
          ),
        ),

        // Top Back Button
        Positioned(
          top: 50,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }


  bool _isCurrentlyPlaying() {
    if (!_isInitialized) return false;
    if (_isYouTube) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        return true;
      }
      return _youtubeController?.value.isPlaying ?? false;
    }
    return _videoController?.value.isPlaying ?? false;
  }

  bool _isMuted() {
    if (_isYouTube) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        return false;
      }
      return (_youtubeController?.value.volume ?? 100) == 0;
    }
    return (_videoController?.value.volume ?? 1.0) == 0;
  }

  void _toggleMute() {
    setState(() {
      if (_isYouTube) {
        if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
          return;
        }
        if ((_youtubeController?.value.volume ?? 100) == 0) {
          _youtubeController?.unMute();
        } else {
          _youtubeController?.mute();
        }
      } else {
        final controller = _videoController;
        if (controller == null) return;
        controller.setVolume(controller.value.volume == 0 ? 1.0 : 0.0);
      }
    });
  }
  Widget _buildSideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool animate = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
              border: animate ? Border.all(color: AppColors.secondaryGold, width: 2) : null,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  void _showCoursePreview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CoursePreviewModal(course: widget.tip.linkedCourse!),
    );
  }
}
