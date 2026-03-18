import 'package:flutter/foundation.dart';
import 'offline_cache_service.dart';

/// Service for caching data to reduce Supabase bandwidth usage
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache للدورات
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimes = {};
  
  // مدة الـ Cache (افتراضياً 30 دقيقة)
  final Duration _defaultDuration = const Duration(minutes: 30);

  /// حفظ بيانات في الـ Cache
  void set(String key, dynamic data, {Duration? duration}) {
    _cache[key] = data;
    _cacheTimes[key] = DateTime.now();
    debugPrint('📦 Cached: $key');
  }

  /// جلب بيانات من الـ Cache
  dynamic get(String key, {Duration? duration}) {
    if (!_cache.containsKey(key)) {
      debugPrint('❌ Cache miss: $key');
      return null;
    }

    final cacheTime = _cacheTimes[key];
    if (cacheTime == null) {
      debugPrint('❌ No cache time for: $key');
      return null;
    }

    final cacheDuration = duration ?? _defaultDuration;
    final age = DateTime.now().difference(cacheTime);
    
    if (age > cacheDuration) {
      debugPrint('⏰ Cache expired: $key (age: ${age.inMinutes}m)');
      _cache.remove(key);
      _cacheTimes.remove(key);
      return null;
    }

    debugPrint('✅ Cache hit: $key (age: ${age.inSeconds}s)');
    return _cache[key];
  }

  /// التحقق من وجود مفتاح في الـ Cache وصلاحيته
  bool has(String key, {Duration? duration}) {
    return get(key, duration: duration) != null;
  }

  /// مسح عنصر واحد من الـ Cache
  void remove(String key) {
    _cache.remove(key);
    _cacheTimes.remove(key);
    debugPrint('🗑️ Removed from cache: $key');
  }

  /// مسح كل الـ Cache
  void clear() {
    _cache.clear();
    _cacheTimes.clear();
    debugPrint('🗑️ Cleared cache');
  }
}

/// Helper for robust type casting (especially for Web minified builds)
T _safeCast<T>(dynamic data) {
  try {
    // 1. Direct match
    if (data is T) return data;

    final typeStr = T.toString();

    // 2. Handle List of Maps (Common in Supabase)
    if (typeStr.contains('List<Map<String, dynamic>>')) {
      if (data is List) {
        final casted = data.map((item) {
          if (item is Map) return Map<String, dynamic>.from(item);
          return item;
        }).toList().cast<Map<String, dynamic>>();
        return casted as T;
      }
    }

    // 3. Handle Single Map
    if (typeStr.contains('Map<String, dynamic>')) {
      if (data is Map) {
        return Map<String, dynamic>.from(data) as T;
      }
    }

    // 4. Handle List/Set of Strings
    if (typeStr.contains('List<String>') || typeStr.contains('Set<String>')) {
      if (data is Iterable) {
        final list = data.map((e) => e.toString()).toList();
        if (typeStr.contains('Set')) return list.toSet() as T;
        return list as T;
      }
    }

    // 5. Fallback for primitives or untracked types
    return data as T;
  } catch (e) {
    debugPrint('🚨 SafeCast failed for type $T: $e');
    return data as T;
  }
}

/// Background fetching helper
void _backgroundFetch<T>(
    String key, Future<T> Function() fetcher, Duration? duration) async {
  try {
    debugPrint('🔄 Background refreshing: $key');
    final data = await fetcher();
    CacheService().set(key, data, duration: duration);
    await OfflineCacheService().cacheUserData(key, data);
    debugPrint('✅ Background refresh complete: $key');
  } catch (e) {
    debugPrint('❌ Background refresh failed: $key ($e)');
  }
}

/// Main fetch helper with Cache
Future<T> fetchWithCache<T>({
  required String key,
  required Future<T> Function() fetcher,
  Duration? duration,
  bool forceRefresh = false,
  bool staleWhileRevalidate = true,
}) async {
  final cache = CacheService();
  final offlineCache = OfflineCacheService();
  
  // 1. Check Memory Cache
  if (!forceRefresh) {
    final memoryCached = cache.get(key, duration: duration);
    if (memoryCached != null) {
      debugPrint('🚀 Memory Cache hit: $key');
      try {
        return _safeCast<T>(memoryCached);
      } catch (e) {
        debugPrint('⚠️ Memory cast failed: $e');
      }
    }

    // 2. Check Persistent Cache
    try {
      final persistentCached = await offlineCache.getCachedUserData(key);
      if (persistentCached != null) {
        debugPrint('📦 Persistent Cache hit: $key');

        if (staleWhileRevalidate) {
          _backgroundFetch<T>(key, fetcher, duration);
        }

        cache.set(key, persistentCached);
        return _safeCast<T>(persistentCached);
      }
    } catch (e) {
      debugPrint('⚠️ Persistent cache error: $e');
    }
  }

  // 3. Fetch from source
  try {
    debugPrint('🌐 Fetching from source: $key');
    final data = await fetcher();

    cache.set(key, data, duration: duration);
    await offlineCache.cacheUserData(key, data);

    return data;
  } catch (e) {
    debugPrint('❌ Fetch failed for $key: $e');
    
    // Final fallback to any persistent data even if expired
    try {
      final fallbackData = await offlineCache.getCachedUserData(key);
      if (fallbackData != null) return _safeCast<T>(fallbackData);
    } catch (_) {}
    
    rethrow;
  }
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
}
