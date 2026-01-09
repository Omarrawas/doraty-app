import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';

class VideoPlayerControls extends StatefulWidget {
  final YoutubePlayerController? youtubeController;
  final VideoPlayerController? videoController;
  final bool isYoutube;
  final VoidCallback? onToggleFullScreen;

  const VideoPlayerControls({
    super.key,
    this.youtubeController,
    this.videoController,
    required this.isYoutube,
    this.onToggleFullScreen,
  });

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _isVisible = true;
  bool _isLocked = false;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _startHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isVisible) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _toggleVisibility() {
    if (_isLocked) return;
    setState(() {
      _isVisible = !_isVisible;
      if (_isVisible) _startHideTimer();
    });
  }

  void _togglePlayPause() {
    if (widget.isYoutube) {
      if (widget.youtubeController!.value.isPlaying) {
        widget.youtubeController!.pause();
      } else {
        widget.youtubeController!.play();
      }
    } else {
      if (widget.videoController!.value.isPlaying) {
        widget.videoController!.pause();
      } else {
        widget.videoController!.play();
      }
    }
    setState(() {});
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (widget.isYoutube) {
      final current = widget.youtubeController!.value.position;
      widget.youtubeController!.seekTo(current + Duration(seconds: seconds));
    } else {
      final current = widget.videoController!.value.position;
      widget.videoController!.seekTo(current + Duration(seconds: seconds));
    }
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (widget.isYoutube) {
      // YouTube player speed can be limited by the plugin, but we try
    } else {
      widget.videoController!.setPlaybackSpeed(speed);
    }
    Navigator.pop(context);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleVisibility,
      onDoubleTapDown: (details) {
        if (_isLocked) return;
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          _seekRelative(-10);
        } else {
          _seekRelative(10);
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Black fading overlay
            AnimatedOpacity(
              opacity: _isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(color: Colors.black26),
            ),

            if (_isVisible) ...[
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isLocked ? Icons.lock : Icons.lock_open, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _isLocked = !_isLocked;
                            if (!_isLocked) _startHideTimer();
                          });
                        },
                      ),
                      const Spacer(),
                      _buildSpeedButton(),
                    ],
                  ),
                ),
              ),

              // Center Controls
              if (!_isLocked)
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(Icons.replay_10, () => _seekRelative(-10)),
                      const SizedBox(width: 40),
                      _buildPlayPauseButton(),
                      const SizedBox(width: 40),
                      _buildControlButton(Icons.forward_10, () => _seekRelative(10)),
                    ],
                  ),
                ),

              // Bottom Progress Bar (Custom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: _buildProgressBar(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 36),
      onPressed: onTap,
    );
  }

  Widget _buildPlayPauseButton() {
    final isPlaying = widget.isYoutube 
      ? widget.youtubeController!.value.isPlaying 
      : widget.videoController!.value.isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 48,
        ),
        onPressed: _togglePlayPause,
      ),
    );
  }

  Widget _buildSpeedButton() {
    return TextButton(
      onPressed: () => _showSpeedMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'سرعة التشغيل',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
              title: Text('${speed}x', style: const TextStyle(color: Colors.white)),
              trailing: _playbackSpeed == speed 
                ? const Icon(Icons.check, color: AppColors.primaryBlue) 
                : null,
              onTap: () => _changeSpeed(speed),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    // Note: Simple implementation, usually requires a stateful sync with player
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: widget.isYoutube 
              ? ProgressBar(controller: widget.youtubeController!, colors: const ProgressBarColors(
                  playedColor: AppColors.primaryPurple,
                  handleColor: AppColors.primaryPurple,
                ))
              : VideoProgressIndicator(widget.videoController!, allowScrubbing: true, colors: const VideoProgressColors(
                  playedColor: AppColors.primaryPurple,
                )),
          ),
          if (widget.onToggleFullScreen != null)
            IconButton(
              icon: const Icon(Icons.fullscreen, color: Colors.white),
              onPressed: widget.onToggleFullScreen,
            ),
        ],
      ),
    );
  }
}
