import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'lesson/video_player_controls.dart';
import 'lesson/youtube_player_web_windows.dart';
import 'package:flutter/foundation.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;
  final bool showHeader;
  final String? thumbnailUrl;

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.showHeader = true,
    this.thumbnailUrl,
    this.onDurationFetched,
    this.height = 200,
  });
  
  final Function(Duration)? onDurationFetched;
  final double height;

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget>
    with SingleTickerProviderStateMixin {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _isFullScreen = false;
  bool _hasStarted = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_videoId != null) {
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        _controller = null;
      } else {
        _controller = YoutubePlayerController(
          initialVideoId: _videoId!,
          flags: YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            forceHD: false,
            enableCaption: false,
            isLive: false,
            disableDragSeek: false,
            hideControls: true, 
            hideThumbnail: true, 
          ),
        )..addListener(_onControllerChange);
      }
    }
  }

  void _onControllerChange() {
    if (_controller != null && 
        _controller!.value.isReady && 
        _controller!.metadata.duration.inSeconds > 0) {
      widget.onDurationFetched?.call(_controller!.metadata.duration);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _startPlayback() {
    setState(() => _hasStarted = true);
    _pulseController.stop();
    _controller?.play();
  }

  void _enterFullScreen() {
    if (_controller != null) {
      _controller?.toggleFullScreenMode();
    } else {
      setState(() => _isFullScreen = true);
    }
  }

  void _exitFullScreen() {
    if (_controller != null) {
      _controller?.toggleFullScreenMode();
    } else {
      setState(() => _isFullScreen = false);
    }
  }

  String get _thumbnailUrl =>
      (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          ? widget.thumbnailUrl!
          : 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
      return _buildErrorWidget();
    }

    final bool useExternalPlayer = kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

    if (!useExternalPlayer && _controller != null) {
      return YoutubePlayerBuilder(
        onEnterFullScreen: () {
          setState(() => _isFullScreen = true);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        },
        onExitFullScreen: () {
          setState(() => _isFullScreen = false);
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        },
        player: YoutubePlayer(
          controller: _controller!,
          showVideoProgressIndicator: false,
          aspectRatio: 16 / 9,
        ),
        builder: (context, player) {
          return _buildMainLayout(context, player);
        },
      );
    }

    final playerWidget = YoutubePlayerWebWindows(
      videoId: _videoId!,
      height: widget.height,
    );
    return _buildMainLayout(context, playerWidget);
  }

  Widget _buildMainLayout(BuildContext context, Widget player) {
    if (_isFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exitFullScreen();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: player),
              if (_hasStarted)
                VideoPlayerControls(
                  isYoutube: true,
                  youtubeController: _controller,
                  onToggleFullScreen: _exitFullScreen,
                  courseTitle: 'معاينة الفيديو',
                ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getMutedTextColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showHeader)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.play_circle, color: AppColors.getTextColor(context, secondary: true)),
                      SizedBox(width: 8),
                      Text(
                        'معاينة الفيديو',
                        style: TextStyle(color: AppColors.getTextColor(context), fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      if (_hasStarted)
                        GestureDetector(
                          onTap: _enterFullScreen,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.getMutedTextColor(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(Icons.fullscreen_rounded, color: AppColors.getTextColor(context, secondary: true), size: 20),
                          ),
                        ),
                    ],
                  ),
                ),

              SizedBox(
                height: widget.height,
                child: ClipRRect(
                  borderRadius: widget.showHeader
                      ? const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))
                      : BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      player,
                      if (_hasStarted)
                        VideoPlayerControls(
                          isYoutube: true,
                          youtubeController: _controller,
                          onToggleFullScreen: _enterFullScreen,
                          courseTitle: 'معاينة الفيديو',
                        ),
                      if (!_hasStarted)
                        GestureDetector(
                          onTap: _startPlayback,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CachedNetworkImage(
                                imageUrl: _thumbnailUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.black87),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black87,
                                  child: Icon(Icons.image_not_supported, color: AppColors.getTextColor(context).withOpacity(0.38), size: 48),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.black.withOpacity(0.15), Colors.black.withOpacity(0.5)],
                                  ),
                                ),
                              ),
                              Center(
                                child: AnimatedBuilder(
                                  animation: _pulseAnimation,
                                  builder: (context, child) => Transform.scale(scale: _pulseAnimation.value, child: child),
                                  child: Container(
                                    width: 64, height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.getTextColor(context, secondary: true),
                                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 4)],
                                    ),
                                    child: Icon(Icons.play_arrow_rounded, color: Color(0xFF7B2CBF), size: 40),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12, left: 0, right: 0,
                                child: Center(
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                                    child: Text('اضغط للمشاهدة', style: TextStyle(color: AppColors.getTextColor(context), fontSize: 12, fontWeight: FontWeight.w500)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 12),
          Expanded(child: Text('رابط الفيديو غير صحيح', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
