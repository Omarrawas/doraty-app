import 'package:flutter/material.dart';
import '../core/utils/safe_parser.dart';
import 'lesson.dart';

class Course {
  final String id;
  final String title;
  final String slug;
  final String? description;
  final String? instructorId;
  final String instructorName;

  String getLocalizedTitle(String locale) => title;
  String getLocalizedInstructorName(String locale) => instructorName;
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
  final String? status;
  final DateTime? createdAt;
  final List<Lesson> lessons;
  final double progress;

  Course({
    required this.id,
    required this.title,
    this.slug = '',
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
    this.curriculum = const [],
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
    this.status,
    this.createdAt,
    this.lessons = const [],
    this.progress = 0.0,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    try {
      final List<Lesson> parsedLessons = [];
      final lessonsRaw = json['lessons'];
      if (lessonsRaw != null && lessonsRaw is Iterable) {
        for (final l in lessonsRaw) {
          if (l is Map) {
            parsedLessons.add(Lesson.fromJson(SafeParser.safeMap(l)));
          }
        }
      }

      return Course(
        id: SafeParser.toStringSafe(json['id']),
        title: SafeParser.toStringSafe(json['title']),
        slug: SafeParser.toStringSafe(json['slug'], fallback: ''), // Added slug
        description: SafeParser.toStringSafe(json['description']),
        instructorId: SafeParser.toStringSafe(json['instructor_id']),
        instructorName: SafeParser.toStringSafe(json['instructor_name']),
        instructorPhoto: SafeParser.toStringSafe(json['instructor_photo']),
        imageUrl: SafeParser.toStringSafe(json['image_url'] ?? json['thumbnail']),
        price: SafeParser.toDouble(json['price']),
        rating: SafeParser.toDouble(json['rating']),
        studentsCount: SafeParser.toInt(json['students_count']),
        lessonsCount: SafeParser.toInt(json['lessons_count']),
        durationHours: SafeParser.toStringSafe(json['duration_hours'] ?? json['duration']),
        categories: SafeParser.toStringList(json['categories_names'] ?? (json['category'] != null ? [json['category']] : [])),
        categoryIds: SafeParser.toStringList(json['category_ids'] ?? (json['category_id'] != null ? [json['category_id']] : [])),
        subject: SafeParser.toStringSafe(json['subject']),
        subjectEn: SafeParser.toStringSafe(json['subject_en']),
        curriculum: SafeParser.toStringList(json['curriculum']),
        isEnrolled: SafeParser.toBool(json['is_enrolled']),
        completedLessons: SafeParser.toInt(json['completed_lessons']),
        level: SafeParser.toStringSafe(json['level']),
        isPublished: SafeParser.toBool(json['is_published'], fallback: true),
        currency: SafeParser.toStringSafe(json['currency'], fallback: 'ل.س'),
        isFeatured: SafeParser.toBool(json['is_featured']),
        featuredOrder: SafeParser.toInt(json['featured_order']),
        outcomes: SafeParser.toStringList(json['outcomes']),
        targetAudience: SafeParser.toStringList(json['target_audience']),
        videoUrl: SafeParser.toStringSafe(json['video_url']),
        discountPercentage: SafeParser.toInt(json['discount_percentage']),
        tags: SafeParser.toStringList(json['tags']),
        status: SafeParser.toStringSafe(json['status']),
        createdAt: SafeParser.toDateTime(json['created_at']),
        lessons: parsedLessons,
        progress: SafeParser.toDouble(json['progress']),
      );
    } catch (e) {
      debugPrint('❌ Course.fromJson error: $e. Data: $json');
      return Course(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        title: 'خطأ في تحميل الدورة',
        slug: '',
        instructorName: '',
        price: 0,
        rating: 0,
        studentsCount: 0,
        lessonsCount: 0,
        subject: '',
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug.isNotEmpty ? slug : null,
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
      'status': status,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  double get calculatedProgress {
    if (lessonsCount == 0) return 0;
    return completedLessons / lessonsCount;
  }

  bool get isNew {
    if (createdAt == null) return false;
    return DateTime.now().difference(createdAt!).inDays < 30;
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
