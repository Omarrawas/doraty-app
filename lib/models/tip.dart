import 'course.dart';

class Tip {
  final String id;
  final String title;
  final String videoUrl;
  final String? thumbnailUrl;
  final String? courseId;
  final String? instructorId;
  final int viewsCount;
  final DateTime createdAt;
  final Course? linkedCourse; // Optional linked course object

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
    required this.videoUrl,
    this.thumbnailUrl,
    this.courseId,
    this.instructorId,
    this.viewsCount = 0,
    required this.createdAt,
    this.linkedCourse,
  });

  factory Tip.fromJson(Map<String, dynamic> json) {
    return Tip(
      id: json['id'],
      title: json['title'],
      videoUrl: json['video_url'],
      thumbnailUrl: json['thumbnail_url'],
      courseId: json['course_id'],
      instructorId: json['instructor_id'],
      viewsCount: json['views_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      linkedCourse: json['courses'] != null ? Course.fromJson(json['courses']) : null,
    );
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
