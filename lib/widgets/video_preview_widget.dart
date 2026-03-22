import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'lesson/video_player_controls.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;
  final bool showHeader;
  final String? thumbnailUrl; // ← تمت الإضافة

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.showHeader = true,
    this.thumbnailUrl,
    this.onDurationFetched, // Added callback
  });
  
  final Function(Duration)? onDurationFetched; // Added property

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget>
    with SingleTickerProviderStateMixin {
  YoutubePlayerController? _controller;
  String? _videoId;
  bool _isFullScreen = false;
  bool _hasStarted = false; // هل بدأ المستخدم التشغيل؟

  // Animation للـ play button
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    // إعداد نبضة زر التشغيل
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (_videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          forceHD: false,
          enableCaption: false,
          isLive: false,
          disableDragSeek: false,
          hideControls: true, 
          hideThumbnail: true, 
        ),
      )..addListener(_onControllerChange); // Added listener
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
    // استعادة الاتجاه الرأسي دائماً عند الخروج
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  // بدء التشغيل عند الضغط على زر Play
  void _startPlayback() {
    setState(() => _hasStarted = true);
    _pulseController.stop();
    _controller?.play();
  }

  // تفعيل وضع ملء الشاشة
  void _enterFullScreen() {
    _controller?.toggleFullScreenMode();
    // onEnterFullScreen سيُفعَّل تلقائياً بعده
  }

  // إلغاء وضع ملء الشاشة
  void _exitFullScreen() {
    _controller?.toggleFullScreenMode();
    // onExitFullScreen سيُفعَّل تلقائياً بعده
  }

  // رابط Thumbnail (يميل لرابط المستخدم إن وُجد، وإلا يوتيوب)
  String get _thumbnailUrl =>
      (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
          ? widget.thumbnailUrl!
          : 'https://img.youtube.com/vi/$_videoId/hqdefault.jpg';

  @override
  Widget build(BuildContext context) {
    if (_videoId == null || _controller == null) {
      return _buildErrorWidget();
    }

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
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: SystemUiOverlay.values);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: false, // يُدار بواسطة VideoPlayerControls
        aspectRatio: 16 / 9,
      ),
      builder: (context, player) {
        // ── وضع Fullscreen ──
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

        // ── الوضع العادي ──
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  if (widget.showHeader)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.play_circle,
                              color: Colors.white.withOpacity(0.7)),
                          const SizedBox(width: 8),
                          const Text(
                            'معاينة الفيديو',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // زر التكبير - يظهر فقط بعد بدء التشغيل
                          if (_hasStarted)
                            GestureDetector(
                              onTap: _enterFullScreen,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 20,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // ── منطقة الفيديو ──
                  Expanded(
                    child: ClipRRect(
                      borderRadius: widget.showHeader
                          ? const BorderRadius.only(
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            )
                          : BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // الفيديو الفعلي
                          player,

                          // التحكم المخصص (يظهر فقط بعد بدء التشغيل)
                          if (_hasStarted)
                            VideoPlayerControls(
                              isYoutube: true,
                              youtubeController: _controller,
                              onToggleFullScreen: _enterFullScreen,
                              courseTitle: 'معاينة الفيديو',
                            ),

                          // ── Thumbnail + Play Button Overlay ──
                          // يظهر فقط قبل بدء التشغيل
                          if (!_hasStarted)
                            GestureDetector(
                              onTap: _startPlayback,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Thumbnail من يوتيوب
                                  CachedNetworkImage(
                                    imageUrl: _thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.black87,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                      color: Colors.black87,
                                      child: const Icon(Icons.image_not_supported,
                                          color: Colors.white38, size: 48),
                                    ),
                                  ),

                                  // طبقة تعتيم خفيفة
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.15),
                                          Colors.black.withOpacity(0.5),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // زر التشغيل المتحرك في المنتصف
                                  Center(
                                    child: AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: child,
                                        );
                                      },
                                      child: Container(
                                        width: 64,
                                        height: 64,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.95),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 20,
                                              spreadRadius: 4,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow_rounded,
                                          color: Color(0xFF7B2CBF),
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // نص "اضغط للمشاهدة" في الأسفل
                                  Positioned(
                                    bottom: 12,
                                    left: 0,
                                    right: 0,
                                    child: Center(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text(
                                          'اضغط للمشاهدة',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // أزلنا زر التكبير القديم لأن VideoPlayerControls أصبح يتكفل به
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.5), width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.error, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'رابط الفيديو غير صحيح',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
