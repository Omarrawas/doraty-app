import 'dart:convert';

class Review {
  final String id;
  final String courseId;
  final String userId;
  final String userName;
  final String? userPhoto;
  final double rating;
  final String comment;
  final DateTime createdAt;
  final List<String> likes;
  final List<String> dislikes;

  Review({
    required this.id,
    required this.courseId,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.likes = const [],
    this.dislikes = const [],
  });

  int get likesCount => likes.length;
  int get dislikesCount => dislikes.length;

  bool isLikedBy(String userId) => likes.contains(userId);
  bool isDislikedBy(String userId) => dislikes.contains(userId);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'courseId': courseId,
      'userId': userId,
      'userName': userName,
      'userPhoto': userPhoto,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'likes': likes,
      'dislikes': dislikes,
    };
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      courseId: json['course_id'],
      userId: json['user_id'],
      userName: json['users'] != null ? json['users']['full_name'] : 'مستخدم',
      userPhoto: json['users'] != null ? json['users']['avatar_url'] : null,
      rating: (json['rating'] ?? 0).toDouble(),
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      likes: _parseStringList(
          json['likes'] ?? json['likes_user_ids'] ?? json['likes_users']),
      dislikes: _parseStringList(json['dislikes'] ??
          json['dislikes_user_ids'] ??
          json['dislikes_users']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    // If already a List, map to String
    if (value is List) {
      return value
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    // If it's a JSON-encoded string representing a list
    if (value is String) {
      // Try decode JSON
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {
        // not JSON — fall through to comma split
      }
      // Comma-separated string
      return value
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    // If it's a map of user objects, extract ids
    if (value is Map) {
      return value.values
          .map((e) {
            if (e is Map) {
              return (e['id'] ?? e['user_id'] ?? e['userId'] ?? '').toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }
    // Fallback: single value to string
    return [value.toString()];
  }
}

class CourseRating {
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingDistribution; // star -> count

  CourseRating({
    required this.averageRating,
    required this.totalReviews,
    required this.ratingDistribution,
  });

  double getPercentageForRating(int stars) {
    if (totalReviews == 0) return 0;
    final count = ratingDistribution[stars] ?? 0;
    return (count / totalReviews) * 100;
  }

  Map<String, dynamic> toJson() {
    return {
      'averageRating': averageRating,
      'totalReviews': totalReviews,
      'ratingDistribution': ratingDistribution,
    };
  }

  factory CourseRating.fromJson(Map<String, dynamic> json) {
    return CourseRating(
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalReviews: json['totalReviews'],
      ratingDistribution: Map<int, int>.from(json['ratingDistribution']),
    );
  }
}
