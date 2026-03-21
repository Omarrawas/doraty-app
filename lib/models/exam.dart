import '../core/utils/safe_parser.dart';
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
      id: json['id']?.toString() ?? '',
      text: json['text'] ?? json['question_text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswer: json['correctAnswer'] ?? json['correct_answer'] ?? 0,
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
  final String? lessonId;
  final List<Question> questions;
  final int duration; // in minutes
  final int totalPoints;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool isCompleted;
  final int? maxAttempts;
  final List<Map<String, dynamic>> attempts;
  final bool shuffleQuestions;
  final bool shuffleOptions;
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
    this.maxAttempts,
    this.attempts = const [],
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.score,
  });

  double? get percentage {
    final total = calculatedTotalPoints;
    if (score == null || total == 0) return null;
    return (score! / total) * 100;
  }

  int get attemptCount => attempts.length;

  bool get canTakeAgain {
    if (maxAttempts == null) return true;
    return attemptCount < maxAttempts!;
  }

  Map<String, dynamic>? get bestAttempt {
    if (attempts.isEmpty) return null;
    return attempts.reduce((curr, next) =>
        ((curr['score'] as num?) ?? 0) > ((next['score'] as num?) ?? 0)
            ? curr
            : next);
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

  int get calculatedTotalPoints {
    if (questions.isEmpty) return totalPoints; // Fallback to DB value
    return questions.fold(0, (sum, q) => sum + q.points);
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
      'max_attempts': maxAttempts,
      'shuffle_questions': shuffleQuestions,
      'shuffle_options': shuffleOptions,
      'score': score,
    };
  }

  factory Exam.fromJson(Map<String, dynamic> json) {
    // Handle course name from joined data if present
    String courseNameVal = json['courseName'] ?? '';
    if (courseNameVal.isEmpty && json['courses'] != null) {
      if (json['courses'] is Map) {
        courseNameVal = json['courses']['title'] ?? '';
      }
    }

    return Exam(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      courseId:
          json['courseId'] ??
          json['course_id'] ??
          '', // handle both cases safely
      courseName: courseNameVal,
      lessonId: json['lesson_id'],
      questions: (json['questions'] as List? ?? [])
          .map((q) => Question.fromJson(q))
          .toList(),
      duration: json['duration'] ?? 0,
      totalPoints: json['totalPoints'] ?? json['total_points'] ?? 0,
      startTime:
          json['startTime'] != null ? DateTime.parse(json['startTime']) : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isCompleted: json['isCompleted'] ?? false,
      maxAttempts: json['max_attempts'],
      attempts: SafeParser.safeMapList(json['attempts'] ?? []),
      shuffleQuestions: json['shuffle_questions'] ?? false,
      shuffleOptions: json['shuffle_options'] ?? false,
      score: json['score'],
    );
  }
}
