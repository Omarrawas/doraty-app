import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/tip.dart';
import '../../core/theme/app_colors.dart';
import 'course_preview_modal.dart';
import 'lesson/youtube_player_web_windows.dart';

class VerticalTipPlayer extends StatefulWidget {
  final List<Tip> tips;
  final int initialIndex;
  final bool isVisible;

  const VerticalTipPlayer({
    super.key,
    required this.tips,
    this.initialIndex = 0,
    this.isVisible = true,
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
  void didUpdateWidget(VerticalTipPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the whole player visibility changed, we might need to trigger a rebuild
    // to let TipPlayerItems know.
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Stop any logic if needed
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
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
                  isVisible: widget.isVisible,
                );
              },
            ),
            
            // Single Global Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  ),
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TipPlayerItem extends StatefulWidget {
  final Tip tip;
  final bool isActive;
  final bool isVisible;

  const TipPlayerItem({
    super.key,
    required this.tip,
    required this.isActive,
    required this.isVisible,
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
          flags: YoutubePlayerFlags(
            autoPlay: widget.isActive && widget.isVisible,
            loop: true,
            mute: false,
            hideControls: true,
          ),
        );
      }
      if (mounted) {
        setState(() {
          _isInitialized = _isYouTube 
            ? (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || _youtubeController != null)
            : false;
        });
      }
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
      if (widget.isActive && widget.isVisible) {
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
    return Uri.encodeFull(url);
  }

  @override
  void didUpdateWidget(TipPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tip.videoUrl != widget.tip.videoUrl) {
      _videoController?.dispose();
      _youtubeController?.dispose();
      _videoController = null;
      _youtubeController = null;
      _isInitialized = false;
      _isYouTube = widget.tip.videoUrl.contains('youtube.com') || 
                   widget.tip.videoUrl.contains('youtu.be') ||
                   widget.tip.videoUrl.contains('shorts');
      _initializePlayer();
      return;
    }

    
    final bool currentlyShouldPlay = widget.isActive && widget.isVisible;
    final bool previouslyShouldPlay = oldWidget.isActive && oldWidget.isVisible;

    if (currentlyShouldPlay && !previouslyShouldPlay) {
      if (_isYouTube) {
        _youtubeController?.play();
      } else if (_videoController?.value.isInitialized == true) {
        _videoController?.play();
      }
    } else if (!currentlyShouldPlay && previouslyShouldPlay) {
      if (_isYouTube) {
        _youtubeController?.pause();
      } else if (_videoController?.value.isInitialized == true) {
        _videoController?.pause();
      }
    }
  }

  @override
  void deactivate() {
    _videoController?.pause();
    _youtubeController?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    // Calculate ideal width for a vertical video (9:16)
    final double idealWidth = screenHeight * 9 / 16;
    final double playerWidth = idealWidth > screenWidth ? screenWidth : idealWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred Background for Wide Screens
        if (widget.tip.effectiveThumbnailUrl != null)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(
                    widget.tip.effectiveThumbnailUrl!,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(color: Colors.black.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          )
        else
          Container(color: Colors.black),

        // 2. Centered Video & Interface (TikTok Style)
        Center(
          child: SizedBox(
            width: playerWidth,
            height: screenHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Video Player
                if (_isInitialized)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_isYouTube) {
                        if (_youtubeController != null) {
                          _youtubeController!.value.isPlaying ? _youtubeController!.pause() : _youtubeController!.play();
                        }
                      } else {
                        final controller = _videoController;
                        if (controller != null && controller.value.isInitialized) {
                          setState(() {
                            controller.value.isPlaying ? controller.pause() : controller.play();
                          });
                        }
                      }
                    },
                    child: _isYouTube 
                      ? (kIsWeb || defaultTargetPlatform == TargetPlatform.windows
                          ? YoutubePlayerWebWindows(
                              videoId: _extractedVideoId ?? '',
                              height: screenHeight,
                            )
                          : YoutubePlayer(
                              controller: _youtubeController ?? YoutubePlayerController(initialVideoId: ''),
                              showVideoProgressIndicator: true,
                              progressIndicatorColor: AppColors.primaryPurple,
                            ))
                      : Center(
                          child: AspectRatio(
                            aspectRatio: (_videoController?.value.aspectRatio ?? 0) > 0 
                              ? _videoController!.value.aspectRatio 
                              : 9 / 16,
                            child: _videoController != null 
                              ? VideoPlayer(_videoController!) 
                              : const SizedBox(),
                          ),
                        ),
                  )
                else if (!_isInitialized && (widget.tip.videoUrl.isNotEmpty) && !_hasLoadError)
                  const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),

                // Error State
                if (_hasLoadError || (widget.tip.videoUrl.isEmpty && !_isInitialized))
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.white70, size: 48),
                        SizedBox(height: 16),
                        Text('تعذر تشغيل الفيديو', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
                      ],
                    ),
                  ),

                // Interface Overlay (Inside playerWidth)
                
                // Top Close button removed from here, moved to parent VerticalTipPlayer

                // Side Buttons (TikTok Style)
                Positioned(
                  bottom: 120,
                  right: 12,
                  child: Column(
                    children: [
                      _buildSideAction(
                        icon: Icons.share,
                        label: 'مشاركة',
                        onTap: () {},
                      ),
                      const SizedBox(height: 24),
                      _buildSideAction(
                        icon: _isMuted() ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        label: _isMuted() ? 'تنشيط' : 'كتم',
                        onTap: _toggleMute,
                      ),
                      if (widget.tip.linkedCourse != null) ...[
                        const SizedBox(height: 24),
                        _buildSideAction(
                          icon: Icons.play_circle_fill_rounded,
                          label: 'الدورة',
                          onTap: () => _showCoursePreview(),
                          isFeatured: true,
                        ),
                      ],
                    ],
                  ),
                ),

                // Title & Info
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 80,
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
                          fontFamily: 'Cairo',
                        ),
                      ),
                      if (widget.tip.linkedCourse != null) ...[
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _showCoursePreview(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'استكشاف الدورة',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Play/Pause Center Indicator
                if (_isInitialized && !_isCurrentlyPlaying() && !_hasLoadError)
                  Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 80, color: Colors.white70),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  bool _isCurrentlyPlaying() {
    if (!_isInitialized) return false;
    if (_isYouTube) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        return widget.isActive && widget.isVisible;
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
    bool isFeatured = false,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(
                color: isFeatured ? AppColors.secondaryGold : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isFeatured ? AppColors.secondaryGold : Colors.white,
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            fontFamily: 'Cairo',
          ),
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
