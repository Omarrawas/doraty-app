import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../models/lesson.dart';
import '../../models/download.dart';
import '../../core/utils/error_utils.dart';

class VideoPlayerControls extends StatefulWidget {
  final YoutubePlayerController? youtubeController;
  final VideoPlayerController? videoController;
  final bool isYoutube;
  final VoidCallback? onToggleFullScreen;
  final Lesson lesson;
  final String courseTitle;

  const VideoPlayerControls({
    super.key,
    this.youtubeController,
    this.videoController,
    required this.isYoutube,
    this.onToggleFullScreen,
    required this.lesson,
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
                      _buildDownloadButton(),
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
    final bool isPlaying = widget.isYoutube
        ? (widget.youtubeController?.value.isPlaying ?? false)
        : (widget.videoController?.value.isPlaying ?? false);

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

  Widget _buildDownloadButton() {
    return AnimatedBuilder(
      animation: DownloadManager(),
      builder: (context, child) {
        final downloadManager = DownloadManager();
        final isDownloaded = downloadManager.isDownloaded(widget.lesson.id);

        // Check if currently downloading
        final activeDownload = downloadManager.activeDownloads.firstWhere(
          (d) => d.lessonId == widget.lesson.id,
          orElse: () => DownloadedLesson(
            id: '',
            lessonId: '',
            courseId: '',
            title: '',
            videoUrl: '',
            localPath: '',
            fileSize: 0,
            downloadedAt: DateTime.now(),
            status: DownloadStatus.notDownloaded,
          ),
        );

        if (activeDownload.status == DownloadStatus.downloading) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: activeDownload.progress,
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          );
        }

        return IconButton(
          icon: Icon(
            isDownloaded ? Icons.download_done : Icons.download_rounded,
            color: isDownloaded ? Colors.greenAccent : Colors.white,
          ),
          onPressed: () {
            if (isDownloaded) {
              _showDeleteConfirm(context, downloadManager, widget.lesson.id);
            } else {
              _showQualitySelectionDialog(context);
            }
          },
        );
      },
    );
  }

  void _showDeleteConfirm(
      BuildContext context, DownloadManager manager, String lessonId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التحميل'),
        content: const Text('هل تريد حذف هذا الفيديو من الجهاز؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final download = manager.getDownload(lessonId);
              if (download != null) {
                await manager.deleteDownload(download.id);
              }
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showQualitySelectionDialog(BuildContext context) async {
    if (!widget.isYoutube) {
      // Direct download
      DownloadManager().startDownload(DownloadedLesson(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        lessonId: widget.lesson.id,
        courseId: widget.lesson.courseId,
        title: widget.lesson.title,
        videoUrl: widget.lesson.videoUrl,
        localPath: '',
        fileSize: 0,
        downloadedAt: DateTime.now(),
      ));
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('جاري تحميل خيارات الجودة...'),
          ],
        ),
      ),
    );

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final manifest =
          await DownloadManager().getYouTubeStreams(widget.lesson.videoUrl);
      if (!context.mounted) return;
      navigator.pop(); // Close loading

      if (manifest == null) throw Exception('فشل في جلب الجودة');

      final muxedStreams = manifest.muxed.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر جودة الفيديو'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: muxedStreams.length,
              itemBuilder: (context, index) {
                final stream = muxedStreams[index];
                final sizeMB =
                    (stream.size.totalBytes / 1024 / 1024).toStringAsFixed(1);
                return ListTile(
                  title: Text(
                      '${stream.videoQualityLabel} (${stream.videoResolution})'),
                  subtitle: Text(
                      'الحجم: $sizeMB MB • ${stream.container.name.toUpperCase()}'),
                  onTap: () {
                    Navigator.pop(context);
                    DownloadManager().startDownload(DownloadedLesson(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      lessonId: widget.lesson.id,
                      courseId: widget.lesson.courseId,
                      title: widget.lesson.title,
                      videoUrl: stream.url.toString(),
                      localPath: '',
                      fileSize: stream.size.totalBytes,
                      downloadedAt: DateTime.now(),
                    ));
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Close loading dialog if it's there
      navigator.pop();

      messenger.showSnackBar(
        SnackBar(content: Text(ErrorUtils.getFriendlyErrorMessage(e))),
      );
    }
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
                ? (widget.youtubeController != null
                    ? ProgressBar(
                        controller: widget.youtubeController!,
                        colors: const ProgressBarColors(
                          playedColor: AppColors.primaryPurple,
                          handleColor: AppColors.primaryPurple,
                        ))
                    : const SizedBox.shrink())
                : (widget.videoController != null
                    ? VideoProgressIndicator(widget.videoController!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primaryPurple,
                        ))
                    : const SizedBox.shrink()),
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
