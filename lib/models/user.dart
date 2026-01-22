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
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      photoUrl: json['photo_url'],
      bio: json['bio'],
      enrolledCourses: List<String>.from(json['enrolled_courses'] ?? []),
      completedCourses: json['completed_courses'] ?? 0,
      totalHours: json['total_hours'] ?? 0,
      certificates: json['certificates'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
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
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isEnrolledIn(String courseId) {
    return enrolledCourses.contains(courseId);
  }
}
