class Course {
  final String id;
  final String title;
  final String? description;
  final String? instructorId;
  final String instructorName;
  final String? instructorPhoto;
  final String? imageUrl;
  final double price;
  final double rating;
  final int studentsCount;
  final int lessonsCount;
  final String? durationHours;
  final List<String> categories;
  final List<String> categoryIds;
  final String subject;
  final String? subjectEn;
  final List<String> curriculum;
  final bool isEnrolled;
  final int completedLessons;
  final String? level;
  final bool isPublished;
  final String currency;
  final bool isFeatured;
  final int featuredOrder;
  final List<String> outcomes;
  final List<String> targetAudience;
  final String? videoUrl;
  final int discountPercentage;
  final List<String> tags;
  final DateTime? createdAt;

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
    this.outcomes = const [],
    this.targetAudience = const [],
    this.videoUrl,
    this.discountPercentage = 0,
    this.tags = const [],
    this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      instructorId: json['instructor_id']?.toString(),
      instructorName: json['instructor_name']?.toString() ?? '',
      instructorPhoto: json['instructor_photo']?.toString(),
      imageUrl: (json['image_url'] ?? json['thumbnail'])?.toString(),
      price: _toDouble(json['price']),
      rating: _toDouble(json['rating']),
      studentsCount: _toInt(json['students_count']),
      lessonsCount: _toInt(json['lessons_count']),
      durationHours: json['duration_hours']?.toString() ?? json['duration']?.toString(),
      categories: _toStringList(
          json['categories_names'] ?? (json['category'] != null ? [json['category']] : const [])),
      categoryIds: _toStringList(
          json['category_ids'] ?? (json['category_id'] != null ? [json['category_id']] : const [])),
      subject: json['subject']?.toString() ?? '',
      subjectEn: json['subject_en']?.toString(),
      curriculum: _toStringList(json['curriculum']),
      isEnrolled: json['is_enrolled'] == true,
      completedLessons: _toInt(json['completed_lessons']),
      level: json['level']?.toString(),
      isPublished: json['is_published'] != false,
      currency: json['currency']?.toString() ?? 'ل.س',
      isFeatured: json['is_featured'] == true,
      featuredOrder: _toInt(json['featured_order']),
      outcomes: _toStringList(json['outcomes']),
      targetAudience: _toStringList(json['target_audience']),
      videoUrl: json['video_url']?.toString(),
      discountPercentage: _toInt(json['discount_percentage']),
      tags: _toStringList(json['tags']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is Iterable) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
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
      'outcomes': outcomes,
      'target_audience': targetAudience,
      'video_url': videoUrl,
      'discount_percentage': discountPercentage,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  double get progress {
    if (lessonsCount == 0) return 0;
    return completedLessons / lessonsCount;
  }

  bool get isNew {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!).inDays < 30;
  }

  String getLocalizedTitle(String locale) {
    return title;
  }

  String? getLocalizedDescription(String locale) {
    return description;
  }

  String getLocalizedInstructorName(String locale) {
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

  String getLocalizedPrice(String locale) {
    final currentPrice = hasDiscount ? discountedPrice : price;
    String currencyLabel = currency;
    if (currency == 'ل.س') {
      currencyLabel = locale == 'en' ? 'SYP' : 'ل.س';
    }
    return '${currentPrice.toStringAsFixed(0)} $currencyLabel';
  }

  String get category => categories.isNotEmpty ? categories.first : '';
  String get categoryId => categoryIds.isNotEmpty ? categoryIds.first : '';

  double get discountedPrice {
    if (discountPercentage <= 0) return price;
    return price * (1 - discountPercentage / 100);
  }

  bool get hasDiscount => discountPercentage > 0;
}
