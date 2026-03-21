import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter/foundation.dart';

enum VideoType { network, youtube }

class PooledController {
  final String id;
  final VideoType type;
  dynamic controller;
  DateTime lastUsed;

  PooledController({
    required this.id,
    required this.type,
    required this.controller,
  }) : lastUsed = DateTime.now();
}

/// Elite Video Controller Pool for TikTok-style performance.
/// Manages max 2 controllers, reuses them, and handles prefetching.
class VideoPoolManager {
  static final VideoPoolManager _instance = VideoPoolManager._internal();
  factory VideoPoolManager() => _instance;
  VideoPoolManager._internal();

  final Map<String, PooledController> _pool = {};
  static const int maxActiveControllers = 2;

  /// Get or create a controller for a specific video
  Future<dynamic> getController(String id, String url, VideoType type) async {
    // 1. Check if already in pool
    if (_pool.containsKey(id)) {
      final pooled = _pool[id]!;
      pooled.lastUsed = DateTime.now();
      return pooled.controller;
    }

    // 2. Manage pool size (Evict oldest if needed)
    if (_pool.length >= maxActiveControllers) {
      _evictOldest();
    }

    // 3. Create new controller
    dynamic controller;
    if (type == VideoType.youtube) {
      final videoId = YoutubePlayer.convertUrlToId(url) ?? '';
      controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          disableDragSeek: true,
          loop: true,
        ),
      );
    } else {
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await (controller as VideoPlayerController).initialize();
    }

    _pool[id] = PooledController(id: id, type: type, controller: controller);
    return controller;
  }

  /// Prefetch metadata and thumbnail (Network level handled by OS/Image Cache)
  /// We pre-initialize the controller here for the "Next" video.
  Future<void> prefetch(String id, String url, VideoType type) async {
    if (_pool.containsKey(id)) return;
    
    debugPrint('🚀 VideoPoolManager: Prefetching controller for $id');
    try {
      await getController(id, url, type);
    } catch (e) {
      debugPrint('⚠️ Prefetch failed for $id: $e');
    }
  }

  void _evictOldest() {
    if (_pool.isEmpty) return;
    
    String? oldestKey;
    DateTime? oldestTime;

    _pool.forEach((key, value) {
      if (oldestTime == null || value.lastUsed.isBefore(oldestTime!)) {
        oldestTime = value.lastUsed;
        oldestKey = key;
      }
    });

    if (oldestKey != null) {
      debugPrint('🗑️ VideoPoolManager: Evicting $oldestKey to save memory');
      final pooled = _pool.remove(oldestKey);
      _disposeController(pooled?.controller);
    }
  }

  void _disposeController(dynamic controller) {
    if (controller == null) return;
    if (controller is YoutubePlayerController) {
      controller.dispose();
    } else if (controller is VideoPlayerController) {
      controller.dispose();
    }
  }

  void disposeAll() {
    _pool.forEach((key, value) {
      _disposeController(value.controller);
    });
    _pool.clear();
  }
}
