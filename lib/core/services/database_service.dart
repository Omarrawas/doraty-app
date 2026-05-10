import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import '../../models/chapter.dart';
import '../../models/payment_account.dart';
import 'cache_service.dart';
import 'local_database.dart';
import '../utils/safe_parser.dart';
import '../../models/course.dart';
import 'image_upload_service.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService instance = DatabaseService._internal();

  factory DatabaseService() {
    return instance;
  }

  DatabaseService._internal();

  SupabaseClient get _client => SupabaseService.instance.client;

  // Getter for accessing the client from other classes
  SupabaseClient get supabaseClient => _client;
  SupabaseClient get client => _client;

  // Quick access to current user ID safely
  String? get currentUserId => SupabaseService.instance.currentUserId;

  // Helper to check if a string is a valid UUID
  bool _isUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    return RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            caseSensitive: false)
        .hasMatch(id);
  }

  /// Helper to ensure avatar URLs are full URLs
  String? _formatAvatarUrl(String? avatarUrl, {String? userId}) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    // If it's already a full URL or a data URI, return it
    if (avatarUrl.startsWith('http') || avatarUrl.startsWith('data:')) {
      return avatarUrl;
    }

    // If it's a relative path, assume it's in the old Supabase storage 'avatars' bucket
    final baseUrl =
        'https://cstlqyjoflhxtocrtypg.supabase.co/storage/v1/object/public/avatars/';
    return '$baseUrl$avatarUrl';
  }

  // ==================== CATEGORIES (NEW) ====================
  // Added CRUD for admin management

  Future<List<Map<String, dynamic>>> getCategories(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'categories_all',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          final response =
              await _client.from('categories').select().order('name');
          return SafeParser.safeMapList(response);
        } catch (e) {
          debugPrint('Error getting categories: $e');
          return [];
        }
      },
    );
  }

  /// Get subcategories for a parent category
  Future<List<Map<String, dynamic>>> getSubCategories(String parentId) async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq('parent_id', parentId)
          .order('name');
      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting subcategories: $e');
      return [];
    }
  }

  /// Get a category by its slug or ID
  Future<Map<String, dynamic>?> getCategoryBySlugOrId(String value) async {
    try {
      final response = await _client
          .from('categories')
          .select()
          .eq(_isUuid(value) ? 'id' : 'slug', value)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting category by slug/id: $e');
      return null;
    }
  }

  /// Get subcategory IDs for a parent ID
  Future<List<String>> getSubCategoryIds(String parentId) async {
    try {
      final response = await _client
          .from('categories')
          .select('id')
          .eq('parent_id', parentId);
      return (response as List).map((e) => e['id'] as String).toList();
    } catch (e) {
      debugPrint('Error getting subcategory IDs: $e');
      return [];
    }
  }

  /// Check if a course slug is unique
  Future<bool> isCourseSlugUnique(String slug, {String? excludeId}) async {
    try {
      var query = _client.from('courses').select('id').eq('slug', slug);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final response = await query.maybeSingle();
      return response == null;
    } catch (e) {
      debugPrint('Error checking course slug uniqueness: $e');
      return true;
    }
  }

  /// Check if a lesson slug is unique
  Future<bool> isLessonSlugUnique(String slug, {String? excludeId}) async {
    try {
      var query = _client.from('lessons').select('id').eq('slug', slug);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final response = await query.maybeSingle();
      return response == null;
    } catch (e) {
      debugPrint('Error checking lesson slug uniqueness: $e');
      return true;
    }
  }

  /// Check if a category slug is unique
  Future<bool> isCategorySlugUnique(String slug, {String? excludeId}) async {
    try {
      var query = _client.from('categories').select('id').eq('slug', slug);
      if (excludeId != null) {
        query = query.neq('id', excludeId);
      }
      final response = await query.maybeSingle();
      return response == null;
    } catch (e) {
      debugPrint('Error checking category slug uniqueness: $e');
      return true;
    }
  }

  /// Create a new category
  Future<void> createCategory({
    required String name,
    required String slug,
    String? parentId,
    String? iconUrl,
  }) async {
    try {
      // Ensure unique slug
      String finalSlug = slug;
      if (finalSlug.isEmpty) {
        finalSlug = name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
      }
      if (finalSlug.isEmpty) {
        finalSlug = 'cat-${DateTime.now().millisecondsSinceEpoch}';
      }

      int suffix = 1;
      while (!(await isCategorySlugUnique(finalSlug))) {
        finalSlug = '$slug-${suffix++}';
      }

      await _client.from('categories').insert({
        'name': name,
        'slug': finalSlug,
        'parent_id': parentId,
        'icon_url': iconUrl,
      });
      await LocalDatabase().remove(CacheKeys.categories);
    } catch (e) {
      debugPrint('Error creating category: $e');
      rethrow;
    }
  }

  /// Update a category
  Future<void> updateCategory({
    required String id,
    String? name,
    String? slug,
    String? parentId,
    String? iconUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;

      if (slug != null && slug.isNotEmpty) {
        String finalSlug = slug;
        int suffix = 1;
        while (!(await isCategorySlugUnique(finalSlug, excludeId: id))) {
          finalSlug = '$slug-${suffix++}';
        }
        updates['slug'] = finalSlug;
      } else if (slug != null && slug.isEmpty && name != null) {
        // Generate from name if slug is being cleared
        String baseSlug = name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), '');
        if (baseSlug.isEmpty) {
          baseSlug = 'cat-${DateTime.now().millisecondsSinceEpoch}';
        }

        String finalSlug = baseSlug;
        int suffix = 1;
        while (!(await isCategorySlugUnique(finalSlug, excludeId: id))) {
          finalSlug = '$baseSlug-${suffix++}';
        }
        updates['slug'] = finalSlug;
      }

      // Explicitly check for parentId to allow null (removing parent)
      if (parentId != null) {
        updates['parent_id'] = parentId.isEmpty ? null : parentId;
      }

      if (iconUrl != null) updates['icon_url'] = iconUrl;

      if (updates.isNotEmpty) {
        await _client.from('categories').update(updates).eq('id', id);
        await LocalDatabase().remove(CacheKeys.categories);
      }
    } catch (e) {
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  /// Delete a category
  Future<void> deleteCategory(String id) async {
    try {
      await _client.from('categories').delete().eq('id', id);
      await LocalDatabase().remove(CacheKeys.categories);
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // ==================== BUNDLES (NEW) ====================

  /// Get all bundles with their associated courses
  Future<List<Map<String, dynamic>>> getBundles(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'bundles_all',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // Fetch bundles
          final response = await _client
              .from('bundles')
              .select()
              .order('created_at', ascending: false);
          final List<Map<String, dynamic>> bundles =
              SafeParser.safeMapList(response);

          // For each bundle, fetch course IDs and full course details
          final List<Map<String, dynamic>> enrichedBundles = [];
          for (var bundle in bundles) {
            final bundleCoursesResponse = await _client
                .from('bundle_courses')
                .select('course_id')
                .eq('bundle_id', bundle['id']);

            final List<String> courseIds = (bundleCoursesResponse as List)
                .map((e) => e['course_id'] as String)
                .toList();

            // Fetch the actual courses (limit to relevant fields)
            final coursesResponse = await _client
                .from('courses')
                .select()
                .inFilter('id', courseIds);

            bundle['courses'] = coursesResponse;
            enrichedBundles.add(bundle);
          }
          return enrichedBundles;
        } catch (e) {
          debugPrint('Error getting bundles: $e');
          return [];
        }
      },
    );
  }

  /// Create a new bundle and link it to courses
  Future<void> createBundle({
    required String title,
    String? description,
    String? imageUrl,
    required double price,
    int discountPercentage = 0,
    required List<String> courseIds,
  }) async {
    try {
      final response = await _client
          .from('bundles')
          .insert({
            'title': title,
            'description': description,
            'image_url': imageUrl,
            'price': price,
            'discount_percentage': discountPercentage,
          })
          .select()
          .single();

      final String bundleId = response['id'];

      if (courseIds.isNotEmpty) {
        final links = courseIds
            .map((cid) => {
                  'bundle_id': bundleId,
                  'course_id': cid,
                })
            .toList();
        await _client.from('bundle_courses').insert(links);
      }

      // Clear cache
      await LocalDatabase().remove('bundles_all');
    } catch (e) {
      debugPrint('Error creating bundle: $e');
      rethrow;
    }
  }

  /// Update an existing bundle and its course links
  Future<void> updateBundle({
    required String id,
    String? title,
    String? description,
    String? imageUrl,
    double? price,
    int? discountPercentage,
    List<String>? courseIds,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (price != null) updates['price'] = price;
      if (discountPercentage != null) {
        updates['discount_percentage'] = discountPercentage;
      }

      if (updates.isNotEmpty) {
        await _client.from('bundles').update(updates).eq('id', id);
      }

      if (courseIds != null) {
        // Replace links: delete and re-insert
        await _client.from('bundle_courses').delete().eq('bundle_id', id);
        if (courseIds.isNotEmpty) {
          final links = courseIds
              .map((cid) => {
                    'bundle_id': id,
                    'course_id': cid,
                  })
              .toList();
          await _client.from('bundle_courses').insert(links);
        }
      }

      // Clear cache
      await LocalDatabase().remove('bundles_all');
    } catch (e) {
      debugPrint('Error updating bundle: $e');
      rethrow;
    }
  }

  /// Delete a bundle
  Future<void> deleteBundle(String id) async {
    try {
      await _client.from('bundles').delete().eq('id', id);
      // Clear cache
      await LocalDatabase().remove('bundles_all');
    } catch (e) {
      debugPrint('Error deleting bundle: $e');
      rethrow;
    }
  }

  /// Get bundles that contain courses by a specific teacher
  Future<List<Map<String, dynamic>>> getBundlesByTeacherId(
      String teacherId) async {
    try {
      // 1. Get IDs of courses owned by this teacher
      final coursesResponse = await _client
          .from('courses')
          .select('id')
          .eq('instructor_id', teacherId);

      final List<String> teacherCourseIds =
          (coursesResponse as List).map((c) => c['id'] as String).toList();

      if (teacherCourseIds.isEmpty) return [];

      // 2. Find bundle IDs that contain these courses
      final bundleCoursesResponse = await _client
          .from('bundle_courses')
          .select('bundle_id')
          .inFilter('course_id', teacherCourseIds);

      final List<String> bundleIds = (bundleCoursesResponse as List)
          .map((bc) => bc['bundle_id'] as String)
          .toSet()
          .toList();

      if (bundleIds.isEmpty) return [];

      // 3. Fetch these specific bundles. Filter by non-null IDs.
      final List<String> cleanBundleIds =
          bundleIds.where((id) => id.isNotEmpty).toList();
      if (cleanBundleIds.isEmpty) return [];

      final response = await _client
          .from('bundles')
          .select()
          .inFilter('id', cleanBundleIds)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> bundles =
          SafeParser.safeMapList(response);

      // 4. Enrich with courses
      final List<Map<String, dynamic>> enrichedBundles = [];
      for (var bundle in bundles) {
        final bCoursesResponse = await _client
            .from('bundle_courses')
            .select('course_id')
            .eq('bundle_id', bundle['id']);

        final List<String> cIds = (bCoursesResponse as List)
            .map((e) => e['course_id'] as String)
            .toList();

        final fullCoursesResponse =
            await _client.from('courses').select().inFilter('id', cIds);

        bundle['courses'] = fullCoursesResponse;
        enrichedBundles.add(bundle);
      }
      return enrichedBundles;
    } catch (e) {
      debugPrint('Error getting bundles by teacher: $e');
      return [];
    }
  }

  // ==================== TIPS (NEW) ====================

  /// Get all tips with optional linked course data
  Future<List<Map<String, dynamic>>> getTips(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.tips, // Make sure to add this to CacheKeys
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final response = await _client
              .from('tips')
              .select('*, courses(*)')
              .order('created_at', ascending: false);
          return SafeParser.safeMapList(response);
        } catch (e) {
          debugPrint('Error getting tips: $e');
          return [];
        }
      },
    );
  }

  /// Get Tip by ID or Slug
  Future<Map<String, dynamic>?> getTipById(String tipId) async {
    try {
      final response = await _client
          .from('tips')
          .select('*, courses(*)')
          .eq(_isUuid(tipId) ? 'id' : 'slug', tipId)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('Error getting tip by ID/Slug: $e');
      return null;
    }
  }

  /// Create a new tip
  Future<void> createTip({
    required String title,
    required String videoUrl,
    String? thumbnailUrl,
    String? courseId,
    String? instructorId,
  }) async {
    try {
      await _client.from('tips').insert({
        'title': title,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'course_id': courseId,
        'instructor_id': instructorId,
      });
      await LocalDatabase().remove(CacheKeys.tips);
    } catch (e) {
      debugPrint('Error creating tip: $e');
      rethrow;
    }
  }

  /// Update an existing tip
  Future<void> updateTip({
    required String id,
    String? title,
    String? videoUrl,
    String? thumbnailUrl,
    String? courseId,
    String? instructorId,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (videoUrl != null) updates['video_url'] = videoUrl;
      if (thumbnailUrl != null) updates['thumbnail_url'] = thumbnailUrl;
      if (courseId != null) updates['course_id'] = courseId;
      if (instructorId != null) updates['instructor_id'] = instructorId;

      if (updates.isNotEmpty) {
        await _client.from('tips').update(updates).eq('id', id);
        await LocalDatabase().remove(CacheKeys.tips);
      }
    } catch (e) {
      debugPrint('Error updating tip: $e');
      rethrow;
    }
  }

  /// Delete a tip
  Future<void> deleteTip(String id) async {
    try {
      await _client.from('tips').delete().eq('id', id);
      await LocalDatabase().remove(CacheKeys.tips);
    } catch (e) {
      debugPrint('Error deleting tip: $e');
      rethrow;
    }
  }

  /// Increment view count for a tip
  Future<void> incrementTipView(String id) async {
    try {
      await _client.rpc('increment_tip_view', params: {'tip_id': id});
    } catch (e) {
      // If RPC fails, try manual update (less efficient but reliable)
      try {
        final tip = await _client
            .from('tips')
            .select('views_count')
            .eq('id', id)
            .single();
        final currentViews = tip['views_count'] ?? 0;
        await _client
            .from('tips')
            .update({'views_count': currentViews + 1}).eq('id', id);
      } catch (err) {
        debugPrint('Error incrementing tip view: $err');
      }
    }
  }

  // ==================== TAGS (NEW) ====================

  /// Get tags for a course
  Future<List<String>> getCourseTags(String courseId) async {
    try {
      final response = await _client
          .from('course_tags')
          .select('tag')
          .eq('course_id', courseId);

      return (response as List).map((e) => e['tag'] as String).toList();
    } catch (e) {
      debugPrint('Error getting course tags: $e');
      return [];
    }
  }

  /// Add tags to a course
  Future<void> addCourseTags(String courseId, List<String> tags) async {
    try {
      if (tags.isEmpty) return;

      final data = tags
          .map((tag) => {
                'course_id': courseId,
                'tag': tag,
              })
          .toList();

      await _client.from('course_tags').insert(data);
    } catch (e) {
      debugPrint('Error adding course tags: $e');
      rethrow;
    }
  }

  /// Update tags for a course (replaces existing tags)
  Future<void> updateCourseTags(String courseId, List<String> tags) async {
    try {
      // Delete existing tags
      await _client.from('course_tags').delete().eq('course_id', courseId);

      // Add new tags
      if (tags.isNotEmpty) {
        await addCourseTags(courseId, tags);
      }
    } catch (e) {
      debugPrint('⚠️ Error updating course tags: $e');
      // We don't rethrow here to prevent tag issues from blocking course saving
    }
  }

  // ==================== BANNERS / ADS (NEW) ====================

  Future<List<Map<String, dynamic>>> getBanners(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.banners,
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final response = await _client
              .from('banners')
              .select()
              .order('created_at', ascending: false);
          return SafeParser.safeMapList(response);
        } catch (e) {
          debugPrint('Error getting banners: $e');
          return [];
        }
      },
    );
  }

  Future<void> createBanner({
    required String title,
    String? subtitle,
    required String imageUrl,
    required String type,
    String? location,
    String? targetId,
    String? linkUrl,
  }) async {
    try {
      await _client.from('banners').insert({
        'title': title,
        'subtitle': subtitle,
        'image_url': imageUrl,
        'type': type,
        'location': location ?? 'top',
        'target_id': targetId,
        'link_url': linkUrl,
      });
      await LocalDatabase().remove(CacheKeys.banners);
    } catch (e) {
      debugPrint('Error creating banner: $e');
      rethrow;
    }
  }

  Future<void> updateBanner({
    required String id,
    String? title,
    String? subtitle,
    String? imageUrl,
    String? type,
    String? location,
    String? targetId,
    String? linkUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (subtitle != null) updates['subtitle'] = subtitle;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (type != null) updates['type'] = type;
      if (location != null) updates['location'] = location;
      if (targetId != null) updates['target_id'] = targetId;
      if (linkUrl != null) updates['link_url'] = linkUrl;

      if (updates.isNotEmpty) {
        await _client.from('banners').update(updates).eq('id', id);
        await LocalDatabase().remove(CacheKeys.banners);
      }
    } catch (e) {
      debugPrint('Error updating banner: $e');
      rethrow;
    }
  }

  Future<void> deleteBanner(String id) async {
    try {
      await _client.from('banners').delete().eq('id', id);
      await LocalDatabase().remove(CacheKeys.banners);
    } catch (e) {
      debugPrint('Error deleting banner: $e');
      rethrow;
    }
  }

  // ==================== SEARCH ====================

  /// Search courses with filters
  Future<List<Map<String, dynamic>>> searchCourses({
    String? query,
    String? category,
    String? categoryId, // Added categoryId support
    String? subject,
    String? level, // Added
    double? minPrice,
    double? maxPrice,
    double? minRating,
  }) async {
    try {
      // Build query
      var dbQuery = _client
          .from('courses')
          .select('*, users!instructor_id(full_name, avatar_url)');

      // Text Search
      if (query != null && query.isNotEmpty) {
        // Search in title and description using ilike (case-insensitive)
        dbQuery = dbQuery.or('title.ilike.%$query%,description.ilike.%$query%');
      }

      // Level Filter
      if (level != null && level != 'all_levels' && level != 'الكل') {
        dbQuery = dbQuery.eq('level', level);
      }

      // Category Filter
      if (categoryId != null) {
        final subCatIds = await getSubCategoryIds(categoryId);
        if (subCatIds.isNotEmpty) {
          dbQuery = dbQuery.inFilter('course_category_junction.category_id',
              [categoryId, ...subCatIds]);
        } else {
          dbQuery = dbQuery.filter(
              'course_category_junction.category_id', 'eq', categoryId);
        }
      } else if (category != null && category != 'الكل') {
        dbQuery = dbQuery.filter('category', 'eq', category);
      }

      // Subject Filter
      if (subject != null && subject != 'الكل') {
        dbQuery = dbQuery.eq('subject', subject);
      }

      // Price Range
      if (minPrice != null) {
        dbQuery = dbQuery.gte('price', minPrice);
      }
      if (maxPrice != null) {
        dbQuery = dbQuery.lte('price', maxPrice);
      }

      // Rating Filter
      if (minRating != null) {
        dbQuery = dbQuery.gte('rating', minRating);
      }

      // Ensure published only
      dbQuery = dbQuery.eq('is_published', true);

      final response = await dbQuery;
      final data = SafeParser.safeMapList(response);

      // Map joined data to flat structure expected by UI
      return data
          .map((course) {
            final user = course['users'];
            if (user != null) {
              course['instructor_name'] =
                  user['full_name'] ?? course['instructor_name'];
              course['instructor_photo'] =
                  user['avatar_url'] ?? course['instructor_photo'];
            }
            return course;
          })
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error searching courses: $e');
      rethrow;
    }
  }

  // ==================== COURSES ====================

  /// Get courses by teacher ID (Internal helper or use directly)
  Future<List<Map<String, dynamic>>> getCoursesByTeacherId(
      String teacherId) async {
    try {
      final response = await _client
          .from('courses')
          .select()
          .eq('instructor_id', teacherId)
          .eq('is_published', true);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get teacher courses with statistics
  Future<List<Map<String, dynamic>>> getTeacherCourses(
      {bool forceRefresh = false}) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];

    return fetchWithCache(
      key: 'teacher_courses_$userId',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // 1. Get all courses for this teacher
          final coursesResponse = await _client
              .from('courses')
              .select()
              .eq('instructor_id', userId);

          final courses = SafeParser.safeMapList(coursesResponse);
          final courseIds = courses.map((c) => c['id']).toList();

          if (courseIds.isEmpty) return [];

          // 2. Get enrollments for progress and student count
          final enrollmentsResponse = await _client
              .from('enrollments')
              .select('course_id, progress_percentage')
              .inFilter('course_id', courseIds);

          final enrollments = SafeParser.safeMapList(enrollmentsResponse);

          // 3. Get exams count
          final examsResponse = await _client
              .from('exams')
              .select('course_id')
              .inFilter('course_id', courseIds);

          final allExams = SafeParser.safeMapList(examsResponse);

          // 4. Get revenue from view
          final revenueResponse = await _client
              .from('admin_enrollments_view')
              .select('course_id, course_price')
              .inFilter('course_id', courseIds);

          final allRevenue = SafeParser.safeMapList(revenueResponse);

          // 5. Aggregate data
          return courses
              .map((course) {
                final courseId = course['id'];

                final courseEnrollments =
                    enrollments.where((e) => e['course_id'] == courseId);
                final studentCount = courseEnrollments.length;

                double avgProgress = 0;
                if (studentCount > 0) {
                  final totalProgress = courseEnrollments.fold(
                      0.0,
                      (sum, e) =>
                          sum +
                          (e['progress_percentage'] as num? ?? 0).toDouble());
                  avgProgress = (totalProgress / studentCount);
                }

                final examCount =
                    allExams.where((e) => e['course_id'] == courseId).length;

                final courseRevenue = allRevenue
                    .where((r) => r['course_id'] == courseId)
                    .fold(
                        0.0,
                        (sum, r) =>
                            sum + (r['course_price'] as num? ?? 0).toDouble());

                return {
                  ...course,
                  'student_count': studentCount,
                  'average_progress': avgProgress,
                  'exam_count': examCount,
                  'revenue': courseRevenue,
                };
              })
              .toList()
              .cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error in getTeacherCourses: $e');
          rethrow;
        }
      },
    );
  }

  /// Get all unique students enrolled in any of the teacher's courses
  Future<List<Map<String, dynamic>>> getTeacherSubscribers(
      String teacherId) async {
    try {
      final courses = await getCoursesByTeacherId(teacherId);
      if (courses.isEmpty) return [];

      final courseIds = courses.map((c) => c['id']).toList();

      final response = await _client
          .from('enrollments')
          .select(
              '*, users!inner(full_name, avatar_url, email), courses(title)')
          .inFilter('course_id', courseIds)
          .order('enrolled_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting teacher subscribers: $e');
      return [];
    }
  }

  /// Get students enrolled in a specific course
  Future<List<Map<String, dynamic>>> getCourseSubscribers(
      String courseId) async {
    try {
      final response = await _client
          .from('enrollments')
          .select('*, users!inner(full_name, avatar_url, email)')
          .eq('course_id', courseId)
          .order('enrolled_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting course subscribers: $e');
      return [];
    }
  }

  /// Remove a student from a course
  Future<void> removeStudentFromCourse(String userId, String courseId) async {
    try {
      await _client
          .from('enrollments')
          .delete()
          .eq('user_id', userId)
          .eq('course_id', courseId);

      await _updateCourseEnrollmentCount(courseId);
      await LocalDatabase().remove('user_${userId}_accessible_course_ids');
    } catch (e) {
      debugPrint('Error removing student from course: $e');
      rethrow;
    }
  }

  /// Get teacher exams
  Future<List<Map<String, dynamic>>> getTeacherExams() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('exams')
          .select('*, courses(title)')
          // Assuming exams have an instructor_id or we filter by course owner
          // For now, let's assume we fetch exams for courses owned by teacher
          .eq('created_by', userId) // Or join with courses
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      // Fallback if created_by doesn't exist, try via teacher_courses
      try {
        final courses = await getTeacherCourses();
        if (courses.isEmpty) return [];

        final courseIds = courses.map((c) => c['id']).toList();
        final response = await _client
            .from('exams')
            .select('*, courses(title)')
            .inFilter('course_id', courseIds)
            .order('created_at', ascending: false);

        return SafeParser.safeMapList(response);
      } catch (e2) {
        rethrow;
      }
    }
  }

  /// Get exams for a specific lesson
  Future<List<Map<String, dynamic>>> getExamsForLesson(String lessonId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      final response = await _client
          .from('exams')
          .select('*, courses(title), questions(*), attempts:exam_attempts(*)')
          .eq('lesson_id', lessonId)
          .eq('is_published', true)
          .eq('attempts.user_id', userId ?? '')
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error fetching exams for lesson: $e');
      return [];
    }
  }

  /// Get all courses
  /// Selective columns for listing to reduce data transfer
  static const String liteCourseColumns = '''
    id, title, slug, description, image_url, price, discount_percentage, 
    rating, students_count, lessons_count, instructor_id, instructor_name, 
    instructor_photo, subject, level, is_published, is_featured,
    featured_order, created_at, delivery_mode,
    users!instructor_id(full_name, avatar_url),
    course_category_junction(category:categories(id, name, name_en)),
    course_tags(tag)
  ''';

  /// Get courses with advanced filtering and pagination
  Future<List<Map<String, dynamic>>> getCourses({
    String? category,
    String? categoryId,
    String? subject,
    String? instructorId,
    String? level,
    String? query,
    int? limit,
    int? offset,
    List<String>? ids,
    bool includeDrafts = false,
    bool forceRefresh = false,
    bool liteMode = true,
    String orderBy = 'created_at',
    bool ascending = false,
    String? deliveryMode,
  }) async {
    final String cacheKey = CacheKeys.coursesV2(
      categoryId: categoryId,
      teacherId: instructorId,
      level: level,
      subject: subject,
      query: query,
      limit: limit,
      offset: offset,
      ids: ids,
      includeDrafts: includeDrafts,
      orderBy: orderBy,
      ascending: ascending,
      deliveryMode: deliveryMode,
    );

    return fetchWithCache(
      key: cacheKey,
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 5),
      fetcher: () async {
        try {
          String columns = liteMode ? liteCourseColumns : '*';

          // ELITE FIX: To filter by joined table (categories), we MUST use !inner
          // otherwise it performs a LEFT JOIN and returns all courses.
          if (categoryId != null) {
            columns = columns.replaceFirst(
                'course_category_junction', 'course_category_junction!inner');
          }

          var filterQuery = _client.from('courses').select(columns);

          if (instructorId != null) {
            filterQuery = filterQuery.eq('instructor_id', instructorId);
          }

          if (ids != null && ids.isNotEmpty) {
            filterQuery = filterQuery.filter('id', 'in', ids);
          }

          if (level != null && level != 'all' && level != 'الكل') {
            filterQuery = filterQuery.eq('level', level);
          }

          if (categoryId != null) {
            final subCatIds = await getSubCategoryIds(categoryId);
            if (subCatIds.isNotEmpty) {
              filterQuery = filterQuery.filter(
                  'course_category_junction.category_id',
                  'in',
                  [categoryId, ...subCatIds]);
            } else {
              filterQuery = filterQuery.filter(
                  'course_category_junction.category_id', 'eq', categoryId);
            }
          } else if (category != null && category != 'الكل') {
            filterQuery = filterQuery.eq('category', category);
          }

          if (subject != null && subject != 'الكل') {
            filterQuery = filterQuery.eq('subject', subject);
          }

          if (query != null && query.isNotEmpty) {
            filterQuery = filterQuery
                .or('title.ilike.%$query%,description.ilike.%$query%');
          }

          if (deliveryMode != null && deliveryMode != 'all') {
            filterQuery = filterQuery.eq('delivery_mode', deliveryMode);
          }

          if (!includeDrafts) {
            filterQuery = filterQuery.eq('is_published', true);
          }

          // 2. TRANSFORMING (Order, Limit, Range)
          var finalQuery = filterQuery.order(orderBy, ascending: ascending);

          if (limit != null) {
            finalQuery = finalQuery.limit(limit);
          }
          if (offset != null) {
            finalQuery = finalQuery.range(offset, offset + (limit ?? 10) - 1);
          }

          final response = await finalQuery;
          final data = SafeParser.safeMapList(response);

          // Map joined data to flat structure expected by UI
          return data
              .map((course) {
                final user = course['users'];
                if (user != null) {
                  course['instructor_name'] =
                      user['full_name'] ?? course['instructor_name'];
                  course['instructor_photo'] =
                      user['avatar_url'] ?? course['instructor_photo'];
                }

                // Map categories from junction
                final rawJunction = course['course_category_junction'];
                if (rawJunction is List) {
                  final categories = <String>[];
                  final categoriesEn = <String>[];
                  final categoryIds = <String>[];

                  for (var j in rawJunction) {
                    if (j is Map && j['category'] is Map) {
                      final cat = j['category'] as Map;
                      if (cat['name'] != null) categories.add(cat['name']);
                      if (cat['name_en'] != null) {
                        categoriesEn.add(cat['name_en']);
                      }
                      if (cat['id'] != null) categoryIds.add(cat['id']);
                    }
                  }

                  course['categories_names'] = categories;
                  course['categories_names_en'] = categoriesEn;
                  course['category_ids'] = categoryIds;
                  if (categories.isNotEmpty) {
                    course['category'] = categories.first;
                  }
                }

                // Map tags
                final rawTags = course['course_tags'];
                if (rawTags is List) {
                  course['tags'] = rawTags
                      .map((t) => t is Map ? t['tag']?.toString() : null)
                      .whereType<String>()
                      .toList();
                }

                return course;
              })
              .toList()
              .cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error getting courses: $e');
          return [];
        }
      },
    );
  }

  /// Helper to get a small chunk of courses for UI lists
  Future<List<Map<String, dynamic>>> getLiteCourses({
    int limit = 10,
    int offset = 0,
    String? categoryId,
    List<String>? ids,
    bool forceRefresh = false,
    String orderBy = 'created_at',
    bool ascending = false,
    String? deliveryMode,
  }) async {
    return getCourses(
      limit: limit,
      offset: offset,
      categoryId: categoryId,
      ids: ids,
      forceRefresh: forceRefresh,
      liteMode: true,
      orderBy: orderBy,
      ascending: ascending,
      deliveryMode: deliveryMode,
    );
  }

  /// Get course by ID with join
  Future<Map<String, dynamic>?> getCourseById(String courseId,
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.course(courseId),
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          final response = await _client.from('courses').select('''
                *, 
                users!instructor_id(full_name, avatar_url),
                course_category_junction(category:categories(id, name, name_en)),
                chapters:chapters(*, lessons:lessons(*)),
                course_tags(tag)
              ''').eq(_isUuid(courseId) ? 'id' : 'slug', courseId).single();

          final course = Map<String, dynamic>.from(response);

          // Map instructor data
          final user = course['users'];
          if (user != null) {
            course['instructor_name'] =
                user['full_name'] ?? course['instructor_name'];
            course['instructor_photo'] =
                user['avatar_url'] ?? course['instructor_photo'];
            course['instructor_name'] = user['full_name'];
          }

          // Map categories
          final junction = course['course_category_junction'] as List?;
          if (junction != null) {
            final categories =
                junction.map((j) => j['category']['name'] as String).toList();
            final categoriesEn = junction
                .map((j) => j['category']['name_en'] as String)
                .toList();
            final categoryIds =
                junction.map((j) => j['category']['id'] as String).toList();
            course['categories_names'] = categories;
            course['categories_names_en'] = categoriesEn;
            course['category_ids'] = categoryIds;
            if (categories.isNotEmpty) course['category'] = categories.first;
          }

          // Map tags
          final tagsList = course['course_tags'] as List?;
          if (tagsList != null) {
            course['tags'] = tagsList.map((t) => t['tag'] as String).toList();
          }

          return course;
        } catch (e) {
          // Fallback to simple select
          try {
            final res = await _client
                .from('courses')
                .select()
                .eq(_isUuid(courseId) ? 'id' : 'slug', courseId)
                .single();
            return Map<String, dynamic>.from(res);
          } catch (_) {
            return null;
          }
        }
      },
    );
  }

  /// Get lessons for a course with progress
  Future<List<Map<String, dynamic>>> getLessons(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;

      final response = await _client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      final lessons = SafeParser.safeMapList(response);

      // If user is authenticated, get progress for all lessons in one query
      if (userId != null && lessons.isNotEmpty) {
        final lessonIds = lessons.map((l) => l['id'] as String).toList();

        final progressResponse = await _client
            .from('lesson_progress')
            .select()
            .eq('user_id', userId)
            .filter('lesson_id', 'in', lessonIds);

        final allProgress = SafeParser.safeMapList(progressResponse);

        // Create a map for quick lookup
        final progressMap = {for (var p in allProgress) p['lesson_id']: p};

        for (var lesson in lessons) {
          final progress = progressMap[lesson['id']];
          if (progress != null) {
            lesson['is_completed'] = progress['is_completed'];
            lesson['watch_time'] = progress['watch_time'];
            lesson['last_position'] = progress['last_position'];
          }
        }
      }

      return lessons;
    } catch (e) {
      debugPrint('Error getting lessons: $e');
      rethrow;
    }
  }

  /// Get lesson by ID or Slug
  Future<Map<String, dynamic>?> getLessonById(String lessonId) async {
    try {
      final response = await _client
          .from('lessons')
          .select()
          .eq(_isUuid(lessonId) ? 'id' : 'slug', lessonId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting lesson: $e');
      return null;
    }
  }

  /// Get Bundle by ID or Slug
  Future<Map<String, dynamic>?> getBundleById(String bundleId) async {
    try {
      final response = await _client
          .from('bundles')
          .select('*, courses(*)')
          .eq(_isUuid(bundleId) ? 'id' : 'slug', bundleId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting bundle: $e');
      return null;
    }
  }

  /// Get teacher by ID or Slug
  Future<Map<String, dynamic>?> getTeacherById(String teacherId) async {
    try {
      final response = await _client
          .from('users')
          .select('*')
          .eq(_isUuid(teacherId) ? 'id' : 'slug', teacherId)
          .maybeSingle();

      if (response != null) {
        final avatar = _formatAvatarUrl(
            response['photo_url'] ?? response['avatar_url'],
            userId: response['id']);
        response['photo_url'] = avatar;
        response['avatar_url'] = avatar;
      }
      return response;
    } catch (e) {
      debugPrint('Error getting teacher: $e');
      return null;
    }
  }

  /// Get lesson progress for a specific lesson (private helper)
  Future<Map<String, dynamic>?> _getLessonProgress(String lessonId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('lesson_progress')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Update lesson progress
  Future<void> updateLessonProgress({
    required String lessonId,
    int? watchTime,
    int? lastPosition,
    bool? isCompleted,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Check if progress exists
      final existing = await _getLessonProgress(lessonId);

      final data = {
        'user_id': userId,
        'lesson_id': lessonId,
        'watch_time': watchTime,
        'last_position': lastPosition,
        'is_completed': isCompleted ?? false,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isCompleted == true) {
        data['completed_at'] = DateTime.now().toIso8601String();
      }

      if (existing == null) {
        // Create new progress
        await _client.from('lesson_progress').insert(data);
      } else {
        // Update existing progress
        await _client
            .from('lesson_progress')
            .update(data)
            .eq('user_id', userId)
            .eq('lesson_id', lessonId);
      }

      // Update course progress
      await _updateCourseProgress(lessonId);
    } catch (e) {
      rethrow;
    }
  }

  /// Mark lesson as completed
  Future<void> markLessonAsCompleted(String lessonId) async {
    await updateLessonProgress(
      lessonId: lessonId,
      isCompleted: true,
    );
  }

  /// Update course progress based on completed lessons
  Future<void> _updateCourseProgress(String lessonId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      // Get the course_id from the lesson
      final lesson = await _client
          .from('lessons')
          .select('course_id')
          .eq('id', lessonId)
          .single();

      final courseId = lesson['course_id'];

      // Get total lessons count
      final totalLessons =
          await _client.from('lessons').select('id').eq('course_id', courseId);

      // Get completed lessons count
      final completedLessons = await _client
          .from('lesson_progress')
          .select('id')
          .eq('user_id', userId)
          .eq('is_completed', true);

      // Calculate progress percentage
      final progress =
          (completedLessons.length / totalLessons.length * 100).toDouble();

      // Update enrollment progress
      await _client
          .from('enrollments')
          .update({'progress': progress})
          .eq('user_id', userId)
          .eq('user_id', userId)
          .eq('course_id', courseId);

      // Invalidate relevant caches
      await LocalDatabase().remove('user_${userId}_accessible_course_ids');
      await LocalDatabase().remove(CacheKeys.userEnrolledIds(userId));
      await LocalDatabase().remove(CacheKeys.userEnrollments(userId));
    } catch (e) {
      debugPrint('Error updating course progress: $e');
    }
  }

  // ==================== CHAPTERS ====================

  /// Get chapters for a course
  Future<List<Chapter>> getChapters(String courseId) async {
    if (courseId.trim().isEmpty) return [];
    try {
      final response = await _client
          .from('chapters')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      return (response as List).map((json) => Chapter.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting chapters: $e');
      rethrow;
    }
  }

  /// Create a chapter
  Future<void> createChapter(Chapter chapter) async {
    try {
      final data = chapter.toJson();
      if (chapter.id.isEmpty) data.remove('id');
      await _client.from('chapters').insert(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Update a chapter
  Future<void> updateChapter(Chapter chapter) async {
    try {
      final updates = chapter.toJson();
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _client.from('chapters').update(updates).eq('id', chapter.id);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a chapter
  Future<void> deleteChapter(String chapterId) async {
    try {
      await _client.from('chapters').delete().eq('id', chapterId);
    } catch (e) {
      rethrow;
    }
  }

  /// Reorder chapters
  Future<void> reorderChapters(List<Map<String, dynamic>> updates) async {
    try {
      await _client.from('chapters').upsert(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Get course lessons (alias for getLessons)
  Future<List<Map<String, dynamic>>> getCourseLessons(String courseId) async {
    return getLessons(courseId);
  }

  // ==================== NOTES ====================

  /// Create a note
  Future<void> createNote({
    required String lessonId,
    required String courseId,
    required String title,
    required String content,
    int? timestamp,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('notes').insert({
        'user_id': userId,
        'lesson_id': lessonId,
        'course_id': courseId,
        'title': title,
        'content': content,
        'timestamp': timestamp,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get bookmarks for a lesson
  Future<List<Map<String, dynamic>>> getBookmarks(String lessonId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('bookmarks')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('created_at'); // or timestamp if used

      return SafeParser.safeMapList(response);
    } catch (e) {
      return [];
    }
  }

  /// Save bookmark
  Future<void> saveBookmark({
    required String lessonId,
    required String title,
    required int timestamp,
    String? note,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      await _client.from('bookmarks').insert({
        'user_id': userId,
        'lesson_id': lessonId,
        'title': title,
        'timestamp': timestamp,
        'note': note,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Delete bookmark
  Future<void> deleteBookmark(String bookmarkId) async {
    try {
      await _client.from('bookmarks').delete().eq('id', bookmarkId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get notes for a lesson
  Future<List<Map<String, dynamic>>> getNotes(String lessonId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('notes')
          .select()
          .eq('user_id', userId)
          .eq('lesson_id', lessonId)
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Update a note
  Future<void> updateNote(String noteId, String content) async {
    try {
      await _client.from('notes').update({
        'content': content,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', noteId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a note
  Future<void> deleteNote(String noteId) async {
    try {
      await _client.from('notes').delete().eq('id', noteId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== CALENDAR ====================

  /// Create calendar event
  Future<void> createCalendarEvent({
    required String title,
    String? description,
    required DateTime eventDate,
    TimeOfDay? eventTime,
    required String type,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('calendar_events').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'event_date': eventDate.toIso8601String().split('T')[0],
        'event_time': eventTime != null
            ? '${eventTime.hour.toString().padLeft(2, '0')}:${eventTime.minute.toString().padLeft(2, '0')}'
            : null,
        'type': type,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get calendar events
  Future<List<Map<String, dynamic>>> getCalendarEvents() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('calendar_events')
          .select()
          .eq('user_id', userId)
          .order('event_date');

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ACHIEVEMENTS ====================

  /// Get user achievements
  Future<List<Map<String, dynamic>>> getUserAchievements() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('user_achievements')
          .select('*, achievements(*)')
          .eq('user_id', userId);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Update FCM Token for user
  Future<void> updateFcmToken(String token) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      // Update token in profiles table (assuming profiles is linked to auth.users)
      // If using a public 'users' table, verify the table name.
      // Based on previous code, 'users' seems to be the public table name.
      await _client
          .from('users') // or 'profiles'
          .update({'fcm_token': token}).eq('id', userId);

      debugPrint("✅ FCM Token updated in database for user: $userId");
    } catch (e) {
      debugPrint("❌ Error updating FCM Token: $e");
      // Don't rethrow to avoid blocking app flow
    }
  }

  /// Get user notifications
  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      rethrow;
    }
  }

  /// Mark all notifications as read
  Future<void> markAllNotificationsAsRead() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true}).eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  /// Save a received notification (called on FCM message received)
  Future<void> saveNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? type,
    String? category,
    String? imageUrl,
    String? actionUrl,
    DateTime? expiresAt,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
        'type': type ?? 'general',
        'category': category ?? 'announcement',
        'image_url': imageUrl,
        'action_url': actionUrl,
        'expires_at': expiresAt?.toIso8601String(),
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Error saving notification: $e');
    }
  }

  /// Broadcast notification to all users, a course's students, or a single user
  /// This directly inserts into notifications table for instant in-app delivery
  Future<int> broadcastNotification({
    required String title,
    required String body,
    required String targetType, // 'all', 'course', 'user'
    String? targetId, // courseId or userId depending on targetType
    String? imageUrl,
    String? actionUrl,
    String? category,
  }) async {
    try {
      List<String> userIds = [];

      if (targetType == 'all') {
        // Get all user IDs
        final response = await _client.from('users').select('id');
        userIds = (response as List).map((u) => u['id'] as String).toList();
      } else if (targetType == 'course' && targetId != null) {
        // Get enrolled user IDs for the course
        final response = await _client
            .from('enrollments')
            .select('user_id')
            .eq('course_id', targetId);
        userIds =
            (response as List).map((e) => e['user_id'] as String).toList();
      } else if (targetType == 'user' && targetId != null) {
        userIds = [targetId];
      }

      if (userIds.isEmpty) return 0;

      // Batch insert notifications for all target users
      final now = DateTime.now().toIso8601String();
      final inserts = userIds
          .map((uid) => {
                'user_id': uid,
                'title': title,
                'body': body,
                'type': 'general',
                'category': category ?? 'announcement',
                'image_url': imageUrl,
                'action_url': actionUrl,
                'is_read': false,
                'created_at': now,
              })
          .toList();

      // Insert in batches of 100 to avoid request size limits
      const batchSize = 100;
      for (var i = 0; i < inserts.length; i += batchSize) {
        final batch = inserts.sublist(
            i, i + batchSize > inserts.length ? inserts.length : i + batchSize);
        await _client.from('notifications').insert(batch);
      }

      debugPrint('✅ Broadcasted notification to ${userIds.length} users');
      return userIds.length;
    } catch (e) {
      debugPrint('❌ Error broadcasting notification: $e');
      rethrow;
    }
  }

  // ==================== REVIEWS ====================

  /// Get reviews for a course
  Future<List<Map<String, dynamic>>> getReviews(String courseId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('*, users(full_name, avatar_url)')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Add a review
  Future<void> addReview({
    required String courseId,
    required double rating,
    required String comment,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('reviews').insert({
        'user_id': userId,
        'course_id': courseId,
        'rating': rating,
        'comment': comment,
      });

      // Update course rating
      await _updateCourseRating(courseId);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has reviewed the course
  Future<Map<String, dynamic>?> getUserReviewForCourse(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return null;

      final response = await _client
          .from('reviews')
          .select()
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .limit(1)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error getting user review: $e');
      return null;
    }
  }

  /// Update course rating based on reviews
  Future<void> _updateCourseRating(String courseId) async {
    try {
      final response = await _client
          .from('reviews')
          .select('rating')
          .eq('course_id', courseId);

      if (response.isEmpty) return;

      final ratings = SafeParser.safeMapList(response);
      if (ratings.isEmpty) return;

      double totalRating = 0;
      for (var r in ratings) {
        totalRating += (r['rating'] as num).toDouble();
      }

      final averageRating = totalRating / ratings.length;

      // Update course with new calculations
      await _client.from('courses').update({
        'rating': averageRating,
      }).eq('id', courseId);
    } catch (e) {
      debugPrint('Error updating course rating: $e');
    }
  }

  // ==================== TASKS ====================

  /// Get tasks
  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('tasks')
          .select()
          .eq('user_id', userId)
          .order('due_date');

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Create a task
  Future<void> createTask({
    required String title,
    String? description,
    required DateTime dueDate,
    String? courseId,
    int priority = 1,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('tasks').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'course_id': courseId,
        'priority': priority,
        'is_completed': false,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, bool isCompleted) async {
    try {
      await _client.from('tasks').update({
        'is_completed': isCompleted,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', taskId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _client.from('tasks').delete().eq('id', taskId);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== USER STATS ====================

  /// Get user profile (public info)
  Future<Map<String, dynamic>> getUserProfile(String userId,
      {bool forceRefresh = false}) async {
    if (userId.trim().isEmpty) return {};

    return fetchWithCache(
      key: CacheKeys.userProfile(userId),
      forceRefresh: forceRefresh,
      duration: const Duration(days: 1),
      fetcher: () async {
        try {
          final response = await _client
              .from('users')
              .select('full_name, avatar_url')
              .eq('id', userId)
              .maybeSingle();

          if (response == null) return {};

          // Ensure avatar_url is a full URL
          if (response['avatar_url'] != null) {
            response['avatar_url'] =
                _formatAvatarUrl(response['avatar_url'], userId: userId);
          }

          return Map<String, dynamic>.from(response);
        } catch (e) {
          debugPrint('Error getting user profile: $e');
          return {};
        }
      },
    );
  }

  /// Get user stats
  Future<Map<String, dynamic>> getUserStats({bool forceRefresh = false}) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) {
      return {
        'completed_courses': 0,
        'learning_hours': 0.0,
        'certificates': 0,
        'average_score': 0.0,
      };
    }

    return fetchWithCache(
      key: CacheKeys.userStats(userId),
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // Calculate completed courses
          final enrollmentsResponse = await _client
              .from('enrollments')
              .select('id, progress_percentage')
              .eq('user_id', userId)
              .gte('progress_percentage', 100);

          final completedCourses = (enrollmentsResponse as List).length;

          // Calculate learning hours from lesson progress
          final progressResponse = await _client
              .from('lesson_progress')
              .select('watch_time')
              .eq('user_id', userId);

          int totalSeconds = 0;
          for (var record in progressResponse) {
            totalSeconds += (record['watch_time'] as int?) ?? 0;
          }
          final learningHours = totalSeconds / 3600.0;

          // Certificates = completed courses
          final certificates = completedCourses;

          // Calculate average exam score
          final examAttemptsResponse = await _client
              .from('exam_attempts')
              .select('score, total_points')
              .eq('user_id', userId)
              .eq('status', 'submitted');

          double averageScore = 0.0;
          if ((examAttemptsResponse as List).isNotEmpty) {
            double totalPercentage = 0;
            for (var attempt in examAttemptsResponse) {
              final score = (attempt['score'] as num?)?.toDouble() ?? 0;
              final totalScore =
                  (attempt['total_points'] as num?)?.toDouble() ?? 1;
              if (totalScore > 0) {
                totalPercentage += (score / totalScore) * 100;
              }
            }
            averageScore = totalPercentage / examAttemptsResponse.length;
          }

          return {
            'completed_courses': completedCourses,
            'learning_hours': learningHours,
            'certificates': certificates,
            'average_score': averageScore,
          };
        } catch (e) {
          debugPrint('Error getting user stats: $e');
          return {
            'completed_courses': 0,
            'learning_hours': 0.0,
            'certificates': 0,
            'average_score': 0.0,
          };
        }
      },
    );
  }

  /// Get leaderboard data (Top students)
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      // Aggregate points from exam_attempts and lesson_progress
      final response = await _client
          .from('users')
          .select(
              'id, full_name, avatar_url, exam_attempts(score, status), lesson_progress(is_completed)')
          .order('full_name');

      final users = SafeParser.safeMapList(response);

      final results = users.map((u) {
        // Points from exams (50 XP per submitted exam)
        final attempts = u['exam_attempts'] as List?;
        int examPoints = 0;
        if (attempts != null) {
          examPoints =
              attempts.where((a) => a['status'] == 'submitted').length * 50;
          // Add score points too
          for (var attempt in attempts) {
            examPoints += (attempt['score'] as num?)?.toInt() ?? 0;
          }
        }

        // Points from lessons (10 XP per completion)
        final progress = u['lesson_progress'] as List?;
        int lessonPoints = 0;
        if (progress != null) {
          lessonPoints =
              progress.where((p) => p['is_completed'] == true).length * 10;
        }

        int totalPoints = examPoints + lessonPoints;

        return {
          'id': u['id'],
          'full_name': u['full_name'],
          'avatar_url': u['avatar_url'],
          'points': totalPoints,
          'rank_title': _getRankTitle(totalPoints),
        };
      }).toList();

      // Sort by points descending
      results
          .sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

      return results.take(20).toList();
    } catch (e) {
      debugPrint('Error fetching leaderboard: $e');
      return [];
    }
  }

  String _getRankTitle(int points) {
    if (points > 5000) return 'أسطورة';
    if (points > 2000) return 'خبير';
    if (points > 1000) return 'متميز';
    if (points > 500) return 'مجتهد';
    return 'مبتدئ';
  }

  /// Returns a map with summary and list of transactions/enrollments
  Future<Map<String, dynamic>> getFinancialReport({
    DateTime? startDate,
    DateTime? endDate,
    String? courseId,
    String? teacherId,
  }) async {
    try {
      // Start building query on enrollments
      var query = _client.from('enrollments').select('''
        *,
        course:courses(title, price, instructor_id, instructor:users!instructor_id(full_name)),
        user:users(full_name)
      ''');

      // SECURITY: Role-based enforcement
      final currentUserId = SupabaseService.instance.currentUserId;
      if (currentUserId == null) {
        return {'totalEarnings': 0.0, 'totalEnrollments': 0, 'items': []};
      }

      final currentRole = await getUserRole(currentUserId);
      final isTeacher = currentRole == 'teacher';
      final isAdmin = currentRole == 'admin' || currentRole == 'super_admin';

      // If teacher, force teacherId to be their own ID
      String? effectiveTeacherId = teacherId;
      if (isTeacher) {
        effectiveTeacherId = currentUserId;
      } else if (!isAdmin) {
        // If not admin and not teacher (e.g. student), deny access
        return {'totalEarnings': 0.0, 'totalEnrollments': 0, 'items': []};
      }

      if (startDate != null) {
        query = query.gte('enrolled_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('enrolled_at', endDate.toIso8601String());
      }

      // Filter by course
      if (courseId != null) {
        query = query.eq('course_id', courseId);
      }

      // Filter by teacher
      if (effectiveTeacherId != null) {
        query = query.eq('course.instructor_id', effectiveTeacherId);
      }

      var data = await query;
      var enrollments = SafeParser.safeMapList(data);

      // Filter by teacher (Dart side)
      if (effectiveTeacherId != null) {
        enrollments = enrollments.where((e) {
          final course = e['course'] as Map?;
          return course?['instructor_id'] == effectiveTeacherId;
        }).toList();
      }

      double totalEarnings = 0;
      final List<Map<String, dynamic>> reportItems = enrollments.map((e) {
        final course = e['course'] as Map?;
        final amount = (e['price_paid'] ?? course?['price'] ?? 0.0).toDouble();
        totalEarnings += amount;

        return {
          'date': e['enrolled_at'] ?? e['created_at'],
          'student': e['user']?['full_name'] ?? 'مستخدم غير معروف',
          'course': course?['title'] ?? 'دورة غير معروفة',
          'instructor': course?['instructor']?['full_name'] ?? 'مدرس غير محدد',
          'amount': amount,
        };
      }).toList();

      return {
        'totalEarnings': totalEarnings,
        'totalEnrollments': enrollments.length,
        'items': reportItems,
        'period': (startDate != null && endDate != null)
            ? '${DateFormat('yyyy/MM/dd').format(startDate)} - ${DateFormat('yyyy/MM/dd').format(endDate)}'
            : 'كل الأوقات',
      };
    } catch (e) {
      debugPrint('Error generating financial report: $e');
      return {
        'totalEarnings': 0.0,
        'totalEnrollments': 0,
        'items': [],
      };
    }
  }

  // ==================== ENROLLMENTS ====================

  Future<List<String>> getAccessibleCourseIds(
      {bool forceRefresh = false}) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];

    final List<dynamic> cached = await fetchWithCache(
      key: 'user_${userId}_accessible_course_ids',
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 15),
      fetcher: () async {
        final Set<String> accessibleIds = {};

        try {
          final enrolled = await _client
              .from('enrollments')
              .select('course_id')
              .eq('user_id', userId);
          for (final item in enrolled as List) {
            final courseId = item['course_id']?.toString();
            if (courseId != null && courseId.isNotEmpty) {
              accessibleIds.add(courseId);
            }
          }
        } catch (e) {
          debugPrint('Error loading direct enrollments for access map: $e');
        }

        try {
          final paidOrders = await _client
              .from('orders')
              .select('id')
              .eq('user_id', userId)
              .inFilter('status', ['paid', 'completed', 'approved']);

          final orderIds = (paidOrders as List)
              .map((e) => e['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList();

          if (orderIds.isNotEmpty) {
            final orderItems = await _client
                .from('order_items')
                .select('item_id, item_type')
                .inFilter('order_id', orderIds);

            final courseIdsFromOrders = <String>{};
            final bundleIds = <String>{};

            for (final item in orderItems as List) {
              final itemType = item['item_type']?.toString().toLowerCase();
              final itemId = item['item_id']?.toString();
              if (itemId == null || itemId.isEmpty) continue;

              if (itemType == 'course') {
                courseIdsFromOrders.add(itemId);
              } else if (itemType == 'bundle' || itemType == 'package') {
                bundleIds.add(itemId);
              }
            }

            accessibleIds.addAll(courseIdsFromOrders);

            if (bundleIds.isNotEmpty) {
              final bundleCourses = await _client
                  .from('bundle_courses')
                  .select('course_id')
                  .inFilter('bundle_id', bundleIds.toList());

              for (final item in bundleCourses as List) {
                final courseId = item['course_id']?.toString();
                if (courseId != null && courseId.isNotEmpty) {
                  accessibleIds.add(courseId);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading paid order access map: $e');
        }

        return accessibleIds.toList();
      },
    );

    return cached.map((e) => e.toString()).toList();
  }

  Future<bool> hasCourseAccess(String courseId,
      {bool forceRefresh = false}) async {
    final accessibleIds =
        await getAccessibleCourseIds(forceRefresh: forceRefresh);
    return accessibleIds.contains(courseId);
  }

  Future<bool> hasBundleAccess(List<String> courseIds,
      {bool forceRefresh = false}) async {
    if (courseIds.isEmpty) return false;
    final accessibleIds =
        (await getAccessibleCourseIds(forceRefresh: forceRefresh)).toSet();
    return courseIds.every(accessibleIds.contains);
  }

  /// Check if user is enrolled in a course
  Future<bool> isEnrolled(String courseId) async {
    try {
      return await hasCourseAccess(courseId);
    } catch (e) {
      return false;
    }
  }

  /// Enroll in a course
  Future<void> enrollInCourse(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('enrollments').insert({
        'user_id': userId,
        'course_id': courseId,
        'progress': 0,
      });

      // Update students count
      await _updateCourseEnrollmentCount(courseId);

      // Invalidate course access cache so UI reflects new subscription immediately
      await LocalDatabase().remove('user_${userId}_accessible_course_ids');
      await LocalDatabase().remove(CacheKeys.userEnrolledIds(userId));
      await LocalDatabase().remove(CacheKeys.userEnrollments(userId));
    } catch (e) {
      rethrow;
    }
  }

  /// Unenroll from a course
  Future<void> unenrollFromCourse(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client
          .from('enrollments')
          .delete()
          .eq('user_id', userId)
          .eq('course_id', courseId);

      // Update students count
      await _updateCourseEnrollmentCount(courseId);

      // Invalidate course access cache
      await LocalDatabase().remove('user_${userId}_accessible_course_ids');
      await LocalDatabase().remove(CacheKeys.userEnrolledIds(userId));
      await LocalDatabase().remove(CacheKeys.userEnrollments(userId));
    } catch (e) {
      rethrow;
    }
  }

  // ==================== FAVORITES (NEW) ====================

  /// Check if course is in favorites
  Future<bool> isFavorite(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return false;

      final response = await _client
          .from('course_favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking favorite status: $e');
      return false;
    }
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String courseId, bool shouldBeFavorite) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      if (shouldBeFavorite) {
        // Add to favorites
        await _client.from('course_favorites').upsert({
          'user_id': userId,
          'course_id': courseId,
        });
        return true;
      } else {
        // Remove from favorites
        await _client
            .from('course_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('course_id', courseId);
        return false;
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      rethrow;
    }
  }

  /// Get user's favorite courses
  Future<List<Map<String, dynamic>>> getFavoriteCourses() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('course_favorites')
          .select('*, courses(*, users!instructor_id(full_name, avatar_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final data = SafeParser.safeMapList(response);
      return data.map((fav) => fav['courses'] as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting favorite courses: $e');
      return [];
    }
  }

  /// Get similar courses based on category
  Future<List<Course>> getSimilarCourses(
      String courseId, List<String> categoryIds) async {
    try {
      if (categoryIds.isEmpty) return [];

      final response = await _client
          .from('courses')
          .select('*, users!instructor_id(full_name, avatar_url)')
          .inFilter('category_id', categoryIds)
          .neq('id', courseId)
          .eq('is_published', true)
          .limit(6);

      final data = SafeParser.safeMapList(response);
      return data.map((json) => Course.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting similar courses: $e');
      return [];
    }
  }

  /// Update course enrollment count
  Future<void> _updateCourseEnrollmentCount(String courseId) async {
    try {
      // Get count by selecting ids
      final response = await _client
          .from('enrollments')
          .select('id')
          .eq('course_id', courseId);

      final count = (response as List).length;

      // Update course
      await _client.from('courses').update({
        'students_count': count,
      }).eq('id', courseId);
    } catch (e) {
      debugPrint('Error updating course enrollment count: $e');
    }
  }

  /// Get enrolled courses with progress
  Future<List<Map<String, dynamic>>> getEnrolledCoursesWithProgress({
    bool forceRefresh = false,
  }) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];

    return fetchWithCache(
      key: CacheKeys.userEnrollments(userId),
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // Fetch enrollments with course details AND instructor details
          final response = await _client
              .from('enrollments')
              .select(
                  '*, courses(*, users!instructor_id(full_name, avatar_url))')
              .eq('user_id', userId)
              .order('enrolled_at', ascending: false);

          final data = SafeParser.safeMapList(response);

          // Map nested user data to course fields
          final enrollments = data.map((enrollment) {
            if (enrollment['courses'] != null) {
              final course = enrollment['courses'];
              final user = course['users'];
              if (user != null) {
                course['instructor_name'] =
                    user['full_name'] ?? course['instructor_name'];
                course['instructor_photo'] =
                    user['avatar_url'] ?? course['instructor_photo'];
              }
            }
            return enrollment;
          }).toList();

          return enrollments;
        } catch (e) {
          debugPrint('Error getting enrolled courses with join: $e');
          return _getEnrolledCoursesSimple();
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getEnrolledCoursesSimple() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];
    final response = await _client
        .from('enrollments')
        .select('*, courses(*)')
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false);
    return SafeParser.safeMapList(response);
  }

  /// Get enrolled course IDs
  Future<Set<String>> getEnrolledCourseIds() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return {};

      final idsList = await fetchWithCache<List<String>>(
        key: 'user_${userId}_enrolled_ids',
        duration: const Duration(hours: 1),
        fetcher: () async {
          final response = await _client
              .from('enrollments')
              .select('course_id')
              .eq('user_id', userId);

          return List<String>.from(
              (response as List).map((e) => e['course_id'] as String));
        },
      );

      return idsList.toSet();
    } catch (e) {
      debugPrint('Error getting enrolled course IDs: $e');
      return {};
    }
  }

  /// Get user's enrolled courses (without progress)
  Future<List<Map<String, dynamic>>> getEnrolledCourses() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];

    return fetchWithCache(
      key: 'user_${userId}_enrolled_list',
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          final response = await _client
              .from('enrollments')
              .select('*, courses(*)')
              .eq('user_id', userId);

          return SafeParser.safeMapList(response);
        } catch (e) {
          debugPrint('Error getting enrolled courses: $e');
          rethrow;
        }
      },
    );
  }

  // ==================== EXAMS ====================

  /// Get all exams for a course
  Future<List<Map<String, dynamic>>> getExamsForCourse(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      final response = await _client
          .from('exams')
          .select('*, questions(*), attempts:exam_attempts(*)')
          .eq('course_id', courseId)
          .eq('is_published', true)
          .eq('attempts.user_id', userId ?? '')
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all exams for a course (including drafts)
  Future<List<Map<String, dynamic>>> getAllExamsForCourse(String courseId,
      {bool includeQuestions = true}) async {
    if (courseId.trim().isEmpty) return [];
    try {
      final selectStr = includeQuestions ? '*, questions(*)' : '*';
      final response = await _client
          .from('exams')
          .select(selectStr)
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam by ID with questions
  Future<Map<String, dynamic>?> getExamById(String examId) async {
    try {
      final exam =
          await _client.from('exams').select().eq('id', examId).single();

      // Get questions for this exam
      final questions = await _client
          .from('questions')
          .select()
          .eq('exam_id', examId)
          .order('order_index');

      exam['questions'] = questions;
      return exam;
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's exam attempts
  Future<List<Map<String, dynamic>>> getUserExamAttempts({
    String? examId,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      var query = _client
          .from('exam_attempts')
          .select('*, exams(title, course_id, courses(title))')
          .eq('user_id', userId);

      if (examId != null) {
        query = query.eq('exam_id', examId);
      }

      final response = await query.order('started_at', ascending: false);
      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user can take exam (based on max attempts)
  Future<bool> canTakeExam(String examId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return false;

      // Get exam details
      final exam = await _client
          .from('exams')
          .select('max_attempts')
          .eq('id', examId)
          .single();

      final maxAttempts = exam['max_attempts'] as int?;
      if (maxAttempts == null) return true; // No limit

      // Count user's attempts
      final attempts = await _client
          .from('exam_attempts')
          .select('id')
          .eq('user_id', userId)
          .eq('exam_id', examId);

      return attempts.length < maxAttempts;
    } catch (e) {
      return false;
    }
  }

  /// Start a new exam attempt
  Future<String> startExamAttempt(String examId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Check if user can take the exam
      final canTake = await canTakeExam(examId);
      if (!canTake) {
        throw Exception('لقد تجاوزت الحد الأقصى لعدد المحاولات');
      }

      // Get exam details
      final exam = await _client
          .from('exams')
          .select('total_points')
          .eq('id', examId)
          .single();

      // Count previous attempts
      final previousAttempts = await _client
          .from('exam_attempts')
          .select('id')
          .eq('user_id', userId)
          .eq('exam_id', examId);

      final attemptNumber = previousAttempts.length + 1;

      // Create new attempt
      final response = await _client
          .from('exam_attempts')
          .insert({
            'exam_id': examId,
            'user_id': userId,
            'total_points': exam['total_points'],
            'attempt_number': attemptNumber,
            'status': 'in_progress',
          })
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Submit an answer for a question
  Future<void> submitAnswer({
    required String attemptId,
    required String questionId,
    required dynamic userAnswer,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the attempt belongs to the user
      final attempt = await _client
          .from('exam_attempts')
          .select('user_id, status')
          .eq('id', attemptId)
          .single();

      if (attempt['user_id'] != userId) {
        throw Exception('Unauthorized');
      }

      if (attempt['status'] != 'in_progress') {
        throw Exception('لا يمكن تعديل إجابات اختبار مكتمل');
      }

      // Get question details
      final question = await _client
          .from('questions')
          .select('correct_answer, points')
          .eq('id', questionId)
          .single();

      // Check if answer is correct
      final correctAnswer = question['correct_answer'];
      final isCorrect = _checkAnswer(userAnswer, correctAnswer);
      final pointsEarned = isCorrect ? (question['points'] as int) : 0;

      // Insert or update answer
      await _client.from('exam_answers').upsert({
        'attempt_id': attemptId,
        'question_id': questionId,
        'user_answer': userAnswer,
        'is_correct': isCorrect,
        'points_earned': pointsEarned,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Helper function to check if answer is correct
  bool _checkAnswer(dynamic userAnswer, dynamic correctAnswer) {
    if (userAnswer == null || correctAnswer == null) return false;

    // Handle different answer types
    if (userAnswer is int && correctAnswer is int) {
      return userAnswer == correctAnswer;
    } else if (userAnswer is String && correctAnswer is String) {
      return userAnswer.trim().toLowerCase() ==
          correctAnswer.trim().toLowerCase();
    } else if (userAnswer is List && correctAnswer is List) {
      if (userAnswer.length != correctAnswer.length) return false;
      for (var i = 0; i < userAnswer.length; i++) {
        if (userAnswer[i] != correctAnswer[i]) return false;
      }
      return true;
    }

    return userAnswer.toString() == correctAnswer.toString();
  }

  /// Submit exam attempt
  Future<Map<String, dynamic>> submitExamAttempt(String attemptId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      // Verify the attempt belongs to the user
      final attempt = await _client
          .from('exam_attempts')
          .select('user_id, started_at, status')
          .eq('id', attemptId)
          .single();

      if (attempt['user_id'] != userId) {
        throw Exception('Unauthorized');
      }

      if (attempt['status'] != 'in_progress') {
        throw Exception('الاختبار مكتمل بالفعل');
      }

      // Calculate time taken
      final startedAt = DateTime.parse(attempt['started_at']);
      final timeTaken = DateTime.now().difference(startedAt).inSeconds;

      // Update attempt with time taken
      await _client.from('exam_attempts').update({
        'time_taken': timeTaken,
        'status': 'submitted',
      }).eq('id', attemptId);

      // Calculate score using the database function
      await _client.rpc('calculate_exam_score', params: {
        'attempt_id_param': attemptId,
      });

      // Get the updated attempt with results
      final result = await _client
          .from('exam_attempts')
          .select('*, exams(title, passing_score)')
          .eq('id', attemptId)
          .single();

      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam attempt details with answers
  Future<Map<String, dynamic>?> getExamAttemptDetails(String attemptId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return null;

      final attempt = await _client
          .from('exam_attempts')
          .select('*, exams(*)')
          .eq('id', attemptId)
          .eq('user_id', userId)
          .single();

      // Get all answers for this attempt
      final answers = await _client
          .from('exam_answers')
          .select('*, questions(*)')
          .eq('attempt_id', attemptId);

      attempt['answers'] = answers;
      return attempt;
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam statistics for teacher
  Future<Map<String, dynamic>> getExamStats(String examId) async {
    try {
      // Get all attempts for this exam
      final attemptsResponse = await _client
          .from('exam_attempts')
          .select('id, score, total_points, user_id, users(full_name)')
          .eq('exam_id', examId)
          .eq('status', 'submitted');

      final attempts = SafeParser.safeMapList(attemptsResponse);

      if (attempts.isEmpty) {
        return {
          'attemptCount': 0,
          'averageScore': 0.0,
          'attempts': [],
          'questionStats': [],
        };
      }

      // Calculate average score
      double totalScore = 0;
      for (var attempt in attempts) {
        totalScore += (attempt['score'] as num).toDouble();
      }
      final averageScore = totalScore / attempts.length;

      // Get question stats
      // We need to fetch all answers for these attempts to calculate per-question stats
      final attemptIds = attempts.map((a) => a['id']).toList();
      final answersResponse = await _client
          .from('exam_answers')
          .select('question_id, is_correct, questions(question_text)')
          .filter('attempt_id', 'in', attemptIds);

      final answers = SafeParser.safeMapList(answersResponse);

      // Group by question
      final Map<String, Map<String, dynamic>> questionStatsMap = {};

      for (var answer in answers) {
        final qId = answer['question_id'] as String;
        final isCorrect = answer['is_correct'] as bool;
        final qText =
            answer['questions']?['question_text'] ?? 'Unknown Question';

        if (!questionStatsMap.containsKey(qId)) {
          questionStatsMap[qId] = {
            'questionId': qId,
            'questionText': qText,
            'correctCount': 0,
            'totalCount': 0,
            'wrongCount': 0,
          };
        }

        questionStatsMap[qId]!['totalCount']++;
        if (isCorrect) {
          questionStatsMap[qId]!['correctCount']++;
        } else {
          questionStatsMap[qId]!['wrongCount']++;
        }
      }

      return {
        'attemptCount': attempts.length,
        'averageScore': averageScore,
        'attempts': attempts,
        'questionStats': questionStatsMap.values.toList(),
      };
    } catch (e) {
      debugPrint('Error getting exam stats: $e');
      rethrow;
    }
  }

  /// Get all upcoming exams for enrolled courses
  Future<List<Map<String, dynamic>>> getUpcomingExams() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      // Get enrolled course IDs
      final enrollments = await _client
          .from('enrollments')
          .select('course_id')
          .eq('user_id', userId);

      if (enrollments.isEmpty) return [];

      final courseIds =
          enrollments.map((e) => e['course_id'] as String).toList();

      // Get exams for enrolled courses
      final exams = await _client
          .from('exams')
          .select('*, courses(title)')
          .eq('course_id', courseIds)
          .eq('is_published', true)
          .order('created_at', ascending: false);

      // Filter out completed exams
      final List<Map<String, dynamic>> upcomingExams = [];

      for (var exam in exams) {
        final attempts = await _client
            .from('exam_attempts')
            .select('id, status')
            .eq('user_id', userId)
            .eq('exam_id', exam['id'])
            .eq('status', 'graded');

        // If no completed attempts, it's upcoming
        if (attempts.isEmpty) {
          upcomingExams.add(exam);
        }
      }

      return upcomingExams;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all completed exams with results
  Future<List<Map<String, dynamic>>> getCompletedExams() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final attempts = await _client
          .from('exam_attempts')
          .select('*, exams(*, courses(title))')
          .eq('user_id', userId)
          .eq('status', 'graded')
          .order('submitted_at', ascending: false);

      return SafeParser.safeMapList(attempts);
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam statistics for a user
  Future<Map<String, dynamic>> getExamStatistics() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        return {
          'total_exams': 0,
          'passed_exams': 0,
          'failed_exams': 0,
          'average_score': 0.0,
        };
      }

      final attempts = await _client
          .from('exam_attempts')
          .select('is_passed, percentage')
          .eq('user_id', userId)
          .eq('status', 'graded');

      if (attempts.isEmpty) {
        return {
          'total_exams': 0,
          'passed_exams': 0,
          'failed_exams': 0,
          'average_score': 0.0,
        };
      }

      final totalExams = attempts.length;
      final passedExams = attempts.where((a) => a['is_passed'] == true).length;
      final failedExams = totalExams - passedExams;

      final totalPercentage = attempts.fold<double>(
        0.0,
        (sum, a) => sum + ((a['percentage'] as num?)?.toDouble() ?? 0.0),
      );
      final averageScore = totalPercentage / totalExams;

      return {
        'total_exams': totalExams,
        'passed_exams': passedExams,
        'failed_exams': failedExams,
        'average_score': averageScore,
      };
    } catch (e) {
      return {
        'total_exams': 0,
        'passed_exams': 0,
        'failed_exams': 0,
        'average_score': 0.0,
      };
    }
  }

  // ==================== PERMISSIONS & ROLES ====================

  /// Check if current user has a specific permission
  Future<bool> hasPermission(String permissionName) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return false;

      final result = await _client.rpc('has_permission', params: {
        'user_id_param': userId,
        'permission_name_param': permissionName,
      });

      return result as bool? ?? false;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }

  /// Get current user's role
  Future<String> getUserRole([String? userId]) async {
    final targetUserId = userId ?? SupabaseService.instance.currentUserId;
    if (targetUserId == null) return 'student';

    return fetchWithCache(
      key: 'user_role_$targetUserId',
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // Join user_roles with roles table to get role name
          final response = await _client
              .from('user_roles')
              .select('role_id, roles(name)')
              .eq('user_id', targetUserId)
              .maybeSingle();

          if (response == null) {
            debugPrint('⚠️ No role found for user, defaulting to student');
            return 'student';
          }

          // Extract role name from joined data
          final rolesData = response['roles'] as Map<String, dynamic>?;
          final role = rolesData?['name'] as String?;

          debugPrint(
              '✅ User role loaded: $role (role_id: ${response['role_id']})');
          return role ?? 'student';
        } catch (e) {
          debugPrint('❌ Error getting user role: $e');
          return 'student';
        }
      },
    );
  }

  /// Check if user is teacher or higher
  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher' || role == 'admin' || role == 'super_admin';
  }

  /// Check if user is admin or higher
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin' || role == 'super_admin';
  }

  /// Check if user is super admin
  Future<bool> isSuperAdmin() async {
    final role = await getUserRole();
    return role == 'super_admin';
  }

  /// Check if user is teacher of specific course
  Future<bool> isTeacherOfCourse(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return false;

      final result = await _client.rpc('is_teacher_of_course', params: {
        'user_id_param': userId,
        'course_id_param': courseId,
      });

      return result as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Assign role to user (Admin only)
  Future<void> assignRole(String userId, String roleName) async {
    try {
      final currentUserId = SupabaseService.instance.currentUserId;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get role ID
      final role = await _client
          .from('roles')
          .select('id')
          .eq('name', roleName)
          .single();

      // Remove existing roles
      await _client.from('user_roles').delete().eq('user_id', userId);

      // Assign new role
      await _client.from('user_roles').insert({
        'user_id': userId,
        'role_id': role['id'],
        'assigned_by': currentUserId,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Remove role from user (Admin only)
  Future<void> removeRole(String userId, String roleName) async {
    try {
      // Get role ID
      final role = await _client
          .from('roles')
          .select('id')
          .eq('name', roleName)
          .single();

      // Remove role
      await _client
          .from('user_roles')
          .delete()
          .eq('user_id', userId)
          .eq('role_id', role['id']);
    } catch (e) {
      rethrow;
    }
  }

  /// Save teacher profile data
  Future<void> saveTeacherProfile(Map<String, dynamic> data) async {
    try {
      final userId = data['id'];
      if (userId == null) throw 'User ID is required';

      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      // Update public users table (upsert handles both insert and update)
      await _client.from('users').upsert(data);

      // Also ensure teacher-specific table is updated
      // We extract only the fields needed for the teachers table
      await _client.from('teachers').upsert({
        'user_id': userId,
        'phone_number': data['phone_number'],
        'subscription_type': data['subscription_type'],
        'specialization': data['specialization'],
        'status': 'pending', // Default to pending for approval
      });

      // Automatic role assignment is disabled because teacher accounts now require manual approval by admin.
    } catch (e) {
      debugPrint('❌ Error saving teacher profile: $e');
      rethrow;
    }
  }

  /// Save student profile data
  Future<void> saveStudentProfile(Map<String, dynamic> data) async {
    try {
      final userId = data['id'];
      if (userId == null) throw 'User ID is required';

      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      data['status'] = 'approved';

      // Update public users table
      await _client.from('users').upsert(data);

      // Also ensure student-specific table is updated
      await _client.from('students').upsert({
        'user_id': userId,
        'education_level': data['education_level'],
        'grade': data['grade'],
        'specialization': data['specialization'],
      });

      // Also assign the student role if not already assigned
      try {
        await assignRole(userId, 'student');
      } catch (e) {
        debugPrint(
            '⚠️ Could not assign student role automatically (permission?): $e');
      }
    } catch (e) {
      debugPrint('❌ Error saving student profile: $e');
      rethrow;
    }
  }

  /// Get student profile by ID
  Future<Map<String, dynamic>?> getStudentProfile(String userId) async {
    try {
      return await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('❌ Error fetching student profile: $e');
      return null;
    }
  }

  /// Get teacher profile by ID
  Future<Map<String, dynamic>?> getTeacherProfile(String userId,
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'teacher_profile_$userId',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          return await _client
              .from('users')
              .select()
              .eq('id', userId)
              .maybeSingle();
        } catch (e) {
          debugPrint('❌ Error fetching teacher profile: $e');
          return null;
        }
      },
    );
  }

  /// Get all pending teacher registration requests
  Future<List<Map<String, dynamic>>> getPendingTeacherRequests() async {
    try {
      final response = await _client
          .from('users')
          .select()
          .eq('status', 'pending')
          .not('subscription_type', 'is', null);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('❌ Error fetching pending teacher requests: $e');
      return [];
    }
  }

  /// Update teacher registration status and optionally promote to teacher role
  Future<void> updateTeacherStatus(String userId, String status) async {
    try {
      await _client.from('users').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);

      if (status == 'approved') {
        await assignRole(userId, 'teacher');
      }
    } catch (e) {
      debugPrint('❌ Error updating teacher status: $e');
      rethrow;
    }
  }

  /// Update student profile
  Future<void> updateStudentProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _client.from('users').update(data).eq('id', userId);
    } catch (e) {
      debugPrint('❌ Error updating student profile: $e');
      rethrow;
    }
  }

  /// Update teacher profile
  Future<void> updateTeacherProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _client.from('users').update(data).eq('id', userId);
    } catch (e) {
      debugPrint('❌ Error updating teacher profile: $e');
      rethrow;
    }
  }

  /// Assign teacher to course (Admin only)
  Future<void> assignTeacherToCourse(String teacherId, String courseId) async {
    try {
      // Check if teacher is already assigned to this course
      final existing = await _client
          .from('teacher_courses')
          .select('id')
          .eq('teacher_id', teacherId)
          .eq('course_id', courseId)
          .maybeSingle();

      // If already assigned, skip insertion
      if (existing != null) {
        throw Exception('المدرس مرتبط بالفعل بهذه الدورة');
      }

      // Insert new assignment
      await _client.from('teacher_courses').insert({
        'teacher_id': teacherId,
        'course_id': courseId,
      });

      // SYNC: Update the instructor_id in courses table
      await _client.from('courses').update({
        'instructor_id': teacherId,
      }).eq('id', courseId);
    } catch (e) {
      rethrow;
    }
  }

  /// Remove teacher from course (Admin only)
  Future<void> removeTeacherFromCourse(
      String teacherId, String courseId) async {
    try {
      await _client
          .from('teacher_courses')
          .delete()
          .eq('teacher_id', teacherId)
          .eq('course_id', courseId);

      // This handles cases where another teacher might have been assigned in the meantime
      final courseData = await _client
          .from('courses')
          .select('instructor_id')
          .eq('id', courseId)
          .maybeSingle();

      if (courseData != null && courseData['instructor_id'] == teacherId) {
        await _client.from('courses').update({
          'instructor_id': null,
        }).eq('id', courseId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all roles
  Future<List<Map<String, dynamic>>> getRoles() async {
    try {
      final response = await _client.from('roles').select();
      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's roles
  Future<List<Map<String, dynamic>>> getUserRoles(String userId) async {
    try {
      final response = await _client
          .from('user_roles')
          .select('*, roles(*)')
          .eq('user_id', userId);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all permissions for a role
  Future<List<Map<String, dynamic>>> getRolePermissions(String roleName) async {
    try {
      final role = await _client
          .from('roles')
          .select('id')
          .eq('name', roleName)
          .single();

      final response = await _client
          .from('role_permissions')
          .select('*, permissions(*)')
          .eq('role_id', role['id']);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  // ==================== TEACHER DASHBOARD ====================

  /// Create exam (Teacher/Admin only)
  Future<String> createExam({
    required String courseId,
    required String title,
    required String description,
    required int duration,
    required int totalPoints,
    String? lessonId, // Added lessonId
    int passingScore = 60,
    int? maxAttempts,
    bool shuffleQuestions = false,
    bool shuffleOptions = false,
  }) async {
    try {
      final response = await _client
          .from('exams')
          .insert({
            'course_id': courseId,
            'lesson_id': lessonId, // Added lesson_id
            'title': title,
            'description': description,
            'duration': duration,
            'total_points': totalPoints,
            'passing_score': passingScore,
            'max_attempts': maxAttempts,
            'shuffle_questions': shuffleQuestions,
            'shuffle_options': shuffleOptions,
            'is_published': false,
          })
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Update exam (Teacher/Admin only)
  Future<void> updateExam(String examId, Map<String, dynamic> updates) async {
    try {
      await _client.from('exams').update(updates).eq('id', examId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete exam (Teacher/Admin only)
  Future<void> deleteExam(String examId) async {
    try {
      await _client.from('exams').delete().eq('id', examId);
    } catch (e) {
      rethrow;
    }
  }

  /// Publish/Unpublish exam (Teacher/Admin only)
  Future<void> toggleExamPublish(String examId, bool isPublished) async {
    try {
      await _client
          .from('exams')
          .update({'is_published': isPublished}).eq('id', examId);
    } catch (e) {
      rethrow;
    }
  }

  /// Add question to exam (Teacher/Admin only)
  Future<String> addQuestion({
    required String examId,
    required String questionText,
    required String questionType,
    required List<String> options,
    required dynamic correctAnswer,
    String? explanation,
    int points = 1,
    int orderIndex = 0,
  }) async {
    try {
      final response = await _client
          .from('questions')
          .insert({
            'exam_id': examId,
            'question_text': questionText,
            'question_type': questionType,
            'options': options,
            'correct_answer': correctAnswer,
            'explanation': explanation,
            'points': points,
            'order_index': orderIndex,
          })
          .select()
          .single();

      return response['id'] as String;
    } catch (e) {
      rethrow;
    }
  }

  /// Update question (Teacher/Admin only)
  Future<void> updateQuestion(
      String questionId, Map<String, dynamic> updates) async {
    try {
      await _client.from('questions').update(updates).eq('id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete question (Teacher/Admin only)
  Future<void> deleteQuestion(String questionId) async {
    try {
      await _client.from('questions').delete().eq('id', questionId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam attempts for teacher's exams
  Future<List<Map<String, dynamic>>> getExamAttemptsForTeacher(
      {String? examId}) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      // Check role first
      final role = await getUserRole(userId);
      final isAdmin =
          role == 'admin' || role == 'super_admin' || role == 'owner';

      // Build query base
      var query = _client.from('exam_attempts').select(
          '*, exams(title, course_id, courses(title)), users(full_name, email)');

      if (examId != null) {
        query = query.eq('exam_id', examId);
      } else if (!isAdmin) {
        // Teachers only: Get teacher's courses
        final teacherCourses = await _client
            .from('teacher_courses')
            .select('course_id')
            .eq('teacher_id', userId);

        if (teacherCourses.isEmpty) return [];

        final courseIds =
            teacherCourses.map((tc) => tc['course_id'] as String).toList();

        // Get exams for teacher's courses
        final exams = await _client
            .from('exams')
            .select('id')
            .inFilter('course_id', courseIds);

        final examIds = exams.map((e) => e['id'] as String).toList();
        if (examIds.isEmpty) return [];

        query = query.inFilter('exam_id', examIds);
      }

      final response = await query.order('started_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get exam statistics for teacher
  Future<Map<String, dynamic>> getExamStatisticsForTeacher(
      String examId) async {
    try {
      final attempts = await _client
          .from('exam_attempts')
          .select('score, percentage, is_passed')
          .eq('exam_id', examId)
          .eq('status', 'graded');

      if (attempts.isEmpty) {
        return {
          'total_attempts': 0,
          'average_score': 0.0,
          'pass_rate': 0.0,
          'highest_score': 0,
          'lowest_score': 0,
        };
      }

      final totalAttempts = attempts.length;
      final passedAttempts =
          attempts.where((a) => a['is_passed'] == true).length;
      final scores = attempts
          .map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0)
          .toList();

      return {
        'total_attempts': totalAttempts,
        'average_score': scores.reduce((a, b) => a + b) / totalAttempts,
        'pass_rate': (passedAttempts / totalAttempts) * 100,
        'highest_score': scores.reduce((a, b) => a > b ? a : b),
        'lowest_score': scores.reduce((a, b) => a < b ? a : b),
      };
    } catch (e) {
      return {
        'total_attempts': 0,
        'average_score': 0.0,
        'pass_rate': 0.0,
        'highest_score': 0,
        'lowest_score': 0,
      };
    }
  }

  // ==================== ADMIN DASHBOARD ====================

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client.from('users').select('*');
      final users = SafeParser.safeMapList(response);

      for (final user in users) {
        final userId = user['id']?.toString();
        if (userId == null || userId.isEmpty) {
          user['user_roles'] = <Map<String, dynamic>>[];
          continue;
        }

        try {
          user['user_roles'] = await getUserRoles(userId);
        } catch (e) {
          debugPrint('⚠️ Error loading roles for user $userId: $e');
          user['user_roles'] = <Map<String, dynamic>>[];
        }
      }

      return users;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserById(String userId,
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.userProfile(userId),
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          final response = await _client
              .from('users')
              .select('*')
              .eq('id', userId)
              .maybeSingle();
          return response;
        } catch (e) {
          debugPrint('Error getting user by ID: $e');
          return null;
        }
      },
    );
  }

  /// Get teacher statistics
  Future<Map<String, dynamic>> getTeacherStatistics(String teacherId,
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'teacher_stats_$teacherId',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          final isUuid = RegExp(
                  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
                  caseSensitive: false)
              .hasMatch(teacherId);

          String actualId = teacherId;
          if (!isUuid) {
            // If slug, find ID first
            final user = await _client
                .from('users')
                .select('id')
                .eq('slug', teacherId)
                .maybeSingle();
            if (user != null) {
              actualId = user['id'];
            }
          }

          final response = await _client.rpc('get_teacher_statistics',
              params: {'teacher_id_param': actualId});
          return response as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Error getting teacher stats: $e');
          return {};
        }
      },
    );
  }

  /// Get all teachers
  Future<List<Map<String, dynamic>>> getAllTeachers(
      {bool forceRefresh = false}) async {
    return await fetchWithCache(
      key: CacheKeys.teachers,
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 1),
      fetcher: () async {
        try {
          // Use RPC to bypass RLS and get teachers list cleanly
          final response = await _client.rpc('get_all_teachers_public');
          final data = SafeParser.safeMapList(response);

          // Normalize to a single top-level shape expected by admin screens.
          return data
              .map((t) {
                final avatar =
                    _formatAvatarUrl(t['avatar_url'], userId: t['user_id']);
                return {
                  'id': t['user_id'],
                  'user_id': t['user_id'],
                  'name': t['name'],
                  'full_name': t['name'],
                  'email': t['email'],
                  'avatar_url': avatar,
                  'photo_url': avatar,
                  'bio': t['bio'],
                  'subjects': t['subjects'],
                  'specialization': t['subjects'],
                  'teacher_status': t['teacher_status'] ?? 'approved',
                };
              })
              .where((t) => t['teacher_status'] == 'approved')
              .toList();
        } catch (e) {
          debugPrint('Error getting all teachers: $e');
          return [];
        }
      },
    );
  }

  /// Get teacher statistics for a specific date range (for monthly reports)
  Future<Map<String, dynamic>> getTeacherMonthlyStatistics(
    String teacherId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Adjust endDate to include the full day
      // Adjust endDate to include the full day of the last month in the range
      final inclusiveEndDate =
          DateTime(endDate.year, endDate.month + 1, 0, 23, 59, 59);

      // 0. Get course IDs for this teacher (Safe link)
      final teacherCourses = await _client
          .from('courses')
          .select('id')
          .eq('instructor_id', teacherId);
      final courseIdList =
          (teacherCourses as List).map((c) => c['id']).toList();

      // 1. Fetch teacher data from the view using BOTH instructor_id and course_ids
      var query = _client.from('admin_enrollments_view').select();

      if (courseIdList.isNotEmpty) {
        // Construct the in list for course_id
        final courseIdsStr = courseIdList.map((id) => '"$id"').join(',');
        query = query
            .or('instructor_id.eq.$teacherId,course_id.in.($courseIdsStr)');
      } else {
        query = query.eq('instructor_id', teacherId);
      }

      final response = await query;

      final rawEnrollments = SafeParser.safeMapList(response);

      // 2. Filter enrollments by date in Dart - using a more robust comparison
      final enrollments = rawEnrollments.where((e) {
        final date = _parseSafeDate(e['enrolled_at'])?.toLocal();
        if (date == null) return false;

        final start = DateTime(startDate.year, startDate.month, startDate.day);
        final end = DateTime(inclusiveEndDate.year, inclusiveEndDate.month,
            inclusiveEndDate.day, 23, 59, 59);

        return (date.isAfter(start.subtract(const Duration(seconds: 1))) ||
                date.isAtSameMomentAs(start)) &&
            (date.isBefore(end.add(const Duration(seconds: 1))) ||
                date.isAtSameMomentAs(end));
      }).toList();

      // 3. Get Course IDs for attempts
      final Set<String> courseIdSet = {};
      for (var e in rawEnrollments) {
        if (e['course_id'] != null) courseIdSet.add(e['course_id'].toString());
      }

      // Also add teacher's directly assigned courses from Step 0
      for (var id in courseIdList) {
        courseIdSet.add(id.toString());
      }
      final courseIds = courseIdSet.toList();

      // 4. Get exam attempts in this period
      List<Map<String, dynamic>> attempts = [];
      if (courseIds.isNotEmpty) {
        // First get all exam IDs for these courses because exam_attempts doesn't have course_id
        final examsResponse = await _client
            .from('exams')
            .select('id')
            .inFilter('course_id', courseIds);
        final examIds =
            (examsResponse as List).map((e) => e['id'] as String).toList();

        if (examIds.isNotEmpty) {
          final attemptsResponse = await _client
              .from('exam_attempts')
              .select('id, started_at, exam_id')
              .inFilter('exam_id', examIds)
              .gte('started_at', startDate.toIso8601String())
              .lte('started_at', inclusiveEndDate.toIso8601String());
          attempts = SafeParser.safeMapList(attemptsResponse);
        }
      }

      // 5. Calculate Summary Data for the filtered period
      double totalRevenue = 0;
      final distinctUserIds = <String>{};
      final monthlyData = <String, Map<String, dynamic>>{};

      for (var enrollment in enrollments) {
        double price = _safeDouble(enrollment['course_price']);
        totalRevenue += price;

        if (enrollment['user_id'] != null) {
          distinctUserIds.add(enrollment['user_id'].toString());
        }

        final enrollDate = _parseSafeDate(enrollment['enrolled_at']);
        if (enrollDate != null) {
          final monthKey =
              '${enrollDate.year}-${enrollDate.month.toString().padLeft(2, '0')}';

          if (!monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey] = {
              'month': monthKey,
              'enrollments': 0,
              'revenue': 0.0,
              'students': <String>{},
              'attempts': 0,
            };
          }

          monthlyData[monthKey]!['enrollments'] =
              (monthlyData[monthKey]!['enrollments'] as int) + 1;
          monthlyData[monthKey]!['revenue'] =
              (monthlyData[monthKey]!['revenue'] as double) + price;

          if (enrollment['user_id'] != null) {
            (monthlyData[monthKey]!['students'] as Set<String>)
                .add(enrollment['user_id'].toString());
          }
        }
      }

      // Add attempts by month
      for (var attempt in attempts) {
        final attemptDate = _parseSafeDate(attempt['started_at']);
        if (attemptDate != null) {
          final monthKey =
              '${attemptDate.year}-${attemptDate.month.toString().padLeft(2, '0')}';

          if (monthlyData.containsKey(monthKey)) {
            monthlyData[monthKey]!['attempts'] =
                (monthlyData[monthKey]!['attempts'] as int) + 1;
          } else {
            // Optional: if attempt happened in a month with no filtered enrollments
            // but within the report range, we could show it too.
            // But usually report range matches selected months.
          }
        }
      }

      // Format individual months
      final monthlyBreakdown = monthlyData.entries.map((entry) {
        return {
          'month': entry.key,
          'enrollments': entry.value['enrollments'],
          'revenue': entry.value['revenue'],
          'students': (entry.value['students'] as Set).length,
          'attempts': entry.value['attempts'],
        };
      }).toList();

      monthlyBreakdown.sort(
          (a, b) => (a['month'] as String).compareTo(b['month'] as String));

      return {
        'total_users': distinctUserIds.length,
        'total_enrollments': enrollments.length,
        'total_revenue': totalRevenue,
        'total_attempts': attempts.length,
        'monthly_breakdown': monthlyBreakdown,
        'enrollments':
            enrollments, // Added full details for the subscribers table
        'start_date': startDate.toIso8601String(),
        'end_date': inclusiveEndDate.toIso8601String(),
        'teacher_name': rawEnrollments.isNotEmpty
            ? rawEnrollments.first['instructor_name']
            : null,
      };
    } catch (e) {
      debugPrint('Error getting teacher monthly statistics: $e');
      return {
        'total_users': 0,
        'total_enrollments': 0,
        'total_revenue': 0.0,
        'total_attempts': 0,
        'monthly_breakdown': [],
      };
    }
  }

  // ==================== ADMIN: SUBSCRIPTIONS MANAGEMENT ====================

  /// Get recent exam attempts for a specific teacher's courses
  Future<List<Map<String, dynamic>>> getRecentTeacherExamAttempts(
      String teacherId,
      {int limit = 5}) async {
    try {
      final response = await _client
          .from('exam_attempts')
          .select(
              'id, score, total_points, percentage, is_passed, submitted_at, '
              'users(full_name, avatar_url), '
              'exams!inner(title, courses!inner(instructor_id))')
          .eq('exams.courses.instructor_id', teacherId)
          .order('submitted_at', ascending: false)
          .limit(limit);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting recent teacher exam attempts: $e');
      return [];
    }
  }

  // ==================== ADMIN: SUBSCRIPTIONS MANAGEMENT ====================

  /// Get all enrollments (Admin only)
  Future<List<Map<String, dynamic>>> getAllEnrollments({
    String? status,
    String? searchQuery,
    String? courseId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use the administrative view for reliable flattened data
      final PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _client.from('admin_enrollments_view').select();

      PostgrestFilterBuilder<List<Map<String, dynamic>>> filterQuery = query;

      if (status != null && status != 'all') {
        filterQuery = filterQuery.eq('status', status);
      }

      if (courseId != null) {
        filterQuery = filterQuery.eq('course_id', courseId);
      }

      if (startDate != null) {
        filterQuery =
            filterQuery.gte('enrolled_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        filterQuery = filterQuery.lt('enrolled_at', endDate.toIso8601String());
      }

      final response = await filterQuery.order('enrolled_at', ascending: false);
      final rawData = SafeParser.safeMapList(response);

      // Reconstruct UI compatible structure
      final enrollments = rawData.map((row) {
        return {
          'id': row['id'],
          'user_id': row['user_id'],
          'course_id': row['course_id'],
          'status': row['status'],
          'enrolled_at': row['enrolled_at'],
          'expires_at': row['expires_at'],
          'updated_at': row['updated_at'],
          'progress': row['progress'],
          'users': {
            'id': row['user_id'],
            'full_name': row['user_full_name'],
            'email': row['user_email'],
            'avatar_url': row['user_avatar_url'],
          },
          'courses': {
            'id': row['course_id'],
            'title': row['course_title'],
            'thumbnail':
                row['course_image_url'], // Map image_url to thumbnail for UI
            'price': row['course_price'],
            'instructor_name': row['instructor_name'],
          }
        };
      }).toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final search = searchQuery.toLowerCase();
        return enrollments.where((e) {
          final userName =
              e['users']['full_name']?.toString().toLowerCase() ?? '';
          final courseTitle =
              e['courses']['title']?.toString().toLowerCase() ?? '';
          return userName.contains(search) || courseTitle.contains(search);
        }).toList();
      }

      return enrollments;
    } catch (e) {
      debugPrint('Error getting all enrollments via view: $e');
      // If view fails, try the fallback join logic
      return _getAllEnrollmentsFallback(status, searchQuery);
    }
  }

  Future<List<Map<String, dynamic>>> _getAllEnrollmentsFallback(
      String? status, String? searchQuery) async {
    try {
      var query = _client.from('enrollments').select('*');
      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }
      final response = await query.order('enrolled_at', ascending: false);
      final enrollments = SafeParser.safeMapList(response);

      for (var enrollment in enrollments) {
        try {
          final course = await _client
              .from('courses')
              .select('id, title, image_url, price')
              .eq('id', enrollment['course_id'])
              .maybeSingle();
          if (course != null) {
            course['thumbnail'] = course['image_url']; // Normalization
          }
          enrollment['courses'] = course;

          final user = await _client
              .from('users')
              .select('id, full_name, email, avatar_url')
              .eq('id', enrollment['user_id'])
              .maybeSingle();
          enrollment['users'] = user;
        } catch (_) {}
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final search = searchQuery.toLowerCase();
        return enrollments.where((e) {
          final userName =
              e['users']?['full_name']?.toString().toLowerCase() ?? '';
          final courseTitle =
              e['courses']?['title']?.toString().toLowerCase() ?? '';
          return userName.contains(search) || courseTitle.contains(search);
        }).toList();
      }
      return enrollments;
    } catch (e) {
      debugPrint('Fallback failed: $e');
      return [];
    }
  }

  /// Get subscription statistics (Admin only)
  Future<Map<String, dynamic>> getSubscriptionStats() async {
    try {
      // Use the view for stats as well to ensure we get prices
      final response = await _client
          .from('admin_enrollments_view')
          .select('status, enrolled_at, expires_at, course_price');
      final enrollments = SafeParser.safeMapList(response);

      int totalEnrollments = enrollments.length;
      int activeCount = 0;
      int expiredCount = 0;
      double totalRevenue = 0.0;

      for (var row in enrollments) {
        final status = row['status'] as String?;
        if (status == 'active') {
          activeCount++;
        } else if (status == 'expired') {
          expiredCount++;
        }

        final price = row['course_price'] as num?;
        if (price != null) totalRevenue += price.toDouble();
      }

      // Format for monthly revenue helper
      final mappedEnrollments = enrollments
          .map((e) => {
                'enrolled_at': e['enrolled_at'],
                'courses': {'price': e['course_price']}
              })
          .toList();

      return {
        'total_enrollments': totalEnrollments,
        'active_subscriptions': activeCount,
        'expired_subscriptions': expiredCount,
        'total_revenue': totalRevenue,
        'monthly_revenue': _calculateMonthlyRevenue(mappedEnrollments),
      };
    } catch (e) {
      debugPrint('Error getting subscription stats: $e');
      return {
        'total_enrollments': 0,
        'active_subscriptions': 0,
        'expired_subscriptions': 0,
        'total_revenue': 0.0,
        'monthly_revenue': 0.0,
      };
    }
  }

  double _calculateMonthlyRevenue(List<Map<String, dynamic>> enrollments) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    double monthlyRevenue = 0.0;

    for (var enrollment in enrollments) {
      final enrolledAtStr = enrollment['enrolled_at'] as String?;
      if (enrolledAtStr != null) {
        final enrolledAt = DateTime.parse(enrolledAtStr);
        if (enrolledAt.isAfter(firstDayOfMonth)) {
          final courseData = enrollment['courses'] as Map<String, dynamic>?;
          final price = courseData?['price'] as num?;
          if (price != null) {
            monthlyRevenue += price.toDouble();
          }
        }
      }
    }
    return monthlyRevenue;
  }

  /// Get enrollments grouped by course
  Future<List<Map<String, dynamic>>> getEnrollmentsGroupedByCourse({
    String? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final enrollments = await getAllEnrollments(
        status: status,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
      );
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var enrollment in enrollments) {
        final course = enrollment['courses'] as Map<String, dynamic>?;
        if (course == null) continue;

        final courseId = course['id']?.toString() ?? 'unknown';
        if (!grouped.containsKey(courseId)) {
          grouped[courseId] = {
            'course': course,
            'enrollment_count': 0,
            'total_revenue': 0.0,
            'active_count': 0,
            'enrollments': [],
          };
        }

        grouped[courseId]!['enrollment_count']++;
        grouped[courseId]!['enrollments'].add(enrollment);
        final price = course['price'] as num? ?? 0;
        grouped[courseId]!['total_revenue'] += price.toDouble();
        if (enrollment['status'] == 'active') {
          grouped[courseId]!['active_count']++;
        }
      }

      return grouped.values.toList()
        ..sort((a, b) => (b['total_revenue'] as double)
            .compareTo(a['total_revenue'] as double));
    } catch (e) {
      debugPrint('Error grouping enrollments by course: $e');
      return [];
    }
  }

  /// Get enrollments grouped by teacher
  Future<List<Map<String, dynamic>>> getEnrollmentsGroupedByTeacher({
    String? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use the administrative view for reliable flattened data
      var query = _client.from('admin_enrollments_view').select();

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }
      if (startDate != null) {
        query = query.gte('enrolled_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lt('enrolled_at', endDate.toIso8601String());
      }

      final response = await query.order('enrolled_at', ascending: false);
      var rawData = SafeParser.safeMapList(response);

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final search = searchQuery.toLowerCase();
        rawData = rawData.where((row) {
          final userName =
              row['user_full_name']?.toString().toLowerCase() ?? '';
          final courseTitle =
              row['course_title']?.toString().toLowerCase() ?? '';
          final instructorName =
              row['instructor_name']?.toString().toLowerCase() ?? '';
          return userName.contains(search) ||
              courseTitle.contains(search) ||
              instructorName.contains(search);
        }).toList();
      }

      final Map<String, Map<String, dynamic>> grouped = {};

      for (var row in rawData) {
        final teacherId = row['instructor_id']?.toString() ?? 'unknown';

        if (!grouped.containsKey(teacherId)) {
          grouped[teacherId] = {
            'teacher': {
              'id': row['instructor_id'],
              'full_name': row['instructor_name'] ?? 'مدرس غير معروف',
            },
            'student_count': 0,
            'total_revenue': 0.0,
            '_course_ids': <String>{},
            'enrollments': [],
          };
        }

        // Reconstruct UI compatible enrollment structure for the list
        final enrollment = {
          'id': row['id'],
          'user_id': row['user_id'],
          'course_id': row['course_id'],
          'status': row['status'],
          'enrolled_at': row['enrolled_at'],
          'expires_at': row['expires_at'],
          'users': {
            'full_name': row['user_full_name'],
            'email': row['user_email'],
            'avatar_url': row['user_avatar_url'],
          },
          'courses': {
            'title': row['course_title'],
            'price': row['course_price'],
            'id': row['course_id'],
            'thumbnail': row['course_image_url'],
          }
        };
        grouped[teacherId]!['enrollments'].add(enrollment);

        if (row['course_id'] != null) {
          (grouped[teacherId]!['_course_ids'] as Set<String>)
              .add(row['course_id'].toString());
        }

        grouped[teacherId]!['student_count']++;
        final price = row['course_price'] as num? ?? 0;
        grouped[teacherId]!['total_revenue'] += price.toDouble();
      }

      final result = grouped.values.map((item) {
        item['course_count'] = (item['_course_ids'] as Set<String>).length;
        item.remove('_course_ids');
        return item;
      }).toList();

      return result
        ..sort((a, b) => (b['total_revenue'] as double)
            .compareTo(a['total_revenue'] as double));
    } catch (e) {
      debugPrint('Error grouping enrollments by teacher: $e');
      return [];
    }
  }

  /// Get detailed stats for a specific teacher
  Future<Map<String, dynamic>> getTeacherDetailedStats(String teacherId) async {
    try {
      final response = await _client
          .from('admin_enrollments_view')
          .select()
          .eq('instructor_id', teacherId);

      final rawData = SafeParser.safeMapList(response);

      double totalRevenue = 0;
      int totalStudents = rawData.length;
      Map<String, Map<String, dynamic>> coursesStats = {};

      for (var row in rawData) {
        final price = _safeDouble(row['course_price']);
        totalRevenue += price;

        final courseId = row['course_id']?.toString() ?? 'unknown';
        if (!coursesStats.containsKey(courseId)) {
          coursesStats[courseId] = {
            'id': courseId,
            'title': row['course_title'] ?? 'دورة غير معروفة',
            'student_count': 0,
            'revenue': 0.0,
            'image_url': row['course_image_url'],
          };
        }
        coursesStats[courseId]!['student_count']++;
        coursesStats[courseId]!['revenue'] =
            (coursesStats[courseId]!['revenue'] as double) + price;
      }

      return {
        'total_revenue': totalRevenue,
        'student_count': totalStudents,
        'course_count': coursesStats.length,
        'courses_breakdown': coursesStats.values.toList()
          ..sort((a, b) =>
              (b['revenue'] as double).compareTo(a['revenue'] as double)),
        'recent_enrollments': rawData.take(10).toList(),
      };
    } catch (e) {
      debugPrint('Error getting teacher detailed stats: $e');
      return {};
    }
  }

  /// Update enrollment status (Admin only)
  Future<void> updateEnrollmentStatus(
      String enrollmentId, String status) async {
    try {
      await _client.from('enrollments').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('id', enrollmentId);

      debugPrint('✅ Enrollment status updated: $enrollmentId -> $status');
    } catch (e) {
      debugPrint('Error updating enrollment status: $e');
      rethrow;
    }
  }

  // ==================== ADMIN: COURSE MANAGEMENT ====================

  /// Create a new course (Admin only)
  Future<String> createCourse(Map<String, dynamic> data) async {
    try {
      final instructorId = data['instructor_id'];

      final response =
          await _client.from('courses').insert(data).select('id').single();

      final courseId = response['id'];

      // Assign teacher to course in teacher_courses table if instructor specified
      if (instructorId != null) {
        await assignTeacherToCourse(instructorId, courseId);
      }

      return courseId;
    } catch (e) {
      rethrow;
    }
  }

  /// Update course (Admin only)
  Future<void> updateCourse(String courseId, Map<String, dynamic> data) async {
    try {
      await _client.from('courses').update(data).eq('id', courseId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete course (Admin only)
  Future<void> deleteCourse(String courseId) async {
    try {
      // Get the image URL before deleting the course
      final response = await _client
          .from('courses')
          .select('image_url')
          .eq('id', courseId)
          .maybeSingle();

      final imageUrl = response?['image_url'] as String?;

      await _client.from('courses').delete().eq('id', courseId);

      // If the image is on Supabase, delete it to save space
      if (imageUrl != null && imageUrl.contains('supabase.co')) {
        try {
          await ImageUploadService().deleteImage(imageUrl, 'courses');
        } catch (e) {
          debugPrint('Error deleting course image: $e');
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==================== ADMIN: LESSON MANAGEMENT ====================

  /// Create a new lesson (Admin only)
  Future<String> createLesson(Map<String, dynamic> data) async {
    try {
      final response =
          await _client.from('lessons').insert(data).select('id').single();
      final lessonId = response['id'];

      // Update course total duration
      if (data['course_id'] != null) {
        await updateCourseTotalDuration(data['course_id']);
      }

      return lessonId;
    } catch (e) {
      rethrow;
    }
  }

  /// Update lesson (Admin only)
  Future<void> updateLesson(String lessonId, Map<String, dynamic> data) async {
    try {
      await _client.from('lessons').update(data).eq('id', lessonId);

      // If we don't have course_id in data, we need to fetch it to update duration
      String? courseId = data['course_id'];
      if (courseId == null) {
        final lesson = await _client
            .from('lessons')
            .select('course_id')
            .eq('id', lessonId)
            .single();
        courseId = lesson['course_id'];
      }

      if (courseId != null) {
        await updateCourseTotalDuration(courseId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete lesson (Admin only)
  Future<void> deleteLesson(String lessonId) async {
    try {
      // Get course_id before deleting
      final lesson = await _client
          .from('lessons')
          .select('course_id')
          .eq('id', lessonId)
          .single();
      final courseId = lesson['course_id'];

      await _client.from('lessons').delete().eq('id', lessonId);

      if (courseId != null) {
        await updateCourseTotalDuration(courseId);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get all lessons for a course (Admin - no progress)

  /// Reorder lessons (modern upsert)
  Future<void> reorderLessons(List<Map<String, dynamic>> updates) async {
    try {
      await _client.from('lessons').upsert(updates);
    } catch (e) {
      rethrow;
    }
  }

  /// Update the total duration of a course based on its lessons
  Future<void> updateCourseTotalDuration(String courseId) async {
    try {
      final response = await _client
          .from('lessons')
          .select('duration')
          .eq('course_id', courseId);

      final lessons = SafeParser.safeMapList(response);
      int totalSeconds = 0;

      for (var lesson in lessons) {
        final durationRaw = lesson['duration'];
        if (durationRaw == null) continue;

        if (durationRaw is int) {
          totalSeconds += durationRaw;
        } else if (durationRaw is String) {
          // Parse HH:MM:SS or MM:SS
          final parts = durationRaw.split(':').reversed.toList();
          if (parts.isNotEmpty) {
            totalSeconds += int.tryParse(parts[0]) ?? 0; // seconds
            if (parts.length > 1) {
              totalSeconds += (int.tryParse(parts[1]) ?? 0) * 60; // minutes
            }
            if (parts.length > 2) {
              totalSeconds += (int.tryParse(parts[2]) ?? 0) * 3600; // hours
            }
          }
        }
      }

      // Format the total duration
      String formattedDuration;
      final h = totalSeconds ~/ 3600;
      final m = (totalSeconds % 3600) ~/ 60;

      if (h > 0) {
        formattedDuration = '$h:${m.toString().padLeft(2, '0')} ساعة';
      } else if (m > 0) {
        formattedDuration = '$m دقيقة';
      } else {
        formattedDuration = '0';
      }

      await _client
          .from('courses')
          .update({'duration_hours': formattedDuration}).eq('id', courseId);

      // Clear cache for this course
      await LocalDatabase().remove('course_$courseId');
      await LocalDatabase().remove('courses_all');
    } catch (e) {
      debugPrint('Error updating course total duration: $e');
    }
  }

  // ==================== STATISTICS ====================

  /// Get course statistics
  Future<Map<String, dynamic>> getCourseStatistics(String courseId) async {
    try {
      // Fetch enrollments for the course
      final response = await _client
          .from('enrollments')
          .select('id, progress, status')
          .eq('course_id', courseId);

      final enrollments = SafeParser.safeMapList(response);

      // Total lessons in the course
      final lessonsResponse =
          await _client.from('lessons').select('id').eq('course_id', courseId);
      final totalLessons = (lessonsResponse as List).length;

      // Calculate completed enrollments and average progress
      int completedCount = 0;
      double totalProgress = 0;

      for (var e in enrollments) {
        final progress = (e['progress'] as num?)?.toDouble() ?? 0.0;
        final status = e['status'] as String?;

        if (progress >= 100 || status == 'completed') {
          completedCount++;
        }
        totalProgress += progress;
      }

      double avgProgress =
          enrollments.isEmpty ? 0 : totalProgress / enrollments.length;

      return {
        'total_enrollments': enrollments.length,
        'completed_enrollments': completedCount,
        'total_lessons': totalLessons,
        'average_progress': avgProgress.round(),
        'completion_rate': enrollments.isEmpty
            ? 0
            : ((completedCount / enrollments.length) * 100).round(),
      };
    } catch (e) {
      debugPrint('Error getting course statistics: $e');
      return {
        'total_enrollments': 0,
        'completed_enrollments': 0,
        'total_lessons': 0,
        'average_progress': 0,
        'completion_rate': 0,
      };
    }
  }

  /// Get lesson statistics
  Future<Map<String, dynamic>> getLessonStatistics(String lessonId) async {
    try {
      // Total views
      final views = await _client
          .from('lesson_progress')
          .select('id')
          .eq('lesson_id', lessonId);

      // Completed views
      final completed = await _client
          .from('lesson_progress')
          .select('id')
          .eq('lesson_id', lessonId)
          .eq('is_completed', true);

      return {
        'total_views': views.length,
        'completed_views': completed.length,
        'completion_rate': views.isEmpty
            ? 0
            : ((completed.length / views.length) * 100).round(),
      };
    } catch (e) {
      return {
        'total_views': 0,
        'completed_views': 0,
        'completion_rate': 0,
      };
    }
  }

  // ==================== PAYMENTS & SUBSCRIPTIONS ====================

  /// Create a new order
  Future<Map<String, dynamic>> createOrder({
    required double amount,
    required String paymentMethod,
    String? transactionId,
    String? courseId,
    String? bundleId,
    String? discountCodeId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final orderData = <String, dynamic>{
        'user_id': userId,
        'order_number': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        'total_amount': amount,
        'payment_method': paymentMethod,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'order_type': bundleId != null
            ? 'bundle'
            : (courseId != null ? 'course' : 'subscription'),
      };

      if (transactionId != null) orderData['payment_transaction_id'] = transactionId;
      if (courseId != null) orderData['course_id'] = courseId;
      if (bundleId != null) orderData['bundle_id'] = bundleId;
      if (discountCodeId != null) orderData['discount_code_id'] = discountCodeId;

      final response =
          await _client.from('orders').insert(orderData).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _client.from('orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  /// Activate user subscription
  Future<void> activateSubscription({
    required String userId,
    required String planId,
    required int durationMonths,
  }) async {
    try {
      final startDate = DateTime.now();
      final endDate = DateTime(
          startDate.year, startDate.month + durationMonths, startDate.day);

      await _client.from('user_subscriptions').upsert({
        'user_id': userId,
        'plan_id': planId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'is_active': true,
      }, onConflict: 'user_id,plan_id');

      debugPrint('Subscription activated for user $userId, plan $planId');
    } catch (e) {
      debugPrint('Error activating subscription: $e');
      rethrow;
    }
  }

  /// Get user orders
  Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      try {
        final response = await _client
            .from('orders')
            .select('*, courses(title), bundles(title), payment_receipts(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        return SafeParser.safeMapList(response);
      } catch (e) {
        // If table doesn't exist, return empty
        return [];
      }
    } catch (e) {
      debugPrint('Error getting user orders: $e');
      // Return empty list if table doesn't exist (PGRST205) or any other error
      return [];
    }
  }

  // ==================== DISCOUNT CODES ====================

  /// Get discount code details by code string
  Future<Map<String, dynamic>?> getDiscountCode(String code) async {
    try {
      final response = await _client
          .from('discount_codes')
          .select()
          .eq('code', code.toUpperCase())
          .eq('is_active', true)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching discount code: $e');
      return null;
    }
  }

  /// Increment usage count for a discount code
  Future<void> incrementDiscountCodeUsage(String codeId) async {
    try {
      // In a real app, you might use an RPC or a trigger
      // Here we'll do a simple update
      final current = await _client
          .from('discount_codes')
          .select('usage_count')
          .eq('id', codeId)
          .single();

      final currentCount = (current['usage_count'] as int? ?? 0);

      await _client
          .from('discount_codes')
          .update({'usage_count': currentCount + 1}).eq('id', codeId);
    } catch (e) {
      debugPrint('Error incrementing discount code usage: $e');
    }
  }

  // ==================== PAYMENT RECEIPTS & ACCOUNTS ====================

  /// Upload receipt image to Supabase Storage
  Future<String?> uploadReceiptImage(String filePath, String fileName) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Create unique file name with user ID and timestamp
      final uniqueFileName =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Upload to Supabase Storage
      await _client.storage
          .from('payment-receipts')
          .uploadBinary(uniqueFileName, bytes);

      // Get public URL
      final publicUrl =
          _client.storage.from('payment-receipts').getPublicUrl(uniqueFileName);

      debugPrint('Receipt uploaded: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      return null;
    }
  }

  /// Create payment receipt
  Future<String?> createPaymentReceipt({
    required String orderId,
    required String paymentMethod,
    required double amount,
    String? transactionId,
    String? receiptImageUrl,
    String? phoneNumber,
    String? courseId,
    String? bundleId,
    String? discountCodeId,
    String? senderName,
    double? paidAmount,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final receiptData = <String, dynamic>{
        'order_id': orderId,
        'user_id': userId,
        'payment_method': paymentMethod,
        'amount': amount,
        'status': 'pending',
      };

      if (courseId != null) receiptData['course_id'] = courseId;
      if (bundleId != null) receiptData['bundle_id'] = bundleId;
      if (discountCodeId != null) receiptData['discount_code_id'] = discountCodeId;
      if (transactionId != null) receiptData['transaction_id'] = transactionId;
      if (receiptImageUrl != null) receiptData['receipt_image_url'] = receiptImageUrl;
      if (phoneNumber != null) receiptData['phone_number'] = phoneNumber;
      if (senderName != null) receiptData['sender_name'] = senderName;
      if (paidAmount != null) receiptData['paid_amount'] = paidAmount;

      final response = await _client
          .from('payment_receipts')
          .insert(receiptData)
          .select()
          .single();

      debugPrint('Payment receipt created: ${response['id']}');
      return response['id'] as String;
    } catch (e) {
      debugPrint('Error creating payment receipt: $e');
      rethrow;
    }
  }

  /// Get payment receipts for current user
  Future<List<Map<String, dynamic>>> getUserPaymentReceipts() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from('payment_receipts')
          .select('*, orders(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting user payment receipts: $e');
      return [];
    }
  }

  /// Check if user has a pending payment receipt for a specific course
  Future<bool> hasPendingCourseRequest(String courseId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _client
          .from('payment_receipts')
          .select('id')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .inFilter('status', ['pending', 'under_review']).maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking pending course request: $e');
      return false;
    }
  }

  /// Get all payment receipts (Admin only)
  Future<List<Map<String, dynamic>>> getAllPaymentReceipts({
    String? status,
  }) async {
    try {
      var query = _client.from('payment_receipts').select(
          '*, orders(*), users!user_id(full_name, email), courses(title, image_url)');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting all payment receipts: $e');
      return [];
    }
  }

  /// Get payment receipt by ID
  Future<Map<String, dynamic>?> getPaymentReceiptById(String receiptId) async {
    try {
      final response = await _client
          .from('payment_receipts')
          .select(
              '*, orders(*), users!user_id(full_name, email), courses(title)')
          .eq('id', receiptId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('Error getting payment receipt: $e');
      return null;
    }
  }

  /// Approve payment receipt and activate subscription (Admin only)
  Future<void> approvePaymentReceipt({
    required String receiptId,
    String? adminNotes,
  }) async {
    try {
      // Logic is now prioritized in the database RPC/trigger
      await _client.rpc('approve_payment_receipt', params: {
        'receipt_id_param': receiptId,
        'admin_notes_param': adminNotes,
      });

      debugPrint('Payment receipt approved: $receiptId');
    } catch (e) {
      debugPrint('Error approving payment receipt: $e');
      rethrow;
    }
  }

  /// Reject payment receipt (Admin only)
  Future<void> rejectPaymentReceipt({
    required String receiptId,
    String? adminNotes,
  }) async {
    try {
      await _client.rpc('reject_payment_receipt', params: {
        'receipt_id_param': receiptId,
        'admin_notes_param': adminNotes,
      });

      debugPrint('Payment receipt rejected: $receiptId');
    } catch (e) {
      debugPrint('Error rejecting payment receipt: $e');
      rethrow;
    }
  }

  /// Get payment statistics (Admin only)
  Future<Map<String, dynamic>> getPaymentStatistics() async {
    try {
      // Total receipts
      final allReceipts =
          await _client.from('payment_receipts').select('status, amount');

      final pending = allReceipts.where((r) => r['status'] == 'pending').length;
      final approved =
          allReceipts.where((r) => r['status'] == 'approved').length;
      final rejected =
          allReceipts.where((r) => r['status'] == 'rejected').length;

      final totalRevenue = allReceipts
          .where((r) => r['status'] == 'approved')
          .fold<double>(0, (sum, r) => sum + (r['amount'] as num).toDouble());

      return {
        'total_receipts': allReceipts.length,
        'pending_receipts': pending,
        'approved_receipts': approved,
        'rejected_receipts': rejected,
        'total_revenue': totalRevenue,
      };
    } catch (e) {
      debugPrint('Error getting payment statistics: $e');
      return {
        'total_receipts': 0,
        'pending_receipts': 0,
        'approved_receipts': 0,
        'rejected_receipts': 0,
        'total_revenue': 0.0,
      };
    }
  }

  // ==================== Q&A / COMMUNITY ====================

  /// Get questions for a lesson
  Future<List<Map<String, dynamic>>> getLessonQuestions(String lessonId) async {
    try {
      // 1. Fetch questions with author data, basic replies, and reaction summary
      final response = await _client
          .from('lesson_questions')
          .select(
              '*, users!user_id(full_name, avatar_url), question_replies(*)')
          .eq('lesson_id', lessonId)
          .order('created_at', ascending: false);

      final questions = SafeParser.safeMapList(response);

      final userId = SupabaseService.instance.currentUserId;

      // 2. Collect all User IDs from replies to fetch their info
      final replyUserIds = <String>{};
      final questionIds = questions.map((q) => q['id'].toString()).toList();
      final replyIds = <String>[];

      for (var q in questions) {
        if (q['question_replies'] != null) {
          for (var r in q['question_replies']) {
            if (r['user_id'] != null) {
              replyUserIds.add(r['user_id']);
            }
            replyIds.add(r['id'].toString());
          }
        }
      }

      // 3. Fetch user details for those IDs and reactions if possible
      final userMap = <String, dynamic>{};
      if (replyUserIds.isNotEmpty) {
        final usersResponse = await _client
            .from('users')
            .select('id, full_name, avatar_url')
            .inFilter('id', replyUserIds.toList());

        for (var u in usersResponse) {
          userMap[u['id']] = u;
        }
      }

      // Build reaction summaries
      try {
        final allItemIds = [...questionIds, ...replyIds];
        if (allItemIds.isNotEmpty) {
          // Construct the OR filter string safely
          final qFilter = questionIds.isNotEmpty
              ? 'question_id.in.(${questionIds.join(",")})'
              : '';
          final rFilter =
              replyIds.isNotEmpty ? 'reply_id.in.(${replyIds.join(",")})' : '';

          String combinedFilter = '';
          if (qFilter.isNotEmpty && rFilter.isNotEmpty) {
            combinedFilter = '$qFilter,$rFilter';
          } else {
            combinedFilter = qFilter.isNotEmpty ? qFilter : rFilter;
          }

          final reactionsResponse = await _client
              .from('lesson_question_reactions')
              .select()
              .or(combinedFilter);

          final reactions = SafeParser.safeMapList(reactionsResponse);

          void processReactions(Map<String, dynamic> item, String idKey) {
            final id = item['id'].toString();
            final itemReactions =
                reactions.where((r) => r[idKey]?.toString() == id).toList();

            final summary = <String, int>{};
            for (var r in itemReactions) {
              final type = r['reaction_type'].toString();
              summary[type] = (summary[type] ?? 0) + 1;
              if (r['user_id'] == userId) {
                item['my_reaction'] = type;
              }
            }
            item['reaction_summary'] = summary;
          }

          for (var q in questions) {
            processReactions(q, 'question_id');
            if (q['question_replies'] != null) {
              for (var r in q['question_replies']) {
                processReactions(r, 'reply_id');
                if (r['user_id'] != null && userMap.containsKey(r['user_id'])) {
                  r['users'] = userMap[r['user_id']];
                }
              }
            }
          }
        }
      } catch (e) {
        // If reactions table doesn't exist, just proceed without them
        debugPrint('Reactions table might be missing: $e');
        for (var q in questions) {
          if (q['question_replies'] != null) {
            for (var r in q['question_replies']) {
              if (r['user_id'] != null && userMap.containsKey(r['user_id'])) {
                r['users'] = userMap[r['user_id']];
              }
            }
          }
        }
      }

      return questions;
    } catch (e) {
      debugPrint('Error getting lesson questions: $e');
      return [];
    }
  }

  /// Ask a question about a lesson
  Future<void> askLessonQuestion(String lessonId, String content) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      await _client.from('lesson_questions').insert({
        'lesson_id': lessonId,
        'user_id': userId,
        'content': content,
      });
    } catch (e) {
      debugPrint('Error adding question: $e');
      rethrow;
    }
  }

  /// Get replies for a question
  Future<List<Map<String, dynamic>>> getQuestionReplies(
      String questionId) async {
    try {
      final response = await _client
          .from('question_replies')
          .select('*, users!user_id(full_name, avatar_url)')
          .eq('question_id', questionId)
          .order('created_at', ascending: true);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting question replies: $e');
      return [];
    }
  }

  /// Add a reply to a question
  Future<void> addReply(String questionId, String content) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      await _client.from('question_replies').insert({
        'question_id': questionId,
        'user_id': userId,
        'content': content,
        'is_instructor_reply': false,
      });
    } catch (e) {
      debugPrint('Error adding reply: $e');
      rethrow;
    }
  }

  /// Delete a question
  Future<void> deleteLessonQuestion(String questionId) async {
    try {
      await _client.from('lesson_questions').delete().eq('id', questionId);
    } catch (e) {
      debugPrint('Error deleting question: $e');
      rethrow;
    }
  }

  /// Delete a reply
  Future<void> deleteReply(String replyId) async {
    try {
      await _client.from('question_replies').delete().eq('id', replyId);
    } catch (e) {
      debugPrint('Error deleting reply: $e');
      rethrow;
    }
  }

  /// Update a question
  Future<void> updateLessonQuestion(String questionId, String content) async {
    try {
      await _client
          .from('lesson_questions')
          .update({'content': content}).eq('id', questionId);
    } catch (e) {
      debugPrint('Error updating question: $e');
      rethrow;
    }
  }

  /// Update a reply
  Future<void> updateReply(String replyId, String content) async {
    try {
      await _client
          .from('question_replies')
          .update({'content': content}).eq('id', replyId);
    } catch (e) {
      debugPrint('Error updating reply: $e');
      rethrow;
    }
  }

  /// Toggle a reaction on a question or reply
  Future<void> toggleReaction({
    String? questionId,
    String? replyId,
    required String reactionType,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not logged in');

      // Check for existing reaction
      var query = _client
          .from('lesson_question_reactions')
          .select()
          .eq('user_id', userId);

      if (questionId != null) query = query.eq('question_id', questionId);
      if (replyId != null) query = query.eq('reply_id', replyId);

      final existing = await query.maybeSingle();

      if (existing != null) {
        if (existing['reaction_type'] == reactionType) {
          // Remove if same
          await _client
              .from('lesson_question_reactions')
              .delete()
              .eq('id', existing['id']);
        } else {
          // Update if different
          await _client
              .from('lesson_question_reactions')
              .update({'reaction_type': reactionType}).eq('id', existing['id']);
        }
      } else {
        // Add new
        await _client.from('lesson_question_reactions').insert({
          'user_id': userId,
          'question_id': questionId,
          'reply_id': replyId,
          'reaction_type': reactionType,
        });
      }
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      rethrow;
    }
  }

  // ==================== DYNAMIC PROGRESS & FEATURED CONTENT ====================

  /// Get user enrollments with progress data
  Future<List<Map<String, dynamic>>> getUserEnrollmentsWithProgress(
      String userId) async {
    return fetchWithCache(
      key: 'user_${userId}_enrollments_v2',
      duration: const Duration(minutes: 15),
      fetcher: () async {
        try {
          final response = await _client.from('enrollments').select('''
                *,
                courses(*),
                last_accessed_lesson:lessons!last_accessed_lesson_id(*)
              ''').eq('user_id', userId).order('updated_at', ascending: false);

          return SafeParser.safeMapList(response);
        } catch (e) {
          debugPrint('Error fetching enrollments with progress: $e');
          rethrow;
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getFeaturedCourses(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.featuredCourses,
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 2),
      fetcher: () async {
        try {
          final response = await _client
              .from('courses')
              .select('*, users!instructor_id(full_name, avatar_url)')
              .eq('is_featured', true)
              .eq('is_published', true)
              .order('featured_order', ascending: true)
              .limit(5);

          final data = SafeParser.safeMapList(response);

          // Map joined data to flat structure
          return data
              .map((course) {
                final user = course['users'];
                if (user != null) {
                  course['instructor_name'] =
                      user['full_name'] ?? course['instructor_name'];
                  course['instructor_photo'] =
                      user['avatar_url'] ?? course['instructor_photo'];
                }
                return course;
              })
              .toList()
              .cast<Map<String, dynamic>>();
        } catch (e) {
          debugPrint('Error fetching featured courses: $e');
          return [];
        }
      },
    );
  }

  /// Update enrollment progress (called after lesson completion)
  Future<void> updateEnrollmentProgress(
      String enrollmentId, String courseId) async {
    try {
      await _client.rpc('update_enrollment_progress', params: {
        'p_enrollment_id': enrollmentId,
        'p_course_id': courseId,
      });
    } catch (e) {
      debugPrint('Error updating enrollment progress: $e');
      rethrow;
    }
  }

  /// Update last accessed lesson for an enrollment
  Future<void> updateLastAccessedLesson(
      String enrollmentId, String lessonId) async {
    try {
      await _client
          .from('enrollments')
          .update({'last_accessed_lesson_id': lessonId}).eq('id', enrollmentId);
    } catch (e) {
      debugPrint('Error updating last accessed lesson: $e');
      rethrow;
    }
  }

  /// Get enrollment by course for current user
  Future<Map<String, dynamic>?> getEnrollmentByCourse(
      String userId, String courseId) async {
    try {
      final response = await _client
          .from('enrollments')
          .select()
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching enrollment: $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Get all notifications for current user
  /// Get all notifications for current user (including global ones)
  Future<List<Map<String, dynamic>>> getUserNotifications() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      // 1. User specific notifications
      final userResponse = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      final notifications = SafeParser.safeMapList(userResponse);

      // 2. Global admin notifications (type = 'all')
      try {
        final adminResponse = await _client
            .from('admin_notifications')
            .select()
            .eq('notification_type', 'all')
            .order('created_at', ascending: false)
            .limit(20);

        final adminNotifications = SafeParser.safeMapList(adminResponse);

        for (var adminNotif in adminNotifications) {
          // Avoid duplicates if app already saved it locally
          // We assume if title and body match and time is close, it's a diff one?
          // For simplicity, just add them. The ID will be different.

          // Only add if not already present (by ID check - useless if diff tables)
          // Just add them as read-only items

          notifications.add({
            'id': adminNotif['id'], // Use admin notif ID
            'user_id': userId,
            'title': adminNotif['title'],
            'body': adminNotif['body'],
            'data': {'type': 'admin_broadcast'},
            'is_read': true, // Mark global ones as read to avoid update errors
            'created_at': adminNotif['created_at'],
          });
        }
      } catch (e) {
        debugPrint('Error fetching admin notifications: $e');
        // Continue with just user notifications
      }

      // 3. Sort merged list
      notifications.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA); // Newest first
      });

      return notifications;
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }

  /// Get unread notifications count
  Future<int> getUnreadNotificationsCount() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return 0;

      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_read', false);

      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }

  /// Mark notification as read
  Future<void> setNotificationRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> setAllNotificationsRead() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      await _client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  /// Delete all notifications for current user
  Future<void> deleteAllNotifications() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      await _client.from('notifications').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
      rethrow;
    }
  }

  // ==================== NOTIFICATION PREFERENCES ====================

  /// Get user notification preferences
  Future<Map<String, bool>> getNotificationPreferences(String userId) async {
    try {
      final response = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Return defaults if no record exists
        return {
          'email_marketing': true,
          'push_learning': true,
          'push_social': true,
          'push_marketing': false,
        };
      }

      return {
        'email_marketing': response['email_marketing'] ?? true,
        'push_learning': response['push_learning'] ?? true,
        'push_social': response['push_social'] ?? true,
        'push_marketing': response['push_marketing'] ?? false,
      };
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
      return {
        'email_marketing': true,
        'push_learning': true,
        'push_social': true,
        'push_marketing': false,
      };
    }
  }

  /// Update user notification preferences
  Future<void> updateNotificationPreferences(
      String userId, Map<String, bool> preferences) async {
    try {
      await _client.from('notification_preferences').upsert({
        'user_id': userId,
        ...preferences,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating notification preferences: $e');
      rethrow;
    }
  }

  // ==================== PAYMENT ACCOUNTS ====================

  Future<List<PaymentAccount>> getPaymentAccounts() async {
    try {
      final response = await _client
          .from('payment_accounts')
          .select()
          .order('display_order');
      return (response as List).map((e) => PaymentAccount.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error getting payment accounts: $e');
      return [];
    }
  }

  Future<void> updatePaymentAccount(PaymentAccount account) async {
    try {
      await _client.from('payment_accounts').update({
        'account_number': account.accountNumber,
        'account_name': account.accountName,
        'instructions': account.instructions,
        'is_active': account.isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', account.id);
    } catch (e) {
      debugPrint('Error updating payment account: $e');
      rethrow;
    }
  }

  // ==================== QR CODE METHODS ====================

  /// Generate a unique QR code
  String _generateUniqueCode() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999).toString().padLeft(6, '0');
    return 'QR-$timestamp-$randomPart';
  }

  /// Generate bulk QR codes with batch tracking
  Future<List<Map<String, dynamic>>> generateBulkQrCodes({
    required List<String> courseIds,
    required String batchName,
    required int quantity,
    required DateTime expiryDate,
    required double totalPrice,
    int discountPercent = 0,
  }) async {
    try {
      final batchId = const Uuid().v4();
      final userId = _client.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('المستخدم غير مصرح');
      }

      final codes = <Map<String, dynamic>>[];

      for (int i = 0; i < quantity; i++) {
        final code = _generateUniqueCode();
        codes.add({
          'code': code,
          'course_ids': courseIds,
          'batch_name': batchName,
          'batch_id': batchId,
          'expires_at': expiryDate.toIso8601String(),
          'created_by': userId,
          'is_redeemed': false,
          'type': 'course',
          'price':
              totalPrice, // This is the total price for the specific code (bundle)
          'discount_percent': discountPercent,
        });
      }

      final response = await _client.from('qr_codes').insert(codes).select();

      debugPrint('Generated ${codes.length} QR codes in batch: $batchName');
      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error generating bulk QR codes: $e');
      rethrow;
    }
  }

  /// Get QR codes by batch ID
  Future<List<Map<String, dynamic>>> getQrCodesByBatch(String batchId) async {
    try {
      final response = await _client
          .from('qr_codes')
          .select()
          .eq('batch_id', batchId)
          .order('created_at', ascending: true);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting QR codes by batch: $e');
      rethrow;
    }
  }

  /// Get all QR codes (for admin) with pagination and search
  Future<List<Map<String, dynamic>>> getAllQrCodes({
    int page = 0,
    int pageSize = 50,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('qr_codes').select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query
            .or('code.ilike.%$searchQuery%,batch_name.ilike.%$searchQuery%');
      }

      final from = page * pageSize;
      final to = from + pageSize - 1;

      final response =
          await query.order('created_at', ascending: false).range(from, to);

      return SafeParser.safeMapList(response);
    } catch (e) {
      debugPrint('Error getting all QR codes: $e');
      return [];
    }
  }

  /// Get unique batches (for filtering/viewing)
  Future<List<Map<String, dynamic>>> getQrBatches() async {
    try {
      final response = await _client
          .from('qr_codes')
          .select('batch_id, batch_name, created_at, created_by')
          .not('batch_id', 'is', null)
          .order('created_at', ascending: false);

      // Get unique batches
      final Map<String, Map<String, dynamic>> uniqueBatches = {};
      for (final row in response) {
        final batchId = row['batch_id'] as String?;
        if (batchId != null && !uniqueBatches.containsKey(batchId)) {
          uniqueBatches[batchId] = row;
        }
      }

      return uniqueBatches.values.toList();
    } catch (e) {
      debugPrint('Error getting QR batches: $e');
      return [];
    }
  }

  /// Redeem a QR code (single-use enforcement)
  Future<Map<String, dynamic>> redeemQrCode(String code, String userId) async {
    try {
      // Fetch the QR code
      final qrResponse =
          await _client.from('qr_codes').select().eq('code', code).single();

      final qrData = qrResponse;

      // Check if already redeemed
      if (qrData['is_redeemed'] == true) {
        throw Exception(
            'هذا الكود تم استخدامه من قبل في ${qrData['redeemed_at']}');
      }

      // Check expiry
      final expiresAt = DateTime.parse(qrData['expires_at']);
      if (expiresAt.isBefore(DateTime.now())) {
        throw Exception('انتهت صلاحية هذا الكود');
      }

      // Get course IDs
      final courseIds = List<String>.from(qrData['course_ids'] ?? []);
      if (courseIds.isEmpty) {
        throw Exception('هذا الكود غير صالح - لا توجد مواد مرتبطة');
      }

      // Enroll user in all courses
      for (final courseId in courseIds) {
        // Check if already enrolled
        final existingEnrollment = await _client
            .from('enrollments')
            .select()
            .eq('user_id', userId)
            .eq('course_id', courseId)
            .maybeSingle();

        if (existingEnrollment == null) {
          // Fetch course price to calculate paid amount
          final courseRes = await _client
              .from('courses')
              .select('price')
              .eq('id', courseId)
              .single();

          final double originalPrice =
              (courseRes['price'] as num? ?? 0).toDouble();
          final int discountPercent = qrData['discount_percent'] ?? 0;
          final double paidAmount =
              originalPrice * (1 - (discountPercent / 100.0));

          await _client.from('enrollments').insert({
            'user_id': userId,
            'course_id': courseId,
            'status': 'active',
            'enrolled_at': DateTime.now().toIso8601String(),
            'paid_amount': paidAmount,
            'discount_applied': discountPercent,
          });
        }
      }

      // Mark QR code as redeemed
      await _client.from('qr_codes').update({
        'is_redeemed': true,
        'redeemed_at': DateTime.now().toIso8601String(),
        'redeemed_by': userId,
      }).eq('id', qrData['id']);

      // Record usage in qr_code_usage table
      await _client.from('qr_code_usage').insert({
        'qr_code_id': qrData['id'],
        'user_id': userId,
        'redeemed_at': DateTime.now().toIso8601String(),
      });

      debugPrint('QR code redeemed successfully: $code');
      return {
        'success': true,
        'message': 'تم تفعيل الاشتراك بنجاح',
        'courses_enrolled': courseIds.length,
        'batch_name': qrData['batch_name'],
      };
    } catch (e) {
      debugPrint('Error redeeming QR code: $e');
      rethrow;
    }
  }

  /// Delete a batch of QR codes
  Future<void> deleteQrBatch(String batchId) async {
    try {
      await _client.from('qr_codes').delete().eq('batch_id', batchId);

      debugPrint(' Deleted QR batch: $batchId');
    } catch (e) {
      debugPrint('Error deleting QR batch: $e');
      rethrow;
    }
  }

  // ==================== FINANCIAL REPORTS ====================

  // ==================== FINANCIAL REPORTS ====================

  /// Get detailed financial report
  Future<Map<String, dynamic>> getDetailedFinancialReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // 1. Fetch regular enrollments (view might already include them, but let's be safe and clear)
      var query = _client.from('admin_enrollments_view').select();

      if (startDate != null) {
        query = query.gte('enrolled_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        // Add one day to include the end date fully
        final adjustedEndDate = endDate.add(const Duration(days: 1));
        query = query.lt('enrolled_at', adjustedEndDate.toIso8601String());
      }

      final response = await query.order('enrolled_at', ascending: false);
      final rawData = SafeParser.safeMapList(response);

      // 2. Fetch QR Code usage for the same period (Safely)
      List<Map<String, dynamic>> qrData = [];
      try {
        var qrQuery = _client.from('qr_code_usage').select('''
           *,
           qr_codes!inner(batch_name, type),
           users!inner(full_name, email)
         ''');

        if (startDate != null) {
          qrQuery = qrQuery.gte('redeemed_at', startDate.toIso8601String());
        }
        if (endDate != null) {
          final adjustedEndDate = endDate.add(const Duration(days: 1));
          qrQuery =
              qrQuery.lt('redeemed_at', adjustedEndDate.toIso8601String());
        }

        final qrResponse = await qrQuery.order('redeemed_at', ascending: false);
        qrData = SafeParser.safeMapList(qrResponse);
      } catch (e) {
        debugPrint('⚠️ Error fetching QR data for report: $e');
        // Continue without QR data
      }

      // 3. Process regular enrollments
      double totalRevenue = 0;

      final List<Map<String, dynamic>> reportItems = [];

      for (var row in rawData) {
        final price = (row['course_price'] as num? ?? 0).toDouble();
        totalRevenue += price;

        row['payment_method'] = 'نقدي / آخر'; // Default

        reportItems.add(row);
      }

      final qrUserIds = qrData.map((e) => e['user_id']).toSet();

      for (var item in reportItems) {
        if (qrUserIds.contains(item['user_id'])) {
          item['payment_method'] = 'رمز QR';
        }
      }

      return {
        'total_revenue': totalRevenue,
        'total_enrollments': rawData.length,
        'enrollments': reportItems,
        'period': startDate != null && endDate != null
            ? '${startDate.toString().split(' ')[0]} - ${endDate.toString().split(' ')[0]}'
            : 'الكل',
        'qr_redemptions_count': qrData.length, // Extra stat
      };
    } catch (e) {
      debugPrint('Error getting financial report: $e');
      return {
        'total_revenue': 0.0,
        'total_enrollments': 0,
        'enrollments': [],
        'period': '-',
      };
    }
  }

  DateTime? _parseSafeDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        String s = value.trim();
        if (s.length >= 10 && s[10] == ' ') {
          s = s.replaceRange(10, 11, 'T');
        }
        return DateTime.tryParse(s) ?? DateTime.tryParse(value);
      } catch (_) {
        return DateTime.tryParse(value);
      }
    }
    return null;
  }

  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Add a new app update record
  Future<void> addAppUpdate({
    required String versionName,
    required String downloadUrl,
    String? releaseNotes,
    bool isMandatory = false,
  }) async {
    try {
      await _client.from('app_updates').insert({
        'version_name': versionName,
        'download_url': downloadUrl,
        'release_notes': releaseNotes,
        'is_mandatory': isMandatory,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error adding app update: $e');
      rethrow;
    }
  }

  // ==================== STATISTICS ====================

  /// Get general system statistics for admin
  Future<Map<String, dynamic>> getSystemStatistics(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'system_stats_all',
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 30),
      fetcher: () async {
        try {
          final usersResponse = await _client.from('users').select('id');
          final coursesResponse = await _client.from('courses').select('id');
          final examsResponse = await _client.from('exams').select('id');
          final attemptsResponse =
              await _client.from('exam_attempts').select('id');

          // Active Users (7 days)
          final lastWeek = DateTime.now()
              .subtract(const Duration(days: 7))
              .toIso8601String();
          final activeInEnrollments = await _client
              .from('enrollments')
              .select('user_id')
              .gte('enrolled_at', lastWeek);
          final activeInExams = await _client
              .from('exam_attempts')
              .select('user_id')
              .gte('submitted_at', lastWeek);

          final Set<String> activeUsersSet = {};
          for (var row in activeInEnrollments as List) {
            activeUsersSet.add(row['user_id'] as String);
          }
          for (var row in activeInExams as List) {
            activeUsersSet.add(row['user_id'] as String);
          }

          // Weekly Growth Data (7 days)
          final List<double> dailyActivity = List.filled(7, 0.1);
          final now = DateTime.now();
          final enrollmentsLastWeek = await _client
              .from('enrollments')
              .select('enrolled_at')
              .gte('enrolled_at', lastWeek);

          for (var enrollment in enrollmentsLastWeek as List) {
            final date = DateTime.tryParse(enrollment['enrolled_at'] ?? '');
            if (date != null) {
              final dayIndex = 6 - now.difference(date).inDays;
              if (dayIndex >= 0 && dayIndex < 7) {
                dailyActivity[dayIndex] += 1;
              }
            }
          }

          double totalThisWeek = dailyActivity.reduce((a, b) => a + b);
          double growthPercentage = totalThisWeek > 0
              ? (totalThisWeek / (usersResponse as List).length * 100)
                  .clamp(1.0, 25.0)
              : 0.0;

          final revenueRes =
              await _client.from('enrollments').select('paid_amount');
          double totalRevenue = 0;
          for (var row in revenueRes as List) {
            totalRevenue += (row['paid_amount'] as num? ?? 0).toDouble();
          }

          return {
            'total_users': (usersResponse as List).length,
            'active_users': activeUsersSet.length,
            'total_courses': (coursesResponse as List).length,
            'total_exams': (examsResponse as List).length,
            'total_attempts': (attemptsResponse as List).length,
            'total_revenue': totalRevenue,
            'weekly_growth': growthPercentage.toStringAsFixed(1),
            'daily_activity': dailyActivity,
          };
        } catch (e) {
          debugPrint('Error fetching system stats: $e');
          return {
            'total_users': 0,
            'active_users': 0,
            'total_courses': 0,
            'total_exams': 0,
            'total_attempts': 0,
            'total_revenue': 0,
            'weekly_growth': '0.0',
            'daily_activity': [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7],
          };
        }
      },
    );
  }

  /// Refresh all caches (Global)
  Future<void> refreshAllCaches() async {
    await LocalDatabase().clear();
    debugPrint('✅ Global cache cleared');
  }

  // ==================== APP SETTINGS & SOCIAL LINKS ====================

  /// Get Social Media Links from app_settings
  Future<Map<String, String>> getSocialLinks(
      {bool forceRefresh = false}) async {
    final result = await fetchWithCache(
      key: CacheKeys.socialLinks,
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 12),
      fetcher: () async {
        try {
          final response = await _client
              .from('app_settings')
              .select('setting_key, setting_value')
              .like('setting_key', 'social_%');

          final List rows = response as List;
          Map<String, String> links = {};
          for (var row in rows) {
            if (row['setting_value'] != null &&
                row['setting_value'].toString().isNotEmpty) {
              links[row['setting_key'] as String] =
                  row['setting_value'] as String;
            }
          }
          return links;
        } catch (e) {
          debugPrint('Error fetching social links: $e');
          return {};
        }
      },
    );
    
    if (result is Map) {
      return result.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return {};
  }

  /// Save Social Media Links to app_settings
  Future<void> saveSocialLinks(Map<String, String> links) async {
    try {
      for (var entry in links.entries) {
        final existing = await _client
            .from('app_settings')
            .select('id')
            .eq('setting_key', entry.key)
            .maybeSingle();

        if (existing != null) {
          await _client.from('app_settings').update({
            'setting_value': entry.value,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', existing['id']);
        } else {
          await _client.from('app_settings').insert({
            'setting_key': entry.key,
            'setting_value': entry.value,
            'description': 'Social link for ${entry.key}',
          });
        }
      }
      // Clear cache after update
      await LocalDatabase().remove(CacheKeys.socialLinks);
    } catch (e) {
      debugPrint('Error saving social links: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getCourseSessions(String courseId) async {
    try {
      final response = await _client
          .from('sessions')
          .select()
          .eq('course_id', courseId)
          .order('scheduled_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting course sessions: $e');
      rethrow;
    }
  }
}
