import 'package:flutter/foundation.dart';
import '../core/utils/safe_parser.dart';

class Lesson {
  final String id;
  final String courseId;
  final String? chapterId; // Added chapterId
  final String title;
  final String? slug; // Added slug
  final String description;
  final String videoUrl;
  final String duration; // stored as string like "45:00"
  final int orderIndex;
  final bool isFree;
  final String contentType;
  final List<Map<String, String>> resources;
  final bool isCompleted;
  final String? contentHtml;
  final String? contentMarkdown;
  final String? content;
  final List<Map<String, dynamic>>? interactiveElements;

  Lesson({
    required this.id,
    required this.courseId,
    this.chapterId,
    required this.title,
    this.slug,
    required this.description,
    required this.videoUrl,
    required this.duration,
    required this.orderIndex,
    required this.isFree,
    this.contentType = 'video',
    this.resources = const [],
    this.isCompleted = false,
    this.contentHtml,
    this.contentMarkdown,
    this.content,
    this.interactiveElements,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    try {
      final List<Map<String, String>> resourcesList = [];
      final resourcesRaw = json['resources'];
      if (resourcesRaw != null && resourcesRaw is Iterable) {
        for (final r in resourcesRaw) {
          if (r is Map) {
            final Map<String, String> res = {};
            r.forEach((k, v) => res[k.toString()] = v?.toString() ?? '');
            resourcesList.add(res);
          }
        }
      }

      final List<Map<String, dynamic>> interactiveElementsList = [];
      final elementsRaw = json['interactive_elements'];
      if (elementsRaw != null && elementsRaw is Iterable) {
        for (final e in elementsRaw) {
          if (e is Map) {
            interactiveElementsList.add(SafeParser.safeMap(e));
          }
        }
      }

      return Lesson(
        id: SafeParser.toStringSafe(json['id']),
        courseId: SafeParser.toStringSafe(json['course_id']),
        chapterId: SafeParser.toStringSafe(json['chapter_id']),
        title: SafeParser.toStringSafe(json['title']),
        slug: SafeParser.toStringSafe(json['slug'], fallback: ''),
        description: SafeParser.toStringSafe(json['description']),
        videoUrl: SafeParser.toStringSafe(json['video_url']),
        duration: SafeParser.toStringSafe(json['duration'], fallback: '0:00'),
        orderIndex: SafeParser.toInt(json['order_index']),
        isFree: SafeParser.toBool(json['is_free']),
        contentType: SafeParser.toStringSafe(json['content_type'], fallback: 'video'),
        resources: resourcesList,
        isCompleted: SafeParser.toBool(json['is_completed']),
        contentHtml: SafeParser.toStringSafe(json['content_html']),
        contentMarkdown: SafeParser.toStringSafe(json['content_markdown']),
        content: SafeParser.toStringSafe(json['content']),
        interactiveElements: interactiveElementsList,
      );
    } catch (e) {
      debugPrint('❌ Lesson.fromJson error: $e. Data: $json');
      return Lesson(
        id: 'error',
        courseId: '',
        title: 'Error loading lesson',
        description: '',
        videoUrl: '',
        duration: '0:00',
        orderIndex: 0,
        isFree: false,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'chapter_id': chapterId,
      'title': title,
      'slug': slug != null && slug!.isNotEmpty ? slug : null,
      'description': description,
      'video_url': videoUrl,
      'duration': duration,
      'order_index': orderIndex,
      'is_free': isFree,
      'content_type': contentType,
      'resources': resources,
      'is_completed': isCompleted,
      'content_html': contentHtml,
      'content_markdown': contentMarkdown,
      'content': content,
      'interactive_elements': interactiveElements,
    };
  }

  String getLocalizedTitle(String locale) {
    return title;
  }

  String getLocalizedDescription(String locale) {
    return description;
  }

  Lesson copyWith({
    String? id,
    String? courseId,
    String? chapterId,
    String? title,
    String? slug,
    String? description,
    String? videoUrl,
    String? duration,
    int? orderIndex,
    bool? isFree,
    String? contentType,
    List<Map<String, String>>? resources,
    bool? isCompleted,
    String? contentHtml,
    String? contentMarkdown,
    String? content,
    List<Map<String, dynamic>>? interactiveElements,
  }) {
    return Lesson(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      chapterId: chapterId ?? this.chapterId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      duration: duration ?? this.duration,
      orderIndex: orderIndex ?? this.orderIndex,
      isFree: isFree ?? this.isFree,
      contentType: contentType ?? this.contentType,
      resources: resources ?? this.resources,
      isCompleted: isCompleted ?? this.isCompleted,
      contentHtml: contentHtml ?? this.contentHtml,
      contentMarkdown: contentMarkdown ?? this.contentMarkdown,
      content: content ?? this.content,
      interactiveElements: interactiveElements ?? this.interactiveElements,
    );
  }
}
