import 'package:hive_flutter/hive_flutter.dart';
import '../../models/course.dart';
import '../../models/lesson.dart';

class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  // Hive boxes for different data types
  Box<Map>? _coursesBox;
  Box<Map>? _lessonsBox;
  Box<Map>? _userDataBox;
  Box<Map>? _offlineActionsBox;
  Box<Map>? _metadataBox;

  // Cache expiry times (in milliseconds)
  static const int courseCacheDuration = 24 * 60 * 60 * 1000; // 24 hours
  static const int lessonCacheDuration = 7 * 24 * 60 * 60 * 1000; // 7 days
  static const int userDataCacheDuration = 60 * 60 * 1000; // 1 hour

  Future<void> init() async {
    _coursesBox = await Hive.openBox<Map>('courses_cache');
    _lessonsBox = await Hive.openBox<Map>('lessons_cache');
    _userDataBox = await Hive.openBox<Map>('user_data_cache');
    _offlineActionsBox = await Hive.openBox<Map>('offline_actions');
    _metadataBox = await Hive.openBox<Map>('cache_metadata');
  }

  // ==================== COURSES CACHE ====================

  Future<void> cacheCourses(List<Course> courses) async {
    if (_coursesBox == null) return;

    final coursesMap = <String, Map>{};
    for (final course in courses) {
      coursesMap[course.id] = {
        'data': course.toJson(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().millisecondsSinceEpoch + courseCacheDuration,
      };
    }

    await _coursesBox!.putAll(coursesMap);
  }

  Future<List<Course>?> getCachedCourses() async {
    if (_coursesBox == null) return null;

    final courses = <Course>[];
    for (final entry in _coursesBox!.values) {
      final expiresAt = entry['expires_at'] as int?;
      final courseDataRaw = entry['data'];

      if (expiresAt != null &&
          DateTime.now().millisecondsSinceEpoch < expiresAt &&
          courseDataRaw != null) {
        final courseData = Map<String, dynamic>.from(courseDataRaw as Map);
        courses.add(Course.fromJson(courseData));
      }
    }

    return courses.isNotEmpty ? courses : null;
  }

  Future<bool> hasValidCoursesCache() async {
    if (_coursesBox == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in _coursesBox!.values) {
      final cachedData = entry;
      final expiresAt = cachedData['expires_at'] as int;
      if (now < expiresAt) return true;
    }
    return false;
  }

  // ==================== ENROLLED COURSES CACHE ====================

  Future<void> cacheEnrolledCourses(
      List<Map<String, dynamic>> enrollments) async {
    if (_coursesBox == null) return;

    // Use a special key for enrollments list
    await _coursesBox!.put('enrolled_courses_list', {
      'data': enrollments,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'expires_at': DateTime.now().millisecondsSinceEpoch + courseCacheDuration,
    });
  }

  Future<List<Map<String, dynamic>>?> getCachedEnrolledCourses() async {
    if (_coursesBox == null) return null;

    final cachedEntry = _coursesBox!.get('enrolled_courses_list');
    if (cachedEntry == null) return null;

    // Check expiry
    final expiresAt = cachedEntry['expires_at'] as int?;
    if (expiresAt != null &&
        DateTime.now().millisecondsSinceEpoch < expiresAt) {
      final List<dynamic> data = cachedEntry['data'];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return null;
  }

  // ==================== LESSONS CACHE ====================

  Future<void> cacheLessons(String courseId, List<Lesson> lessons) async {
    if (_lessonsBox == null) return;

    final lessonsMap = <String, Map>{};
    for (final lesson in lessons) {
      lessonsMap['${courseId}_${lesson.id}'] = {
        'data': lesson.toJson(),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'expires_at':
            DateTime.now().millisecondsSinceEpoch + lessonCacheDuration,
      };
    }

    await _lessonsBox!.putAll(lessonsMap);
  }

  Future<List<Lesson>?> getCachedLessons(String courseId) async {
    if (_lessonsBox == null) return null;

    final lessons = <Lesson>[];
    final prefix = '${courseId}_';

    for (final key in _lessonsBox!.keys) {
      if (key.toString().startsWith(prefix)) {
        final cachedData = _lessonsBox!.get(key);
        if (cachedData != null) {
          final expiresAt = cachedData['expires_at'] as int;

          if (DateTime.now().millisecondsSinceEpoch < expiresAt) {
            final lessonData =
                Map<String, dynamic>.from(cachedData['data'] as Map);
            lessons.add(Lesson.fromJson(lessonData));
          }
        }
      }
    }

    return lessons.isNotEmpty ? lessons : null;
  }

  // ==================== USER DATA CACHE ====================

  Future<void> cacheUserData(String key, dynamic data) async {
    if (_userDataBox == null) return;

    await _userDataBox!.put(key, {
      'data': data,
      'cached_at': DateTime.now().millisecondsSinceEpoch,
      'expires_at':
          DateTime.now().millisecondsSinceEpoch + userDataCacheDuration,
    });
  }

  Future<dynamic> getCachedUserData(String key) async {
    if (_userDataBox == null) return null;

    final cached = _userDataBox!.get(key);
    if (cached == null) return null;

    final cachedData = cached;
    final expiresAt = cachedData['expires_at'] as int;

    if (DateTime.now().millisecondsSinceEpoch < expiresAt) {
      return cachedData['data'];
    }

    // Remove expired data
    await _userDataBox!.delete(key);
    return null;
  }

  // ==================== OFFLINE ACTIONS ====================

  Future<void> queueOfflineAction(
      String actionId, Map<String, dynamic> action) async {
    if (_offlineActionsBox == null) return;

    await _offlineActionsBox!.put(actionId, {
      'action': action,
      'queued_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineActions() async {
    if (_offlineActionsBox == null) return [];

    final actions = <Map<String, dynamic>>[];
    for (final entry in _offlineActionsBox!.values) {
      final actionData = Map<String, dynamic>.from(entry);
      if (actionData['status'] == 'pending') {
        actions.add(actionData);
      }
    }
    return actions;
  }

  Future<void> markOfflineActionCompleted(String actionId) async {
    if (_offlineActionsBox == null) return;

    final action = _offlineActionsBox!.get(actionId);
    if (action != null) {
      final updatedAction = Map<String, dynamic>.from(action);
      updatedAction['status'] = 'completed';
      updatedAction['completed_at'] = DateTime.now().millisecondsSinceEpoch;

      await _offlineActionsBox!.put(actionId, updatedAction);
    }
  }

  Future<void> markOfflineActionFailed(String actionId, String error) async {
    if (_offlineActionsBox == null) return;

    final action = _offlineActionsBox!.get(actionId);
    if (action != null) {
      final updatedAction = Map<String, dynamic>.from(action);
      updatedAction['status'] = 'failed';
      updatedAction['error'] = error;
      updatedAction['failed_at'] = DateTime.now().millisecondsSinceEpoch;

      await _offlineActionsBox!.put(actionId, updatedAction);
    }
  }

  // ==================== CACHE MANAGEMENT ====================

  Future<void> clearExpiredCache() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Clear expired courses
    if (_coursesBox != null) {
      final expiredCourses = <String>[];
      for (final key in _coursesBox!.keys) {
        final cachedData = _coursesBox!.get(key);
        if (cachedData != null) {
          final expiresAt = cachedData['expires_at'] as int;
          if (now >= expiresAt) {
            expiredCourses.add(key.toString());
          }
        }
      }
      await _coursesBox!.deleteAll(expiredCourses);
    }

    // Clear expired lessons
    if (_lessonsBox != null) {
      final expiredLessons = <String>[];
      for (final key in _lessonsBox!.keys) {
        final cachedData = _lessonsBox!.get(key);
        if (cachedData != null) {
          final expiresAt = cachedData['expires_at'] as int;
          if (now >= expiresAt) {
            expiredLessons.add(key.toString());
          }
        }
      }
      await _lessonsBox!.deleteAll(expiredLessons);
    }

    // Clear expired user data
    if (_userDataBox != null) {
      final expiredUserData = <String>[];
      for (final key in _userDataBox!.keys) {
        final cachedData = _userDataBox!.get(key);
        if (cachedData != null) {
          final expiresAt = cachedData['expires_at'] as int;
          if (now >= expiresAt) {
            expiredUserData.add(key.toString());
          }
        }
      }
      await _userDataBox!.deleteAll(expiredUserData);
    }
  }

  Future<void> clearAllCache() async {
    await _coursesBox?.clear();
    await _lessonsBox?.clear();
    await _userDataBox?.clear();
    await _offlineActionsBox?.clear();
    await _metadataBox?.clear();
  }

  Future<Map<String, dynamic>> getCacheStats() async {
    return {
      'courses_count': _coursesBox?.length ?? 0,
      'lessons_count': _lessonsBox?.length ?? 0,
      'user_data_count': _userDataBox?.length ?? 0,
      'offline_actions_count': _offlineActionsBox?.length ?? 0,
      'cache_size_mb': await _calculateCacheSize(),
    };
  }

  Future<double> _calculateCacheSize() async {
    // Rough estimation - each entry ~1KB
    final totalEntries = (_coursesBox?.length ?? 0) +
        (_lessonsBox?.length ?? 0) +
        (_userDataBox?.length ?? 0) +
        (_offlineActionsBox?.length ?? 0);
    return totalEntries * 1024 / (1024 * 1024); // Convert to MB
  }

  // ==================== SYNC MANAGEMENT ====================

  Future<void> setLastSyncTime(String dataType) async {
    if (_metadataBox == null) return;

    await _metadataBox!.put('last_sync_$dataType', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int?> getLastSyncTime(String dataType) async {
    if (_metadataBox == null) return null;

    final data = _metadataBox!.get('last_sync_$dataType');
    if (data != null) {
      return data['timestamp'] as int;
    }
    return null;
  }

  Future<bool> shouldSync(String dataType, int syncIntervalMs) async {
    final lastSync = await getLastSyncTime(dataType);
    if (lastSync == null) return true;

    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSync) > syncIntervalMs;
  }

  void dispose() {
    _coursesBox?.close();
    _lessonsBox?.close();
    _userDataBox?.close();
    _offlineActionsBox?.close();
    _metadataBox?.close();
  }
}
