import 'quiz_question.dart';

enum InteractiveElementType {
  quiz,
  exercise,
  simulation,
}

class InteractiveElement {
  final String id;
  final InteractiveElementType type;
  final String title;
  final String? description;
  final Map<String, dynamic> data;

  InteractiveElement({
    required this.id,
    required this.type,
    required this.title,
    this.description,
    required this.data,
  });

  factory InteractiveElement.fromJson(Map<String, dynamic> json) {
    return InteractiveElement(
      id: json['id'] ?? '',
      type: _parseType(json['type']),
      title: json['title'] ?? '',
      description: json['description'],
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'data': data,
    };
  }

  static InteractiveElementType _parseType(String? type) {
    switch (type) {
      case 'quiz':
        return InteractiveElementType.quiz;
      case 'exercise':
        return InteractiveElementType.exercise;
      case 'simulation':
        return InteractiveElementType.simulation;
      default:
        return InteractiveElementType.quiz;
    }
  }

  // Helper methods to get typed data
  List<QuizQuestion> get quizQuestions {
    if (type != InteractiveElementType.quiz) return [];
    final questions = data['questions'] as List<dynamic>? ?? [];
    return questions.map((q) => QuizQuestion.fromJson(q)).toList();
  }
}
