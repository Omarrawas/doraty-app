import 'course.dart';

class Bundle {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final double price;
  final int discountPercentage;
  final List<Course> courses;
  final List<String> instructorNames;
  final int studentsCount;
  final double rating;
  final String currency;

  Bundle({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.price,
    this.discountPercentage = 0,
    required this.courses,
    this.instructorNames = const [],
    this.studentsCount = 0,
    this.rating = 0,
    this.currency = 'SYP',
  });

  factory Bundle.fromJson(Map<String, dynamic> json, {List<Course>? courses}) {
    final List<Course> parsedCourses;
    if (courses != null) {
      parsedCourses = courses;
    } else {
      final dynamic rawCourses = json['courses'];
      if (rawCourses is Iterable) {
        parsedCourses = rawCourses
            .whereType<Map>()
            .map((c) => Course.fromJson(Map<String, dynamic>.from(c)))
            .toList();
      } else {
        parsedCourses = [];
      }
    }

    return Bundle(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: (json['image_url'] ?? json['thumbnail'])?.toString(),
      price: (json['price'] as num?)?.toDouble() ??
          double.tryParse(json['price']?.toString() ?? '0') ??
          0.0,
      discountPercentage: (json['discount_percentage'] as num?)?.toInt() ??
          int.tryParse(json['discount_percentage']?.toString() ?? '0') ??
          0,
      courses: parsedCourses,
      instructorNames: (json['instructor_names'] is Iterable)
          ? (json['instructor_names'] as Iterable)
              .map((e) => e.toString())
              .toList()
          : const [],
      studentsCount: (json['students_count'] as num?)?.toInt() ??
          int.tryParse(json['students_count']?.toString() ?? '0') ??
          0,
      rating: (json['rating'] as num?)?.toDouble() ??
          double.tryParse(json['rating']?.toString() ?? '0') ??
          0.0,
      currency: json['currency']?.toString() ?? 'SYP',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'price': price,
      'discount_percentage': discountPercentage,
      'instructor_names': instructorNames,
      'students_count': studentsCount,
      'rating': rating,
      'currency': currency,
    };
  }

  double get discountedPrice {
    if (discountPercentage <= 0) return price;
    return price * (1 - discountPercentage / 100);
  }

  bool get hasDiscount => discountPercentage > 0;

  String getFormattedPrice(String locale) {
    final currentPrice = hasDiscount ? discountedPrice : price;
    String currencyLabel = currency;
    if (currency == 'SYP') {
      currencyLabel = locale == 'en' ? 'SYP' : 'SYP';
    }
    return '${currentPrice.toStringAsFixed(0)} $currencyLabel';
  }

  String getOriginalPrice(String locale) {
    String currencyLabel = currency;
    if (currency == 'SYP') {
      currencyLabel = locale == 'en' ? 'SYP' : 'SYP';
    }
    return '${price.toStringAsFixed(0)} $currencyLabel';
  }
}
