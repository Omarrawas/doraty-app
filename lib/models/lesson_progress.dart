class LessonProgress {
  final String id;
  final String userId;
  final String lessonId;
  final bool isCompleted;
  final int watchTime; // in seconds
  final int lastPosition; // in seconds
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  LessonProgress({
    required this.id,
    required this.userId,
    required this.lessonId,
    this.isCompleted = false,
    this.watchTime = 0,
    this.lastPosition = 0,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      lessonId: json['lesson_id'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      watchTime: json['watch_time'] ?? 0,
      lastPosition: json['last_position'] ?? 0,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'lesson_id': lessonId,
      'is_completed': isCompleted,
      'watch_time': watchTime,
      'last_position': lastPosition,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  LessonProgress copyWith({
    String? id,
    String? userId,
    String? lessonId,
    bool? isCompleted,
    int? watchTime,
    int? lastPosition,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonProgress(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      lessonId: lessonId ?? this.lessonId,
      isCompleted: isCompleted ?? this.isCompleted,
      watchTime: watchTime ?? this.watchTime,
      lastPosition: lastPosition ?? this.lastPosition,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  double get progressPercentage {
    if (watchTime == 0) return 0.0;
    return (lastPosition / watchTime * 100).clamp(0.0, 100.0);
  }
}
