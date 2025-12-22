class LessonQuestion {
  final String id;
  final String lessonId;
  final String userId;
  final String content;
  final String? answer;
  final String userName;
  final String? userPhoto;
  final DateTime createdAt;
  final DateTime? answeredAt;

  LessonQuestion({
    required this.id,
    required this.lessonId,
    required this.userId,
    required this.content,
    this.answer,
    required this.userName,
    this.userPhoto,
    required this.createdAt,
    this.answeredAt,
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    return LessonQuestion(
      id: json['id']?.toString() ?? '',
      lessonId: json['lesson_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      answer: json['answer']?.toString(),
      userName: json['users'] != null ? (json['users']['full_name'] ?? 'مستخدِم') : 'مستخدِم',
      userPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      answeredAt: json['answered_at'] != null 
          ? DateTime.parse(json['answered_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'user_id': userId,
      'content': content,
      'answer': answer,
      'created_at': createdAt.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
    };
  }
}
