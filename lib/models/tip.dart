import 'package:flutter/foundation.dart';
import '../core/utils/safe_parser.dart';
import 'course.dart';

class Tip {
  final String id;
  final String title;
  final String description; // Added
  final String videoUrl;
  final String? thumbnailUrl;
  final String? courseId;
  final String? instructorId;
  final int viewsCount;
  final DateTime createdAt;
  final Course? linkedCourse; // Optional linked course object
  final String category; // Added
  final int orderIndex; // Added
  final bool isFree; // Added

  String? get effectiveThumbnailUrl {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) return thumbnailUrl;
    
    // Auto-generate for YouTube
    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be') || videoUrl.contains('shorts')) {
      final videoId = _extractYoutubeId(videoUrl);
      if (videoId != null) {
        return 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
      }
    }
    return null;
  }

  String? _extractYoutubeId(String url) {
    RegExp regExp = RegExp(
        r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*');
    var match = regExp.firstMatch(url);
    if (match != null && match.group(7) != null && match.group(7)!.length == 11) {
      return match.group(7);
    }
    
    // Check for shorts
    if (url.contains('/shorts/')) {
      final parts = url.split('/shorts/');
      if (parts.length > 1) {
        return parts[1].split('?')[0].split('&')[0];
      }
    }
    return null;
  }

  Tip({
    required this.id,
    required this.title,
    required this.description, // Added
    required this.videoUrl,
    this.thumbnailUrl,
    this.courseId,
    this.instructorId,
    this.viewsCount = 0,
    required this.createdAt,
    this.linkedCourse,
    required this.category, // Added
    this.orderIndex = 0, // Added with default
    this.isFree = false, // Added with default
  });

  factory Tip.fromJson(Map<String, dynamic> json) {
    try {
      return Tip(
        id: SafeParser.toStringSafe(json['id']),
        title: SafeParser.toStringSafe(json['title']),
        description: SafeParser.toStringSafe(json['description']),
        videoUrl: SafeParser.toStringSafe(json['video_url']),
        thumbnailUrl: SafeParser.toStringSafe(json['thumbnail_url']),
        category: SafeParser.toStringSafe(json['category']),
        orderIndex: SafeParser.toInt(json['order_index']),
        isFree: SafeParser.toBool(json['is_free']),
        courseId: SafeParser.toStringSafe(json['course_id']),
        // instructorId and viewsCount are not parsed in the new fromJson,
        // so we'll use defaults or null if not explicitly set.
        // createdAt is also not parsed, using DateTime.now() as a fallback.
        instructorId: SafeParser.toStringSafe(json['instructor_id']), // Re-added based on class definition
        viewsCount: SafeParser.toInt(json['views_count']), // Re-added based on class definition
        createdAt: SafeParser.toDateTime(json['created_at']) ?? DateTime.now(), // Re-added based on class definition
        linkedCourse: json['courses'] != null ? Course.fromJson(SafeParser.safeMap(json['courses'])) : null,
      );
    } catch (e) {
      debugPrint('❌ Tip.fromJson error: $e. Data: $json');
      return Tip(
        id: 'error_id',
        title: 'خطأ في التحميل',
        description: '',
        videoUrl: '',
        thumbnailUrl: '',
        category: '',
        createdAt: DateTime.now(), // Added for minimal valid object
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'course_id': courseId,
      'instructor_id': instructorId,
      'views_count': viewsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Tip copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? videoUrl,
    String? thumbnailUrl,
    String? courseId,
    String? instructorId,
    int? viewsCount,
    DateTime? createdAt,
    Course? linkedCourse,
  }) {
    return Tip(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      courseId: courseId ?? this.courseId,
      instructorId: instructorId ?? this.instructorId,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      linkedCourse: linkedCourse ?? this.linkedCourse,
    );
  }
}
