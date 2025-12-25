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

  final List<LessonQuestionReply> replies;

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
    this.replies = const [],
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    var repliesList = <LessonQuestionReply>[];
    if (json['question_replies'] != null) {
      repliesList = (json['question_replies'] as List)
          .map((r) => LessonQuestionReply.fromJson(r))
          .toList();
    }

    // Attempt to fill "answer" from standard answer field OR first reply
    String? legacyAnswer = json['answer']?.toString();
    if (legacyAnswer == null && repliesList.isNotEmpty) {
      legacyAnswer = repliesList.first.content;
    }

    return LessonQuestion(
      id: json['id']?.toString() ?? '',
      lessonId: json['lesson_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      answer: legacyAnswer,
      userName: json['users'] != null ? (json['users']['full_name'] ?? 'مستخدِم') : 'مستخدِم',
      userPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      answeredAt: json['answered_at'] != null 
          ? DateTime.parse(json['answered_at']) 
          : null,
      replies: repliesList,
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

class LessonQuestionReply {
  final String id;
  final String questionId;
  final String userId;
  final String content;
  final String userName;
  final String? userPhoto;
  final DateTime createdAt;
  final bool isInstructorReply;

  LessonQuestionReply({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.userName,
    this.userPhoto,
    required this.createdAt,
    required this.isInstructorReply,
  });

  factory LessonQuestionReply.fromJson(Map<String, dynamic> json) {
    return LessonQuestionReply(
      id: json['id']?.toString() ?? '',
      questionId: json['question_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      userName: json['users'] != null
          ? (json['users']['full_name'] ?? 'مستخدِم')
          : 'مستخدِم',
      userPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isInstructorReply: json['is_instructor_reply'] ?? false,
    );
  }
}
