class Bookmark {
  final String id;
  final String lessonId;
  final int timestamp;
  final String title;
  final String? note;
  final DateTime createdAt;

  Bookmark({
    required this.id,
    required this.lessonId,
    required this.timestamp,
    required this.title,
    this.note,
    required this.createdAt,
  });

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      id: json['id'] ?? '',
      lessonId: json['lesson_id'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      title: json['title'] ?? '',
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'timestamp': timestamp,
      'title': title,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  String get formattedTimestamp {
    final minutes = timestamp ~/ 60;
    final seconds = timestamp % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
