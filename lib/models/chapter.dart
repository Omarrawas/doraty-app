class Chapter {
  final String id;
  final String courseId;
  final String title;
  final int orderIndex;

  Chapter({
    required this.id,
    required this.courseId,
    required this.title,
    required this.orderIndex,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] ?? '',
      courseId: json['course_id'] ?? '',
      title: json['title'] ?? '',
      orderIndex: json['order_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_id': courseId,
      'title': title,
      'order_index': orderIndex,
    };
  }

  Chapter copyWith({
    String? id,
    String? courseId,
    String? title,
    int? orderIndex,
  }) {
    return Chapter(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }
}
