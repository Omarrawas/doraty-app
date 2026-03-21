import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../models/tip.dart';
import '../../core/services/video_pool_manager.dart';
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
    _handlePrefetch(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePrefetch(int index) {
    // ELITE MODE: Prefetch next 2 tips
    for (int i = 1; i <= 2; i++) {
      final nextIndex = index + i;
      if (nextIndex < widget.tips.length) {
        final nextTip = widget.tips[nextIndex];
        final type = nextTip.videoUrl.contains('youtube.com') || 
                     nextTip.videoUrl.contains('youtu.be') ||
                     nextTip.videoUrl.contains('shorts')
            ? VideoType.youtube
            : VideoType.network;
        
        VideoPoolManager().prefetch(nextTip.id, nextTip.videoUrl, type);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
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
                _handlePrefetch(index);
              },
              itemBuilder: (context, index) {
                return TipPlayerItem(
                  tip: widget.tips[index],
                  isActive: _currentIndex == index,
                  isVisible: widget.isVisible,
                );
              },
            ),
            
            // Global Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
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
    
    if (widget.isActive && widget.isVisible) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    if (_isInitialized) return;

    final type = _isYouTube ? VideoType.youtube : VideoType.network;
    
    try {
      final controller = await VideoPoolManager().getController(
        widget.tip.id, 
        widget.tip.videoUrl, 
        type
      );

      if (!mounted) return;

      if (_isYouTube) {
        _youtubeController = controller as YoutubePlayerController;
        _extractedVideoId = YoutubePlayer.convertUrlToId(widget.tip.videoUrl);
      } else {
        _videoController = controller as VideoPlayerController;
      }

      if (widget.isActive && widget.isVisible && mounted) {
        _isYouTube ? _youtubeController?.play() : _videoController?.play();
      }

      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error pooling video: $e');
      if (mounted) setState(() => _hasLoadError = true);
    }
  }

  @override
  void didUpdateWidget(TipPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldBeActive = widget.isActive && widget.isVisible;
    final bool wasActive = oldWidget.isActive && oldWidget.isVisible;

    if (shouldBeActive && !wasActive) {
      if (!_isInitialized) {
        _initializePlayer();
      } else {
        _isYouTube ? _youtubeController?.play() : _videoController?.play();
      }
    } else if (!shouldBeActive && wasActive) {
      _videoController?.pause();
      _youtubeController?.pause();
    }
  }

  @override
  void dispose() {
    // Controllers are managed by Pool, we only nullify refs
    _videoController = null;
    _youtubeController = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double playerWidth = (screenHeight * 9 / 16) > screenWidth ? screenWidth : (screenHeight * 9 / 16);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        if (widget.tip.effectiveThumbnailUrl != null)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.network(widget.tip.effectiveThumbnailUrl!, fit: BoxFit.cover),
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

        // Player
        Center(
          child: SizedBox(
            width: playerWidth,
            height: screenHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_isInitialized)
                  GestureDetector(
                    onTap: () {
                      if (_isYouTube) {
                        _youtubeController?.value.isPlaying ?? false ? _youtubeController?.pause() : _youtubeController?.play();
                      } else {
                        _videoController?.value.isPlaying ?? false ? _videoController?.pause() : _videoController?.play();
                        setState(() {});
                      }
                    },
                    child: _isYouTube 
                      ? (kIsWeb || defaultTargetPlatform == TargetPlatform.windows
                          ? YoutubePlayerWebWindows(videoId: _extractedVideoId ?? '', height: screenHeight)
                          : YoutubePlayer(controller: _youtubeController!))
                      : Center(
                          child: AspectRatio(
                            aspectRatio: _videoController?.value.aspectRatio ?? 9/16,
                            child: VideoPlayer(_videoController!),
                          ),
                        ),
                  )
                else if (!_hasLoadError)
                  const Center(child: CircularProgressIndicator(color: Colors.white)),

                if (_hasLoadError)
                  const Center(child: Text('Error loading video', style: TextStyle(color: Colors.white))),

                // Info Overlay
                Positioned(
                  bottom: 40,
                  left: 16,
                  right: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tip.title,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      ),
                      if (widget.tip.linkedCourse != null) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _showCoursePreview(),
                          icon: const Icon(Icons.school, size: 18),
                          label: const Text('استكشاف الدورة', style: TextStyle(fontFamily: 'Cairo')),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple),
                        ),
                      ],
                    ],
                  ),
                ),

                // Side Actions
                Positioned(
                  bottom: 120,
                  right: 12,
                  child: Column(
                    children: [
                      _buildAction(Icons.share, 'مشاركة', () {}),
                      const SizedBox(height: 20),
                      _buildAction(
                        _videoController?.value.volume == 0 ? Icons.volume_off : Icons.volume_up, 
                        'صوت', 
                        _toggleMute
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _toggleMute() {
    if (_isYouTube) return;
    final newVol = (_videoController?.value.volume ?? 1.0) == 0 ? 1.0 : 0.0;
    _videoController?.setVolume(newVol);
    setState(() {});
  }

  void _showCoursePreview() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => CoursePreviewModal(course: widget.tip.linkedCourse!),
    );
  }

  Widget _buildAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

}
