class Course {
  final String id;
  final String title;
  final String? description; // Nullable
  final String? instructorId; // Added instructorId
  final String instructorName;
  final String? instructorPhoto; // Nullable in schema
  final String? imageUrl; // Renamed from thumbnail, nullable
  final double price;
  final double rating;
  final int studentsCount;
  final int lessonsCount;
  final String? durationHours; // Renamed from duration, nullable
  final String? category; // Nullable in schema
  final String subject;
  final List<String> curriculum;
  final bool isEnrolled;
  final int completedLessons;
  final String? level; // Added level

  Course({
    required this.id,
    required this.title,
    this.description,
    this.instructorId,
    required this.instructorName,
    this.instructorPhoto,
    this.imageUrl,
    required this.price,
    required this.rating,
    required this.studentsCount,
    required this.lessonsCount,
    this.durationHours,
    this.category,
    required this.subject,
    required this.curriculum,
    this.isEnrolled = false,
    this.completedLessons = 0,
    this.level,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      instructorId: json['instructor_id'],
      instructorName: json['instructor_name'] ?? '',
      instructorPhoto: json['instructor_photo'],
      imageUrl:
          json['image_url'] ?? json['thumbnail'], // Handle both for safety
      price: (json['price'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      studentsCount: json['students_count'] ?? 0,
      lessonsCount: json['lessons_count'] ?? 0,
      durationHours: json['duration_hours']?.toString() ?? json['duration'],
      category: json['category'],
      subject: json['subject'] ?? '',
      curriculum: List<String>.from(json['curriculum'] ?? []),
      isEnrolled: json['is_enrolled'] ?? false,
      completedLessons: json['completed_lessons'] ?? 0,
      level: json['level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'instructor_id': instructorId,
      'instructor_name': instructorName,
      'instructor_photo': instructorPhoto,
      'image_url': imageUrl,
      'price': price,
      'rating': rating,
      'students_count': studentsCount,
      'lessons_count': lessonsCount,
      'duration_hours': durationHours,
      'category': category,
      'subject': subject,
      'curriculum': curriculum,
      'is_enrolled': isEnrolled,
      'completed_lessons': completedLessons,
      'level': level,
    };
  }

  double get progress {
    if (lessonsCount == 0) return 0;
    return completedLessons / lessonsCount;
  }

  String get formattedPrice {
    return '${price.toStringAsFixed(0)} ل.س';
  }
}
