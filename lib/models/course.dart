class Course {
  final String id;
  final String title;
  final String? titleEn; // Added titleEn
  final String? description; // Nullable
  final String? descriptionEn; // Added descriptionEn
  final String? instructorId; // Added instructorId
  final String instructorName;
  final String? instructorFullNameEn; // Added for teacher localization
  final String? instructorPhoto; // Nullable in schema
  final String? imageUrl; // Renamed from thumbnail, nullable
  final double price;
  final double rating;
  final int studentsCount;
  final int lessonsCount;
  final String? durationHours; // Renamed from duration, nullable
  final List<String> categories; // List of category names
  final List<String> categoryIds; // List of category IDs
  final String subject;
  final String? subjectEn; // Added subjectEn
  final List<String> curriculum;
  final bool isEnrolled;
  final int completedLessons;
  final String? level;
  final bool isPublished;
  final String currency;
  final bool isFeatured;
  final int featuredOrder;

  Course({
    required this.id,
    required this.title,
    this.titleEn,
    this.description,
    this.descriptionEn,
    this.instructorId,
    required this.instructorName,
    this.instructorFullNameEn,
    this.instructorPhoto,
    this.imageUrl,
    required this.price,
    required this.rating,
    required this.studentsCount,
    required this.lessonsCount,
    this.durationHours,
    this.categories = const [],
    this.categoryIds = const [],
    required this.subject,
    this.subjectEn,
    required this.curriculum,
    this.isEnrolled = false,
    this.completedLessons = 0,
    this.level,
    this.isPublished = true,
    this.currency = 'ل.س',
    this.isFeatured = false,
    this.featuredOrder = 0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      titleEn: json['title_en'],
      description: json['description'],
      descriptionEn: json['description_en'],
      instructorId: json['instructor_id'],
      instructorName: json['instructor_name'] ?? '',
      instructorFullNameEn: json['instructor_full_name_en'],
      instructorPhoto: json['instructor_photo'],
      imageUrl:
          json['image_url'] ?? json['thumbnail'], // Handle both for safety
      price: (json['price'] ?? 0).toDouble(),
      rating: (json['rating'] ?? 0).toDouble(),
      studentsCount: json['students_count'] ?? 0,
      lessonsCount: json['lessons_count'] ?? 0,
      durationHours: json['duration_hours']?.toString() ?? json['duration'],
      categories: List<String>.from(json['categories_names'] ??
          (json['category'] != null ? [json['category']] : [])),
      categoryIds: List<String>.from(json['category_ids'] ??
          (json['category_id'] != null ? [json['category_id']] : [])),
      subject: json['subject'] ?? '',
      subjectEn: json['subject_en'],
      curriculum: List<String>.from(json['curriculum'] ?? []),
      isEnrolled: json['is_enrolled'] ?? false,
      completedLessons: json['completed_lessons'] ?? 0,
      level: json['level'],
      isPublished: json['is_published'] ?? true,
      currency: json['currency'] ?? 'ل.س',
      isFeatured: json['is_featured'] ?? false,
      featuredOrder: json['featured_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_en': titleEn,
      'description': description,
      'description_en': descriptionEn,
      'instructor_id': instructorId,
      'instructor_name': instructorName,
      'instructor_full_name_en': instructorFullNameEn,
      'instructor_photo': instructorPhoto,
      'image_url': imageUrl,
      'price': price,
      'rating': rating,
      'students_count': studentsCount,
      'lessons_count': lessonsCount,
      'duration_hours': durationHours,
      'categories': categories,
      'category_ids': categoryIds,
      'subject': subject,
      'subject_en': subjectEn,
      'curriculum': curriculum,
      'is_enrolled': isEnrolled,
      'completed_lessons': completedLessons,
      'level': level,
      'is_published': isPublished,
      'currency': currency,
      'is_featured': isFeatured,
      'featured_order': featuredOrder,
    };
  }

  double get progress {
    if (lessonsCount == 0) return 0;
    return completedLessons / lessonsCount;
  }

  String getLocalizedTitle(String locale) {
    if (locale == 'en' && titleEn != null && titleEn!.isNotEmpty) {
      return titleEn!;
    }
    return title;
  }

  String? getLocalizedDescription(String locale) {
    if (locale == 'en' && descriptionEn != null && descriptionEn!.isNotEmpty) {
      return descriptionEn;
    }
    return description;
  }

  String getLocalizedInstructorName(String locale) {
    if (locale == 'en' &&
        instructorFullNameEn != null &&
        instructorFullNameEn!.isNotEmpty) {
      return instructorFullNameEn!;
    }
    return instructorName;
  }

  String getLocalizedSubject(String locale) {
    if (locale == 'en' && subjectEn != null && subjectEn!.isNotEmpty) {
      return subjectEn!;
    }
    return subject;
  }

  String getFormattedPrice(String locale) {
    String currencyLabel = currency;
    if (currency == 'ل.س') {
      currencyLabel = locale == 'en' ? 'SYP' : 'ل.س';
    }
    return '${price.toStringAsFixed(0)} $currencyLabel';
  }

  // Backward compatibility getters
  String get category => categories.isNotEmpty ? categories.first : '';
  String get categoryId => categoryIds.isNotEmpty ? categoryIds.first : '';
}
