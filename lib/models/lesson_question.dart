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
  final Map<String, int> reactionCounts;
  final String? myReaction;

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
    this.reactionCounts = const {},
    this.myReaction,
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
      reactionCounts: json['reaction_summary'] != null
          ? Map<String, int>.from(json['reaction_summary'])
          : {},
      myReaction: json['my_reaction']?.toString(),
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

  LessonQuestion copyWith({
    String? id,
    String? lessonId,
    String? userId,
    String? content,
    String? answer,
    String? userName,
    String? userPhoto,
    DateTime? createdAt,
    DateTime? answeredAt,
    List<LessonQuestionReply>? replies,
    Map<String, int>? reactionCounts,
    String? myReaction,
  }) {
    return LessonQuestion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      answer: answer ?? this.answer,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      createdAt: createdAt ?? this.createdAt,
      answeredAt: answeredAt ?? this.answeredAt,
      replies: replies ?? this.replies,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReaction: myReaction ?? this.myReaction,
    );
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
  final Map<String, int> reactionCounts;
  final String? myReaction;

  LessonQuestionReply({
    required this.id,
    required this.questionId,
    required this.userId,
    required this.content,
    required this.userName,
    this.userPhoto,
    required this.createdAt,
    required this.isInstructorReply,
    this.reactionCounts = const {},
    this.myReaction,
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
      reactionCounts: json['reaction_summary'] != null
          ? Map<String, int>.from(json['reaction_summary'])
          : {},
      myReaction: json['my_reaction']?.toString(),
    );
  }

  LessonQuestionReply copyWith({
    String? id,
    String? questionId,
    String? userId,
    String? content,
    String? userName,
    String? userPhoto,
    DateTime? createdAt,
    bool? isInstructorReply,
    Map<String, int>? reactionCounts,
    String? myReaction,
  }) {
    return LessonQuestionReply(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      userName: userName ?? this.userName,
      userPhoto: userPhoto ?? this.userPhoto,
      createdAt: createdAt ?? this.createdAt,
      isInstructorReply: isInstructorReply ?? this.isInstructorReply,
      reactionCounts: reactionCounts ?? this.reactionCounts,
      myReaction: myReaction ?? this.myReaction,
    );
  }
}
