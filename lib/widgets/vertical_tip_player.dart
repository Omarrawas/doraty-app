import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/tip.dart';
import '../../core/theme/app_colors.dart';
import 'course_preview_modal.dart';

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
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.tip.videoUrl));
    try {
      await _controller.initialize();
      _controller.setLooping(true);
      if (widget.isActive) {
        _controller.play();
      }
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void didUpdateWidget(TipPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.play();
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Player
        if (_isInitialized)
          GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              });
            },
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: Colors.white)),

        // Play/Pause Icon Overlay
        if (_isInitialized && !_controller.value.isPlaying)
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
                icon: _controller.value.volume == 0 ? Icons.volume_off : Icons.volume_up,
                label: 'كتم',
                onTap: () {
                  setState(() {
                    _controller.setVolume(_controller.value.volume == 0 ? 1.0 : 0.0);
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
