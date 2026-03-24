import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';


class VideoPlayerControls extends StatefulWidget {
  final YoutubePlayerController? youtubeController;
  final VideoPlayerController? videoController;
  final bool isYoutube;
  final VoidCallback? onToggleFullScreen;
  final Lesson? lesson;
  final String courseTitle;

  const VideoPlayerControls({
    super.key,
    this.youtubeController,
    this.videoController,
    required this.isYoutube,
    this.onToggleFullScreen,
    this.lesson,
    this.courseTitle = '',
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
    _hideTimer = Timer(Duration(seconds: 3), () {
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
      final controller = widget.youtubeController;
      if (controller == null) return;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    } else {
      final controller = widget.videoController;
      if (controller == null) return;
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    }
    setState(() {});
    _startHideTimer();
  }

  void _seekRelative(int seconds) {
    if (widget.isYoutube) {
      final controller = widget.youtubeController;
      if (controller == null) return;
      final current = controller.value.position;
      controller.seekTo(current + Duration(seconds: seconds));
    } else {
      final controller = widget.videoController;
      if (controller == null) return;
      final current = controller.value.position;
      controller.seekTo(current + Duration(seconds: seconds));
    }
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    if (widget.isYoutube) {
      // YouTube player speed can be limited by the plugin, but we try
    } else {
      if (widget.videoController != null) {
        widget.videoController!.setPlaybackSpeed(speed);
      }
    }
    Navigator.pop(context);
    _startHideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFullScreen = widget.isYoutube
        ? (widget.youtubeController?.value.isFullScreen ?? false)
        : false; // For VideoPlayer, it's usually managed by the parent or orientation

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
              duration: Duration(milliseconds: 300),
              child: Container(color: Colors.black45),
            ),

            if (_isVisible)
              SafeArea(
                child: Stack(
                  children: [
                    // Top Bar
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: Icon(_isLocked ? Icons.lock : Icons.lock_open,
                                  color: AppColors.getTextColor(context)),
                              onPressed: () {
                                setState(() {
                                  _isLocked = !_isLocked;
                                  if (!_isLocked) _startHideTimer();
                                });
                              },
                            ),
                            if (!_isLocked) ...[
                              Spacer(),
                              _buildSpeedButton(),
                            ],

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
                            _buildControlButton(
                                Icons.replay_10, () => _seekRelative(-10)),
                            SizedBox(width: 40),
                            _buildPlayPauseButton(),
                            SizedBox(width: 40),
                            _buildControlButton(
                                Icons.forward_10, () => _seekRelative(10)),
                          ],
                        ),
                      ),

                    // Bottom Progress Bar
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black54, Colors.transparent],
                          ),
                        ),
                        child: _buildControlBar(isFullScreen),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(bool isFullScreen) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: widget.isYoutube
                ? (widget.youtubeController != null
                    ? ProgressBar(
                        controller: widget.youtubeController!,
                        colors: ProgressBarColors(
                          playedColor: AppColors.primaryPurple,
                          handleColor: AppColors.primaryPurple,
                        ),
                      )
                    : SizedBox.shrink())
                : (widget.videoController != null
                    ? VideoProgressIndicator(widget.videoController!,
                        allowScrubbing: true,
                        colors: VideoProgressColors(
                          playedColor: AppColors.primaryPurple,
                        ))
                    : SizedBox.shrink()),
          ),
          if (widget.onToggleFullScreen != null)
            IconButton(
              icon: Icon(
                isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                color: AppColors.getTextColor(context),
              ),
              onPressed: () {
                widget.onToggleFullScreen!();
                _startHideTimer();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, color: AppColors.getTextColor(context), size: 36),
      onPressed: onTap,
    );
  }

  Widget _buildPlayPauseButton() {
    final bool isPlaying = widget.isYoutube
        ? (widget.youtubeController?.value.isPlaying ?? false)
        : (widget.videoController?.value.isPlaying ?? false);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getMutedTextColor(context),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: AppColors.getTextColor(context),
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
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.getTextColor(context).withOpacity(0.24),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showSpeedMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'سرعة التشغيل',
                style: TextStyle(color: AppColors.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
              title: Text('${speed}x', style: TextStyle(color: AppColors.getTextColor(context))),
              trailing: _playbackSpeed == speed 
                ? Icon(Icons.check, color: AppColors.primaryBlue) 
                : null,
              onTap: () => _changeSpeed(speed),
            )),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
