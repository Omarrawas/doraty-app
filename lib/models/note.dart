class Note {
  final String id;
  final String userId;
  final String courseId;
  final String? lessonId;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isPinned;
  final int? videoTimestamp; // For video notes

  Note({
    required this.id,
    required this.userId,
    required this.courseId,
    this.lessonId,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.videoTimestamp,
  });

  String get formattedTimestamp {
    if (videoTimestamp == null) return '';
    final minutes = videoTimestamp! ~/ 60;
    final seconds = videoTimestamp! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'courseId': courseId,
      'lessonId': lessonId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'tags': tags,
      'isPinned': isPinned,
      'videoTimestamp': videoTimestamp,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    try {
      return Note(
        id: json['id']?.toString() ?? '',
        userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
        courseId: (json['course_id'] ?? json['courseId'])?.toString() ?? '',
        lessonId: (json['lesson_id'] ?? json['lessonId'])?.toString(),
        title: json['title']?.toString() ?? 'بدون عنوان',
        content: json['content']?.toString() ?? '',
        createdAt: json['created_at'] != null 
            ? DateTime.parse(json['created_at']) 
            : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
        updatedAt: json['updated_at'] != null 
            ? DateTime.parse(json['updated_at']) 
            : (json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : DateTime.now()),
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
        isPinned: json['is_pinned'] ?? json['isPinned'] ?? false,
        videoTimestamp: json['timestamp'] ?? json['videoTimestamp'],
      );
    } catch (e) {
      // Return a dummy note in case of parse failure to prevent app crash
      return Note(
        id: 'error',
        userId: '',
        courseId: '',
        title: 'خطأ في التحميل',
        content: 'تعذر تحميل هذه الملاحظة',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  Note copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? lessonId,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPinned,
    int? videoTimestamp,
  }) {
    return Note(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      lessonId: lessonId ?? this.lessonId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      videoTimestamp: videoTimestamp ?? this.videoTimestamp,
    );
  }
}
