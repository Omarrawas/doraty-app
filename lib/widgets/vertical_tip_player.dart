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

  @override
  void initState() {
    super.initState();
    _isYouTube = widget.tip.videoUrl.contains('youtube.com') || 
                 widget.tip.videoUrl.contains('youtu.be') ||
                 widget.tip.videoUrl.contains('shorts');
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (_isYouTube) {
      final videoId = YoutubePlayer.convertUrlToId(widget.tip.videoUrl);
      if (videoId != null) {
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              loop: true,
              mute: false,
              hideControls: true,
            ),
          );
          if (widget.isActive) {
            _youtubeController!.play();
          }
        }
        setState(() => _isInitialized = true);
        return;
      }
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
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      if (widget.isActive) {
        _videoController!.play();
      }
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video: $e');
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
                        videoId: YoutubePlayer.convertUrlToId(widget.tip.videoUrl) ?? '',
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
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Play/Pause Icon Overlay
        if (_isInitialized && !(_isYouTube ? _youtubeController!.value.isPlaying : _videoController!.value.isPlaying))
          const Center(
            child: Icon(Icons.play_arrow, size: 80, color: Colors.white54),
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
                          'عرض الدورة التدريبية',
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
                label: 'مشاركة',
                onTap: () {},
              ),
              const SizedBox(height: 20),
              _buildSideAction(
                icon: (_isYouTube ? (_youtubeController?.value.volume ?? 100) == 0 : (_videoController?.value.volume ?? 1.0) == 0) ? Icons.volume_off : Icons.volume_up,
                label: 'كتم',
                onTap: () {
                  setState(() {
                    if (_isYouTube) {
                      _youtubeController!.value.volume == 0 ? _youtubeController!.unMute() : _youtubeController!.mute();
                    } else {
                      _videoController!.setVolume(_videoController!.value.volume == 0 ? 1.0 : 0.0);
                    }
                  });
                },
              ),
              if (widget.tip.linkedCourse != null) ...[
                const SizedBox(height: 20),
                _buildSideAction(
                  icon: Icons.monitor,
                  label: 'الدورة',
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
