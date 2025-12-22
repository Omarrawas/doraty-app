class Question {
  final String id;
  final String text;
  final List<String> options;
  final int correctAnswer;
  final String? explanation;
  final int points;

  Question({
    required this.id,
    required this.text,
    required this.options,
    required this.correctAnswer,
    this.explanation,
    this.points = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
      'points': points,
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      options: List<String>.from(json['options']),
      correctAnswer: json['correctAnswer'],
      explanation: json['explanation'],
      points: json['points'] ?? 1,
    );
  }
}

class Exam {
  final String id;
  final String title;
  final String description;
  final String courseId;
  final String courseName;
  final String? lessonId; // Added lessonId
  final List<Question> questions;
  final int duration; // in minutes
  final int totalPoints;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final int? score;

  Exam({
    required this.id,
    required this.title,
    required this.description,
    required this.courseId,
    required this.courseName,
    this.lessonId,
    required this.questions,
    required this.duration,
    required this.totalPoints,
    this.startTime,
    this.endTime,
    this.isCompleted = false,
    this.score,
  });

  double? get percentage {
    if (score == null || totalPoints == 0) return null;
    return (score! / totalPoints) * 100;
  }

  String get formattedDuration {
    if (duration < 60) {
      return '$duration دقيقة';
    } else {
      final hours = duration ~/ 60;
      final minutes = duration % 60;
      if (minutes == 0) {
        return '$hours ساعة';
      }
      return '$hours ساعة و $minutes دقيقة';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'courseId': courseId,
      'courseName': courseName,
      'lesson_id': lessonId,
      'questions': questions.map((q) => q.toJson()).toList(),
      'duration': duration,
      'totalPoints': totalPoints,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isCompleted': isCompleted,
      'score': score,
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      courseId:
          json['courseId'] ?? json['course_id'], // handle both cases safely
      courseName: json['courseName'] ?? '',
      lessonId: json['lesson_id'],
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
      duration: json['duration'],
      totalPoints: json['totalPoints'] ?? json['total_points'] ?? 0,
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isCompleted: json['isCompleted'] ?? false,
      score: json['score'],
    );
  }
}
