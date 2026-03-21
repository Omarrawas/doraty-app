import 'package:flutter/foundation.dart';
import '../core/utils/safe_parser.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String? bio;
  final String? photoUrl;
  final List<String> enrolledCourses;
  final int completedCourses;
  final int totalHours;
  final int certificates;
  final int streakCount;
  final DateTime? lastActivityDate;
  final List<String> badges;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.enrolledCourses = const [],
    this.completedCourses = 0,
    this.totalHours = 0,
    this.certificates = 0,
    this.streakCount = 0,
    this.lastActivityDate,
    this.badges = const [],
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    try {
      return AppUser(
        id: SafeParser.toStringSafe(json['id']),
        name: SafeParser.toStringSafe(json['name']),
        email: SafeParser.toStringSafe(json['email']),
        photoUrl: SafeParser.toStringSafe(json['photo_url']),
        bio: SafeParser.toStringSafe(json['bio']),
        enrolledCourses: SafeParser.toStringList(json['enrolled_courses']),
        completedCourses: SafeParser.toInt(json['completed_courses']),
        totalHours: SafeParser.toInt(json['total_hours']),
        certificates: SafeParser.toInt(json['certificates']),
        streakCount: SafeParser.toInt(json['streak_count']),
        lastActivityDate: SafeParser.toDateTime(json['last_activity_date']),
        badges: SafeParser.toStringList(json['badges']),
        createdAt: SafeParser.toDateTime(json['created_at']) ?? DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ AppUser.fromJson Error: $e. Data: $json');
      return AppUser(
        id: SafeParser.toStringSafe(json['id']),
        name: 'User',
        email: '',
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'photo_url': photoUrl,
      'bio': bio,
      'enrolled_courses': enrolledCourses,
      'completed_courses': completedCourses,
      'total_hours': totalHours,
      'certificates': certificates,
      'streak_count': streakCount,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'badges': badges,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isEnrolledIn(String courseId) {
    return enrolledCourses.contains(courseId);
  }
}
