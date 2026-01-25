class Flashcard {
  final String id;
  final String front;
  final String back;
  final String? imageUrl;
  final String? lessonId;
  final DateTime? nextReviewDate;
  final int interval; // in days
  final double easeFactor;
  final int repetitionCount;

  Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.imageUrl,
    this.lessonId,
    this.nextReviewDate,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.repetitionCount = 0,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['id'] ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      imageUrl: json['image_url'],
      lessonId: json['lesson_id'],
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'])
          : null,
      interval: json['interval'] ?? 0,
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      repetitionCount: json['repetition_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
      'image_url': imageUrl,
      'lesson_id': lessonId,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'interval': interval,
      'ease_factor': easeFactor,
      'repetition_count': repetitionCount,
    };
  }

  Flashcard copyWith({
    String? id,
    String? front,
    String? back,
    String? imageUrl,
    String? lessonId,
    DateTime? nextReviewDate,
    int? interval,
    double? easeFactor,
    int? repetitionCount,
  }) {
    return Flashcard(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      imageUrl: imageUrl ?? this.imageUrl,
      lessonId: lessonId ?? this.lessonId,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      repetitionCount: repetitionCount ?? this.repetitionCount,
    );
  }
}
