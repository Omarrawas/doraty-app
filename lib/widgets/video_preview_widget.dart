import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'lesson/video_player_controls.dart';
import 'lesson/youtube_player_web_windows.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

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
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  
  String? _videoId;
  bool _isYoutube = false;
  bool _hasStarted = false;
  bool _isInitialized = false;
  final GlobalKey _youtubePlayerKey = GlobalKey();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _youtubeController?.removeListener(_onControllerChange);
      _youtubeController?.dispose();
      _videoController?.dispose();
      _chewieController?.dispose();
      _youtubeController = null;
      _videoController = null;
      _chewieController = null;
      _isInitialized = false;
      _hasStarted = false;
      _initPlayer();
      if (mounted) setState(() {});
    }
  }

  void _initPlayer() {
    final url = widget.videoUrl;
    if (url.isEmpty) return;

    // 1. YouTube Check
    if (url.contains('youtu.be') || url.contains('youtube.com')) {
      _isYoutube = true;
      _videoId = YoutubePlayer.convertUrlToId(url);
      if (_videoId != null && _videoId!.contains('?')) {
        _videoId = _videoId!.split('?').first;
      }
      
      if (_videoId != null) {
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: _videoId!,
            flags: const YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              forceHD: true,
              enableCaption: false,
              isLive: false,
              disableDragSeek: false,
              hideControls: true, 
              hideThumbnail: true,
              useHybridComposition: true, // Improved Android compatibility
            ),
          )..addListener(_onControllerChange);
        } else {
          _fetchYoutubeDurationWeb();
        }
      }
      return;
    }

    // 2. Regular Video Check
    _isYoutube = false;
    final sanitizedUrl = _sanitizeUrl(url);
    
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(sanitizedUrl),
      httpHeaders: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Referer': 'https://supabase.co',
      },
    );

    _videoController!.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _isInitialized = true;
        final isVertical = _videoController!.value.aspectRatio < 1.0;
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: false,
          looping: false,
          aspectRatio: _videoController!.value.aspectRatio,
          deviceOrientationsOnEnterFullScreen: isVertical
              ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
              : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
          placeholder: Container(color: Colors.black),
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Text('فشل تحميل الفيديو', style: TextStyle(color: Colors.white)),
            );
          },
        );
      });
      widget.onDurationFetched?.call(_videoController!.value.duration);
    }).catchError((e) {
      debugPrint('Error initializing video: $e');
    });
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

  void _onControllerChange() {
    if (_youtubeController != null && 
        _youtubeController!.value.isReady && 
        _youtubeController!.metadata.duration.inSeconds > 0) {
      widget.onDurationFetched?.call(_youtubeController!.metadata.duration);
    }
  }

  Future<void> _fetchYoutubeDurationWeb() async {
    if (_videoId == null) return;
    try {
      final yt = yt_explode.YoutubeExplode();
      final video = await yt.videos.get(_videoId!);
      if (video.duration != null && mounted) {
        widget.onDurationFetched?.call(video.duration!);
      }
      yt.close();
    } catch (e) {
      debugPrint('Error fetching youtube duration: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _youtubeController?.dispose();
    _videoController?.dispose();
    _chewieController?.dispose();
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
    if (_isYoutube) {
      _youtubeController?.play();
    } else {
      _videoController?.play();
    }
  }

  void _enterFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullScreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  String get _thumbnailUrl =>
      (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          ? widget.thumbnailUrl!
          : 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    if (_isYoutube && _videoId == null) {
      return _buildErrorWidget();
    }

    final bool useExternalYoutube =
        _isYoutube && (kIsWeb || defaultTargetPlatform == TargetPlatform.windows);

    return OrientationBuilder(
      builder: (context, orientation) {
        final bool isLandscape = orientation == Orientation.landscape;

        Widget playerWidget;
        if (_isYoutube && !useExternalYoutube && _youtubeController != null) {
          playerWidget = Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(
                key: _youtubePlayerKey,
                controller: _youtubeController!,
                showVideoProgressIndicator: false,
              ),
            ),
          );
        } else if (useExternalYoutube) {
          playerWidget = YoutubePlayerWebWindows(
            videoId: _videoId!,
            height: widget.height,
          );
        } else {
          // Regular Video
          if (_chewieController != null &&
              _videoController != null &&
              _isInitialized) {
            playerWidget = Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Chewie(controller: _chewieController!),
              ),
            );
          } else {
            playerWidget = Container(
              color: Colors.black,
              child: const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryPurple)),
            );
          }
        }

        return _buildMainLayout(context, playerWidget, isLandscape);
      },
    );
  }

  Widget _buildMainLayout(BuildContext context, Widget player, bool isFullScreen,
      {bool showThumbnailOverlay = true}) {
    if (isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            player,
            VideoPlayerControls(
              isYoutube: _isYoutube,
              youtubeController: _youtubeController,
              videoController: _videoController,
              onToggleFullScreen: _exitFullScreen,
              courseTitle: 'معاينة الفيديو',
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.getElevatedSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorderColor(context), width: 1),
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
                      if (_hasStarted && showThumbnailOverlay)
                        GestureDetector(
                          onTap: _enterFullScreen,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.getSurfaceColor(context),
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
                      if (_hasStarted || !showThumbnailOverlay) player,
                      if (_hasStarted && showThumbnailOverlay)
                        VideoPlayerControls(
                          isYoutube: _isYoutube,
                          youtubeController: _youtubeController,
                          videoController: _videoController,
                          onToggleFullScreen: _enterFullScreen,
                          courseTitle: 'معاينة الفيديو',
                        ),
                      if (!_hasStarted && showThumbnailOverlay)
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
