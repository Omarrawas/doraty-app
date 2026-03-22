import 'local_database.dart';

/// Main fetch helper using LocalDatabase (Hive)
Future<T> fetchWithCache<T>({
  required String key,
  required Future<T> Function() fetcher,
  Duration? duration,
  bool forceRefresh = false,
  bool staleWhileRevalidate = true, // We ignore this as LocalDatabase handles it implicitly
}) async {
  return LocalDatabase().localFirst<T>(
    key: key,
    fetcher: fetcher,
    maxAge: duration ?? const Duration(minutes: 30),
    forceRefresh: forceRefresh,
  );
}

/// Cache keys constants
class CacheKeys {
  static String courses({int page = 0}) => 'courses_page_$page';
  static String course(String id) => 'course_$id';
  static String coursesV2({
    String? categoryId,
    String? teacherId,
    String? level,
    String? query,
    bool? isFree,
  }) {
    return 'courses_v2_${categoryId ?? "all"}_${teacherId ?? "all"}_${level ?? "all"}_${query ?? "all"}_${isFree ?? "false"}';
  }
  static String userEnrolledIds(String userId) => 'user_${userId}_enrolled_ids';
  static String userEnrollments(String userId) => 'user_${userId}_enrollments_v2';
  static String teachers = 'teachers_list';
  static String featuredCourses = 'featured_courses_banner';
  static String categories = 'categories_all';
  static String systemStats = 'system_stats_all';
  static String teacherStats(String id) => 'teacher_stats_$id';
  static String userProfile(String userId) => 'user_profile_$userId';
  static String userStats(String userId) => 'user_stats_$userId';
  static String tips = 'tips_all';
  static String banners = 'banners_all';
}
