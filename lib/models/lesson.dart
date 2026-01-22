class Lesson {
  final String id;
  final String courseId;
  final String? chapterId; // Added chapterId
  final String title;
  final String? titleEn; // Added titleEn
  final String description;
  final String? descriptionEn; // Added descriptionEn
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
    this.titleEn,
    required this.description,
    this.descriptionEn,
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
    List<Map<String, String>> resourcesList = [];
    if (json['resources'] != null) {
      final resourcesData = json['resources'];
      if (resourcesData is List) {
        resourcesList = resourcesData
            .map((r) => Map<String, String>.from(r as Map))
            .toList();
      }
    }

    List<Map<String, dynamic>>? interactiveElementsList;
    if (json['interactive_elements'] != null) {
      final elementsData = json['interactive_elements'];
      if (elementsData is List) {
        interactiveElementsList = elementsData
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }

    return Lesson(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      chapterId: json['chapter_id'],
      title: json['title'] ?? '',
      titleEn: json['title_en'],
      description: json['description'] ?? '',
      descriptionEn: json['description_en'],
      videoUrl: json['video_url'] ?? '',
      duration: json['duration'] ?? '0:00',
      orderIndex: json['order_index'] ?? 0,
      isFree: json['is_free'] ?? false,
      contentType: json['content_type'] ?? 'video',
      resources: resourcesList,
      isCompleted: json['is_completed'] ?? false,
      contentHtml: json['content_html'],
      contentMarkdown: json['content_markdown'],
      content: json['content'],
      interactiveElements: interactiveElementsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'chapter_id': chapterId,
      'title': title,
      'title_en': titleEn,
      'description': description,
      'description_en': descriptionEn,
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
    if (locale == 'en' && titleEn != null && titleEn!.isNotEmpty) {
      return titleEn!;
    }
    return title;
  }

  Lesson copyWith({
    String? id,
    String? courseId,
    String? chapterId,
    String? title,
    String? titleEn,
    String? description,
    String? descriptionEn,
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
      titleEn: titleEn ?? this.titleEn,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
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
