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
    this.currency = 'ل.س',
  });

  factory Bundle.fromJson(Map<String, dynamic> json, {List<Course>? courses}) {
    return Bundle(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'] ?? json['thumbnail'],
      price: (json['price'] ?? 0).toDouble(),
      discountPercentage: json['discount_percentage'] ?? 0,
      courses: courses ?? (json['courses'] != null 
          ? (json['courses'] as List).map((c) => Course.fromJson(c)).toList()
          : []),
      instructorNames: List<String>.from(json['instructor_names'] ?? []),
      studentsCount: json['students_count'] ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'ل.س',
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
    if (currency == 'ل.س') {
      currencyLabel = locale == 'en' ? 'SYP' : 'ل.س';
    }
    return '${currentPrice.toStringAsFixed(0)} $currencyLabel';
  }
  
  String getOriginalPrice(String locale) {
    String currencyLabel = currency;
    if (currency == 'ل.س') {
      currencyLabel = locale == 'en' ? 'SYP' : 'ل.س';
    }
    return '${price.toStringAsFixed(0)} $currencyLabel';
  }
}
