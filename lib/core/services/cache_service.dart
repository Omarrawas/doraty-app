import 'package:flutter/foundation.dart';
import 'offline_cache_service.dart';

/// Service for caching data to reduce Supabase bandwidth usage
/// 
/// الباقة المجانية في Supabase:
/// - Bandwidth: 2 GB/شهر
/// - Database: 500 MB
/// - Storage: 1 GB
/// 
/// هذا الـ Service يساعد في توفير الـ Bandwidth من خلال:
/// 1. تخزين البيانات محلياً لفترة معينة
/// 2. عدم تحميل نفس البيانات مرتين
/// 3. مسح الـ Cache التلقائي عند انتهاء المدة
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
  /// يرجع null إذا:
  /// - المفتاح غير موجود
  /// - انتهت مدة صلاحية الـ Cache
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
    final count = _cache.length;
    _cache.clear();
    _cacheTimes.clear();
    debugPrint('🗑️ Cleared cache: $count items removed');
  }

  /// مسح الـ Cache المنتهية الصلاحية فقط
  void clearExpired({Duration? duration}) {
    final cacheDuration = duration ?? _defaultDuration;
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _cacheTimes.forEach((key, time) {
      if (now.difference(time) > cacheDuration) {
        keysToRemove.add(key);
      }
    });

    for (var key in keysToRemove) {
      _cache.remove(key);
      _cacheTimes.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('🗑️ Cleared expired cache: ${keysToRemove.length} items');
    }
  }

  /// إحصائيات الـ Cache
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final ages = _cacheTimes.values
        .map((time) => now.difference(time).inSeconds)
        .toList();

    final avgAge = ages.isEmpty ? 0 : ages.reduce((a, b) => a + b) / ages.length;

    return {
      'total_items': _cache.length,
      'average_age_seconds': avgAge.round(),
      'oldest_item_seconds': ages.isEmpty ? 0 : ages.reduce((a, b) => a > b ? a : b),
      'newest_item_seconds': ages.isEmpty ? 0 : ages.reduce((a, b) => a < b ? a : b),
    };
  }

  /// عرض معلومات الـ Cache (للتطوير)
  void printStats() {
    final stats = getStats();
    debugPrint('📊 Cache Stats:');
    debugPrint('  Total items: ${stats['total_items']}');
    debugPrint('  Average age: ${stats['average_age_seconds']}s');
    debugPrint('  Oldest: ${stats['oldest_item_seconds']}s');
    debugPrint('  Newest: ${stats['newest_item_seconds']}s');
  }
}

/// Helper functions لتسهيل الاستخدام

/// دالة مساعدة لجلب البيانات مع Cache
/// 
/// مثال:
/// ```dart
/// final courses = await fetchWithCache(
///   key: 'courses_page_0',
///   fetcher: () => dbService.getCourses(page: 0),
///   duration: Duration(minutes: 15),
/// );
/// ```
/// دالة مساعدة لجلب البيانات مع Cache (Persistent & Memory)
///
/// [forceRefresh]: إذا كان true، سيتم تجاهل الـ Cache وجلب البيانات من المصدر مباشرة
/// [staleWhileRevalidate]: إذا كان true، سيتم إرجاع البيانات المخزنة فوراً ثم تحديثها في الخلفية
Future<T> fetchWithCache<T>({
  required String key,
  required Future<T> Function() fetcher,
  Duration? duration,
  bool forceRefresh = false,
  bool staleWhileRevalidate = true,
}) async {
  final cache = CacheService();
  final offlineCache = OfflineCacheService();
  
  // 1. Check Memory Cache first (fastest)
  if (!forceRefresh) {
    final memoryCached = cache.get(key, duration: duration);
    if (memoryCached != null) {
      debugPrint('🚀 Memory Cache hit: $key');
      try {
        return memoryCached as T;
      } catch (e) {
        // Fallback for minified type issues in release/web
        if (memoryCached is List && T.toString().contains('List')) {
          return memoryCached as T; 
        }
        return memoryCached as T;
      }
    }

    // 2. Check Persistent Cache (Hive)
    try {
      final persistentCached = await offlineCache.getCachedUserData(key);
      if (persistentCached != null) {
        debugPrint('📦 Persistent Cache hit: $key');

        // If we found persistent data, we can return it and optionally refresh in background
        if (staleWhileRevalidate) {
          // Trigger background refresh
          _backgroundFetch(key, fetcher, duration);
        }

        // Save to memory cache for next time
        cache.set(key, persistentCached);
        
        // Defensive casting for Hive List/Map types (Fixes release-mode TypeErrors)
        if (persistentCached is List) {
          try {
            if (T.toString().contains('Map') || T.toString().contains('dynamic')) {
              return persistentCached.map((item) {
                if (item is Map) return Map<String, dynamic>.from(item);
                return item;
              }).toList() as T;
            }
          } catch (e) {
            debugPrint('⚠️ Casting list from cache failed: $e');
          }
        }
        
        return persistentCached as T;
      }
    } catch (e) {
      debugPrint('⚠️ Error reading persistent cache: $e');
    }
  }

  // 3. Fetch from source if not found or forced
  try {
    debugPrint('🌐 Fetching from source: $key');
    final data = await fetcher();

    // 4. Update both caches
    cache.set(key, data, duration: duration);
    await offlineCache.cacheUserData(key, data);

    return data;
  } catch (e) {
    debugPrint('❌ Network fetch failed for: $key ($e)');

    // 5. CRITICAL: On failure, search persistent cache AGAIN even if duration expired
    // but we only reach here if step 2 failed (expired/not found) or forceRefresh was true
    try {
      final fallbackData = await offlineCache.getCachedUserData(key);
      if (fallbackData != null) {
        debugPrint('📦 Fallback to persistent cache for: $key');
        return fallbackData as T;
      }
    } catch (_) {}

    // If no cache, rethrow relative to the original error
    rethrow;
  }
}

/// Helper for background fetching without blocking the UI
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

/// مفاتيح الـ Cache الشائعة
class CacheKeys {
  // الدورات
  static String courses({int page = 0}) => 'courses_page_$page';
  static String course(String id) => 'course_$id';
  static String courseLessons(String courseId) => 'course_${courseId}_lessons';
  
  // الدروس
  static String lesson(String id) => 'lesson_$id';
  static String lessonQuestions(String lessonId) => 'lesson_${lessonId}_questions';
  static String lessonNotes(String lessonId) => 'lesson_${lessonId}_notes';
  
  // الامتحانات
  static String exams({int page = 0}) => 'exams_page_$page';
  static String exam(String id) => 'exam_$id';
  static String examQuestions(String examId) => 'exam_${examId}_questions';
  
  // الاشتراكات
  static String subscriptionPlans = 'subscription_plans';
  static String userSubscription(String userId) => 'user_${userId}_subscription';
  
  // حسابات الدفع
  static String paymentAccounts = 'payment_accounts';
  
  // المستخدم
  static String userProfile(String userId) => 'user_${userId}_profile';
  static String userCourses(String userId) => 'user_${userId}_courses';
  static String teachers = 'teachers_list';
  static String featuredCourses = 'featured_courses_banner';
}
