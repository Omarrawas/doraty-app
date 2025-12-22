import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'offline_cache_service.dart';
import '../../models/course.dart';
import '../../models/lesson.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final OfflineCacheService _cacheService = OfflineCacheService();

  final bool _isOnline =
      true; // Assume online for now - can be improved with connectivity check
  Timer? _syncTimer;

  // Sync intervals (in milliseconds)
  // Sync intervals (in milliseconds)
  static const int coursesSyncInterval = 6 * 60 * 60 * 1000; // 6 hours
  static const int lessonsSyncInterval = 24 * 60 * 60 * 1000; // 24 hours
  static const int userDataSyncInterval = 30 * 60 * 1000; // 30 minutes

  Future<void> init() async {
    // Initialize cache service
    await _cacheService.init();

    // Start periodic sync
    _startPeriodicSync();
    await performFullSync();
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        performIncrementalSync();
      }
    });
  }

  // ==================== FULL SYNC ====================

  Future<void> performFullSync() async {
    if (!_isOnline) return;

    try {
      debugPrint('🔄 Starting full sync...');

      // Sync offline actions first
      await _syncOfflineActions();

      // Sync courses
      await _syncCourses();

      // Sync user enrolled courses and lessons
      await _syncUserCourses();

      // Sync user data
      await _syncUserData();

      debugPrint('✅ Full sync completed');
    } catch (e) {
      debugPrint('❌ Full sync failed: $e');
    }
  }

  // ==================== INCREMENTAL SYNC ====================

  Future<void> performIncrementalSync() async {
    if (!_isOnline) return;

    try {
      // Check what needs syncing
      // Check what needs syncing
      final shouldSyncCourses =
          await _cacheService.shouldSync('courses', coursesSyncInterval);
      final shouldSyncLessons =
          await _cacheService.shouldSync('lessons', lessonsSyncInterval);
      final shouldSyncUserData =
          await _cacheService.shouldSync('user_data', userDataSyncInterval);

      if (shouldSyncCourses) {
        await _syncCourses();
      }

      if (shouldSyncLessons) {
        await _syncUserCourses();
      }

      if (shouldSyncUserData) {
        await _syncUserData();
      }

      // Always sync offline actions
      await _syncOfflineActions();
    } catch (e) {
      debugPrint('❌ Incremental sync failed: $e');
    }
  }

  // ==================== COURSES SYNC ====================

  Future<void> _syncCourses() async {
    try {
      debugPrint('📚 Syncing courses...');

      // Fetch latest courses from server
      // Fetch latest courses from server
      final serverCourses = await _databaseService.getCourses();

      // Convert to Course objects
      final courses = serverCourses.map((c) => Course.fromJson(c)).toList();

      // Cache the courses
      await _cacheService.cacheCourses(courses);

      // Update sync time
      await _cacheService.setLastSyncTime('courses');

      debugPrint('✅ Courses synced: ${courses.length} courses');
    } catch (e) {
      debugPrint('❌ Courses sync failed: $e');
    }
  }

  // ==================== USER COURSES SYNC ====================

  Future<void> _syncUserCourses() async {
    try {
      debugPrint('📖 Syncing user courses and lessons...');

      // Get enrolled courses
      // Get enrolled courses
      final enrolledCourses =
          await _databaseService.getEnrolledCoursesWithProgress();

      for (final enrollment in enrolledCourses) {
        final courseData = enrollment['courses'] as Map<String, dynamic>;
        final courseId = courseData['id'] as String;

        // Cache course data
        final course = Course.fromJson(courseData);
        await _cacheService.cacheCourses([course]);

        // Sync lessons for this course
        await _syncLessonsForCourse(courseId);
      }

      await _cacheService.setLastSyncTime('lessons');
      debugPrint('✅ User courses synced');
    } catch (e) {
      debugPrint('❌ User courses sync failed: $e');
    }
  }

  Future<void> _syncLessonsForCourse(String courseId) async {
    try {
      final serverLessons = await _databaseService.getLessons(courseId);

      // Convert to Lesson objects
      final lessons = serverLessons.map((l) => Lesson.fromJson(l)).toList();

      // Cache the lessons
      await _cacheService.cacheLessons(courseId, lessons);

      debugPrint(
          '✅ Lessons synced for course $courseId: ${lessons.length} lessons');
    } catch (e) {
      debugPrint('❌ Lessons sync failed for course $courseId: $e');
    }
  }

  // ==================== USER DATA SYNC ====================

  Future<void> _syncUserData() async {
    try {
      debugPrint('👤 Syncing user data...');

      // Sync user profile
      // Sync user profile
      final userProfile = await _databaseService.getUserProfile('current');
      await _cacheService.cacheUserData('user_profile', userProfile);

      // Sync user stats
      final userStats = await _databaseService.getUserStats();
      await _cacheService.cacheUserData('user_stats', userStats);

      // Sync notifications
      final notifications = await _databaseService.getNotifications();
      await _cacheService.cacheUserData('notifications', notifications);

      await _cacheService.setLastSyncTime('user_data');
      debugPrint('✅ User data synced');
    } catch (e) {
      debugPrint('❌ User data sync failed: $e');
    }
  }

  // ==================== OFFLINE ACTIONS SYNC ====================

  Future<void> _syncOfflineActions() async {
    try {
      final pendingActions = await _cacheService.getPendingOfflineActions();

      for (final actionData in pendingActions) {
        final actionId = actionData['action_id'] as String? ?? 'unknown';
        final action = actionData['action'] as Map<String, dynamic>;

        try {
          await _executeOfflineAction(action);
          await _cacheService.markOfflineActionCompleted(actionId);
          debugPrint('✅ Offline action completed: $actionId');
        } catch (e) {
          await _cacheService.markOfflineActionFailed(actionId, e.toString());
          debugPrint('❌ Offline action failed: $actionId - $e');
        }
      }
    } catch (e) {
      debugPrint('❌ Offline actions sync failed: $e');
    }
  }

  Future<void> _executeOfflineAction(Map<String, dynamic> action) async {
    final actionType = action['type'] as String;

    switch (actionType) {
      case 'create_note':
        await _databaseService.createNote(
          lessonId: action['lesson_id'],
          courseId: action['course_id'] ?? '', // Fallback or ensure it's provided
          title: action['title'] ?? 'ملاحظة', // Fallback
          content: action['content'],
          timestamp: action['timestamp'],
        );
        break;

      case 'update_note':
        await _databaseService.updateNote(action['note_id'], action['content']);
        break;

      case 'delete_note':
        await _databaseService.deleteNote(action['note_id']);
        break;

      case 'update_progress':
        await _databaseService.updateLessonProgress(
          lessonId: action['lesson_id'],
          watchTime: action['watch_time'],
          lastPosition: action['last_position'],
          isCompleted: action['is_completed'],
        );
        break;

      case 'add_bookmark':
        await _databaseService.saveBookmark(
          lessonId: action['lesson_id'],
          title: action['title'],
          timestamp: action['timestamp'],
          note: action['note'],
        );
        break;

      case 'delete_bookmark':
        await _databaseService.deleteBookmark(action['bookmark_id']);
        break;

      case 'add_review':
        await _databaseService.addReview(
          courseId: action['course_id'],
          rating: action['rating'],
          comment: action['comment'],
        );
        break;

      case 'enroll_course':
        await _databaseService.enrollInCourse(action['course_id']);
        break;

      case 'unenroll_course':
        await _databaseService.unenrollFromCourse(action['course_id']);
        break;

      default:
        throw Exception('Unknown action type: $actionType');
    }
  }

  // ==================== PUBLIC API ====================

  /// Queue an action to be executed when online
  Future<void> queueOfflineAction(
      String actionId, Map<String, dynamic> action) async {
    await _cacheService.queueOfflineAction(actionId, action);

    // If online, try to execute immediately
    if (_isOnline) {
      try {
        await _executeOfflineAction(action);
        await _cacheService.markOfflineActionCompleted(actionId);
      } catch (e) {
        // If immediate execution fails, it will be retried later
        debugPrint('Immediate action execution failed, will retry later: $e');
      }
    }
  }

  /// Get cached data with fallback to server if online
  Future<List<Course>?> getCourses({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedCourses();
      if (cached != null) return cached;
    }

    if (_isOnline) {
      await _syncCourses();
      return _cacheService.getCachedCourses();
    }

    return null;
  }

  /// Get cached lessons with fallback to server if online
  Future<List<Lesson>?> getLessons(String courseId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _cacheService.getCachedLessons(courseId);
      if (cached != null) return cached;
    }

    if (_isOnline) {
      await _syncLessonsForCourse(courseId);
      return _cacheService.getCachedLessons(courseId);
    }

    return null;
  }

  /// Get cached user data
  Future<dynamic> getUserData(String key) async {
    final cached = await _cacheService.getCachedUserData(key);
    if (cached != null) return cached;

    if (_isOnline) {
      await _syncUserData();
      return _cacheService.getCachedUserData(key);
    }

    return null;
  }

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (_isOnline) {
      await performFullSync();
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _cacheService.clearAllCache();
  }

  /// Clear expired cache entries
  Future<void> clearExpiredCache() async {
    await _cacheService.clearExpiredCache();
  }

  void dispose() {
    _syncTimer?.cancel();
    _cacheService.dispose();
  }
}
