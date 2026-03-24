import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/tip.dart';
import '../core/theme/app_colors.dart';

class TipPreviewCard extends StatefulWidget {
  final Tip tip;
  final VoidCallback onTap;

  const TipPreviewCard({
    super.key,
    required this.tip,
    required this.onTap,
  });

  @override
  State<TipPreviewCard> createState() => _TipPreviewCardState();
}

class _TipPreviewCardState extends State<TipPreviewCard> {
  VideoPlayerController? _controller;
  bool _isHovering = false;
  bool _isInitialized = false;
  bool _isYouTube = false;

  @override
  void initState() {
    super.initState();
    _isYouTube = widget.tip.videoUrl.contains('youtube.com') || 
                 widget.tip.videoUrl.contains('youtu.be') || 
                 widget.tip.videoUrl.contains('shorts');
  }

  Future<void> _initializePlayer() async {
    if (_isYouTube || _isInitialized || _controller != null) return;

    final uri = Uri.parse(widget.tip.videoUrl);
    _controller = VideoPlayerController.networkUrl(uri);
    
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _controller!.setVolume(0); // Silent preview like YouTube/TikTok
          _controller!.setLooping(true);
          if (_isHovering) _controller!.play();
        });
      }
    } catch (e) {
      debugPrint('Error initializing tip preview: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleHoverEnter() {
    setState(() => _isHovering = true);
    if (!_isYouTube) {
      if (!_isInitialized) {
        _initializePlayer();
      } else {
        _controller?.play();
      }
    }
  }

  void _handleHoverExit() {
    setState(() => _isHovering = false);
    if (_isInitialized) {
      _controller?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHoverEnter(),
      onExit: (_) => _handleHoverExit(),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: _handleHoverEnter, // For mobile "preview" on long press
        onLongPressUp: _handleHoverExit,
        child: Container(
          width: 140,
          margin: EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: Colors.black26,
            boxShadow: [
              if (_isHovering)
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Static Thumbnail (Always shown behind if video loading or not hovering)
                CachedNetworkImage(
                  imageUrl: widget.tip.thumbnailUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.getTextColor(context).withOpacity(0.10)),
                  errorWidget: (context, url, err) => Icon(Icons.play_circle_fill, color: AppColors.getTextColor(context).withOpacity(0.24)),
                ),

                // 2. Video Preview (Only mp4 supported easily for list previews)
                if (!_isYouTube && _isInitialized && _isHovering)
                  VideoPlayer(_controller!),

                // 3. YouTube Indicator (Since we can't easily hover-preview YT without iframe)
                if (_isYouTube && _isHovering)
                  Container(
                    color: Colors.black45,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_filled, color: Colors.red, size: 40),
                          SizedBox(height: 4),
                          Text(
                            'YouTube',
                            style: TextStyle(color: AppColors.getTextColor(context, secondary: true), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 4. Corner Badge (Optional)
                if (_isHovering && !_isYouTube && !_isInitialized)
                  Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.getTextColor(context).withOpacity(0.70))),
                
                // 5. Title Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Text(
                      widget.tip.title,
                      style: TextStyle(color: AppColors.getTextColor(context), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
