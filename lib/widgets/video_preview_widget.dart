import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:ui';

class VideoPreviewWidget extends StatefulWidget {
  final String videoUrl;
  final bool showHeader; // Added

  const VideoPreviewWidget({
    super.key,
    required this.videoUrl,
    this.showHeader = true, // Default to true
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  YoutubePlayerController? _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);

    if (_videoId != null) {
      _controller = YoutubePlayerController(
        initialVideoId: _videoId!,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoId == null) {
      return _buildErrorWidget();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    ],
                  ),
                ),
              Expanded(
                child: ClipRRect(
                  borderRadius: widget.showHeader 
                      ? const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        )
                      : BorderRadius.circular(16),
                  child: YoutubePlayer(
                    controller: _controller!,
                    showVideoProgressIndicator: true,
                    aspectRatio: widget.showHeader ? 16 / 9 : 1, // Change aspect ratio based on header
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
