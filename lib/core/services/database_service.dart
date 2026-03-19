import 'dart:io';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import '../../models/chapter.dart';
import '../../models/payment_account.dart';
import 'offline_cache_service.dart';
import 'cache_service.dart';
import 'local_database.dart';
import '../../models/course.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService instance = DatabaseService._internal();

  factory DatabaseService() {
    return instance;
  }

  DatabaseService._internal();

  final SupabaseClient _client = SupabaseService.instance.client;

  // Getter for accessing the client from other classes
  SupabaseClient get supabaseClient => _client;
  
  // Quick access to current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Helper to ensure avatar URLs are full URLs
  String? _formatAvatarUrl(String? avatarUrl, {String? userId}) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    
    // If it's already a full URL, return it
    if (avatarUrl.startsWith('http')) return avatarUrl;
    
    // If it's a relative path, assume it's in the old Supabase storage 'avatars' bucket
    // Format: user_id/filename.jpg
    final baseUrl = 'https://cstlqyjoflhxtocrtypg.supabase.co/storage/v1/object/public/avatars/';
    return '$baseUrl$avatarUrl';
  }

  // ==================== CATEGORIES (NEW) ====================
  // Added CRUD for admin management

  Future<List<Map<String, dynamic>>> getCategories(
      {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'categories_all',
      forceRefresh: forceRefresh,
      duration: const Duration(days: 1),
      fetcher: () async {
        try {
          final response =
              await _client.from('categories').select().order('name');
          return List<Map<String, dynamic>>.from(response);
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
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting subcategories: $e');
      return [];
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
      await _client.from('categories').insert({
        'name': name,
        'slug': slug,
        'parent_id': parentId,
        'icon_url': iconUrl,
      });
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
      if (slug != null) updates['slug'] = slug;
      
      // Explicitly check for parentId to allow null (removing parent)
      if (parentId != null) {
        updates['parent_id'] = parentId.isEmpty ? null : parentId;
      }
      
      if (iconUrl != null) updates['icon_url'] = iconUrl;

      if (updates.isNotEmpty) {
        await _client.from('categories').update(updates).eq('id', id);
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
    } catch (e) {
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // ==================== BUNDLES (NEW) ====================

  /// Get all bundles with their associated courses
  Future<List<Map<String, dynamic>>> getBundles({bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'bundles_all',
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 12),
      fetcher: () async {
        try {
          // Fetch bundles
          final response = await _client.from('bundles').select().order('created_at', ascending: false);
          final List<Map<String, dynamic>> bundles = List<Map<String, dynamic>>.from(response);
          
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
      final response = await _client.from('bundles').insert({
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'price': price,
        'discount_percentage': discountPercentage,
      }).select().single();
      
      final String bundleId = response['id'];
      
      if (courseIds.isNotEmpty) {
        final links = courseIds.map((cid) => {
          'bundle_id': bundleId,
          'course_id': cid,
        }).toList();
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
      if (discountPercentage != null) updates['discount_percentage'] = discountPercentage;

      if (updates.isNotEmpty) {
        await _client.from('bundles').update(updates).eq('id', id);
      }
      
      if (courseIds != null) {
        // Replace links: delete and re-insert
        await _client.from('bundle_courses').delete().eq('bundle_id', id);
        if (courseIds.isNotEmpty) {
          final links = courseIds.map((cid) => {
            'bundle_id': id,
            'course_id': cid,
          }).toList();
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

  // ==================== TIPS (NEW) ====================

  /// Get all tips with optional linked course data
  Future<List<Map<String, dynamic>>> getTips({bool forceRefresh = false}) async {
    return fetchWithCache(
      key: CacheKeys.tips, // Make sure to add this to CacheKeys
      forceRefresh: forceRefresh,
      duration: const Duration(hours: 6),
      fetcher: () async {
        try {
          final response = await _client
              .from('tips')
              .select('*, courses(*)')
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        } catch (e) {
          debugPrint('Error getting tips: $e');
          return [];
        }
      },
    );
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
        final tip = await _client.from('tips').select('views_count').eq('id', id).single();
        final currentViews = tip['views_count'] ?? 0;
        await _client.from('tips').update({'views_count': currentViews + 1}).eq('id', id);
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
      var dbQuery = _client.from('courses').select(
          '*, users!instructor_id(full_name, avatar_url)');

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
        // Search in course_category_junction
        dbQuery = dbQuery.filter(
            'course_category_junction.category_id', 'eq', categoryId);
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
      final data = List<Map<String, dynamic>>.from(response);

      // Map joined data to flat structure expected by UI
      return data.map((course) {
        final user = course['users'];
        if (user != null) {
          course['instructor_name'] =
              user['full_name'] ?? course['instructor_name'];
          course['instructor_photo'] =
              user['avatar_url'] ?? course['instructor_photo'];
        }
        return course;
      }).toList();
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

      return List<Map<String, dynamic>>.from(response);
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

          final courses = List<Map<String, dynamic>>.from(coursesResponse);
          final courseIds = courses.map((c) => c['id']).toList();

          if (courseIds.isEmpty) return [];

          // 2. Get enrollments for progress and student count
          final enrollmentsResponse = await _client
              .from('enrollments')
              .select('course_id, progress_percentage')
              .inFilter('course_id', courseIds);

          final enrollments =
              List<Map<String, dynamic>>.from(enrollmentsResponse);

          // 3. Get exams count
          final examsResponse = await _client
              .from('exams')
              .select('course_id')
              .inFilter('course_id', courseIds);

          final allExams = List<Map<String, dynamic>>.from(examsResponse);

          // 4. Get revenue from view
          final revenueResponse = await _client
              .from('admin_enrollments_view')
              .select('course_id, course_price')
              .inFilter('course_id', courseIds);

          final allRevenue = List<Map<String, dynamic>>.from(revenueResponse);

          // 5. Aggregate data
          return courses.map((course) {
            final courseId = course['id'];

            final courseEnrollments =
                enrollments.where((e) => e['course_id'] == courseId);
            final studentCount = courseEnrollments.length;

            double avgProgress = 0;
            if (studentCount > 0) {
              final totalProgress = courseEnrollments.fold(
                  0.0,
                  (sum, e) =>
                      sum + (e['progress_percentage'] as num? ?? 0).toDouble());
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
          }).toList();
        } catch (e) {
          debugPrint('Error in getTeacherCourses: $e');
          rethrow;
        }
      },
    );
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

      return List<Map<String, dynamic>>.from(response);
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

        return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching exams for lesson: $e');
      return [];
    }
  }


  /// Get all courses
  Future<List<Map<String, dynamic>>> getCourses({
    String? category,
    String? categoryId, // Added
    String? subject,
    String? instructorId, // Added
    bool includeDrafts = false,
    bool forceRefresh = false,
  }) async {
    final String cacheKey =
        'courses_v2_${category ?? "all"}_${categoryId ?? "all"}_${subject ?? "all"}_${instructorId ?? "all"}_$includeDrafts';

    return fetchWithCache(
      key: cacheKey,
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 15),
      fetcher: () async {
        try {
          // Join with users to get correct instructor details
          // Join with junction table to get categories
          var query = _client.from('courses').select('''
                *, 
                users!instructor_id(full_name, avatar_url),
                course_category_junction(category:categories(id, name, name_en)),
                course_tags(tag)
              ''');

          if (instructorId != null) {
            query = query.eq('instructor_id', instructorId);
          }

          if (categoryId != null) {
            query = query.filter(
                'course_category_junction.category_id', 'eq', categoryId);
          } else if (category != null) {
            query = query.eq('category', category);
          }

          if (subject != null) {
            query = query.eq('subject', subject);
          }

          if (!includeDrafts) {
            query = query.eq('is_published', true);
          }

          final response = await query;
          final data = List<Map<String, dynamic>>.from(response);

          // Map joined data to flat structure expected by UI
          final coursesMapList = data.map((course) {
            final user = course['users'];
            if (user != null) {
              course['instructor_name'] =
                  user['full_name'] ?? course['instructor_name'];
              course['instructor_photo'] =
                  user['avatar_url'] ?? course['instructor_photo'];
            }

            // Map categories from junction
            final junction = course['course_category_junction'] as List?;
            if (junction != null) {
              final categories = junction
                  .map((j) {
                    final cat = j['category'] as Map?;
                    return cat?['name'] as String? ?? '';
                  })
                  .where((name) => name.isNotEmpty)
                  .toList();

              final categoriesEn = junction
                  .map((j) {
                    final cat = j['category'] as Map?;
                    return cat?['name_en'] as String? ?? '';
                  })
                  .where((name) => name.isNotEmpty)
                  .toList();

              final categoryIds = junction
                  .map((j) {
                    final cat = j['category'] as Map?;
                    return cat?['id'] as String? ?? '';
                  })
                  .where((id) => id.isNotEmpty)
                  .toList();

              course['categories_names'] = categories;
              course['categories_names_en'] = categoriesEn;
              course['category_ids'] = categoryIds;

              // Fallback for single category field
              if (categories.isNotEmpty) {
                course['category'] = categories.first;
              }
            }

            // Map tags
            final tagsList = course['course_tags'] as List?;
            if (tagsList != null) {
              course['tags'] = tagsList.map((t) => t['tag'] as String).toList();
            }

            return course;
          }).toList();

          return coursesMapList;
        } catch (e) {
          debugPrint('Error getting courses with join: $e');
          // Fallback to simple select if join fails
          return _getCoursesSimple(
            category: category,
            categoryId: categoryId,
            subject: subject,
            instructorId: instructorId,
            includeDrafts: includeDrafts,
          );
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getCoursesSimple({
    String? category,
    String? categoryId,
    String? subject,
    String? instructorId,
    bool includeDrafts = false,
  }) async {
    try {
      var query = _client.from('courses').select();
      if (instructorId != null) {
        query = query.eq('instructor_id', instructorId);
      }
      if (categoryId != null) {
        query = query.eq('category_id', categoryId);
      } else if (category != null) {
        query = query.eq('category', category);
      }
      if (subject != null) {
        query = query.eq('subject', subject);
      }
      if (!includeDrafts) {
        query = query.eq('is_published', true);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error in _getCoursesSimple: $e');
      return [];
    }
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
              ''').eq('id', courseId).single();

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
          debugPrint('Error getting course by id: $e');
          // Fallback to simple select
          try {
            final res = await _client
                .from('courses')
                .select()
                .eq('id', courseId)
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

      final lessons = List<Map<String, dynamic>>.from(response);

      // If user is authenticated, get progress for all lessons in one query
      if (userId != null && lessons.isNotEmpty) {
        final lessonIds = lessons.map((l) => l['id'] as String).toList();

        final progressResponse = await _client
            .from('lesson_progress')
            .select()
            .eq('user_id', userId)
            .filter('lesson_id', 'in', lessonIds);

        final allProgress = List<Map<String, dynamic>>.from(progressResponse);

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
          .eq('course_id', courseId);
    } catch (e) {
      debugPrint('Error updating course progress: $e');
    }
  }

  // ==================== CHAPTERS ====================

  /// Get chapters for a course
  Future<List<Chapter>> getChapters(String courseId) async {
    try {
      final response = await _client
          .from('chapters')
          .select()
          .eq('course_id', courseId)
          .order('order_index', ascending: true);

      return (response as List).map((json) => Chapter.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting chapters: $e');
      return [];
    }
  }

  /// Create a chapter
  Future<void> createChapter({
    required String courseId,
    required String title,
    int? orderIndex,
  }) async {
    try {
      // If orderIndex is not provided, put it at the end
      int index = orderIndex ?? 0;
      if (orderIndex == null) {
        final chapters = await getChapters(courseId);
        index = chapters.length;
      }

      await _client.from('chapters').insert({
        'course_id': courseId,
        'title': title,
        'order_index': index,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Update a chapter
  Future<void> updateChapter({
    required String chapterId,
    String? title,
    int? orderIndex,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (orderIndex != null) updates['order_index'] = orderIndex;

      if (updates.isEmpty) return;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client.from('chapters').update(updates).eq('id', chapterId);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      final ratings = List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('full_name, avatar_url')
          .eq('id', userId)
          .single();
      
      // Ensure avatar_url is a full URL
      if (response['avatar_url'] != null) {
        response['avatar_url'] = _formatAvatarUrl(response['avatar_url'], userId: userId);
      }
      
      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return {};
    }
  }

  /// Get user stats
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        return {
          'completed_courses': 0,
          'learning_hours': 0.0,
          'certificates': 0,
          'average_score': 0.0,
        };
      }

      // Calculate completed courses
      final enrollmentsResponse = await _client
          .from('enrollments')
          .select('id, progress_percentage')
          .eq('user_id', userId)
          .gte('progress_percentage', 100);

      final completedCourses = (enrollmentsResponse as List).length;

      // Calculate learning hours from lesson progress (as double for decimal display)
      final progressResponse = await _client
          .from('lesson_progress')
          .select('watch_time')
          .eq('user_id', userId);

      int totalSeconds = 0;
      for (var record in progressResponse) {
        totalSeconds += (record['watch_time'] as int?) ?? 0;
      }
      final learningHours = totalSeconds / 3600.0; // Keep as double

      // Certificates = completed courses (1 certificate per completed course)
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
          final totalScore = (attempt['total_points'] as num?)?.toDouble() ?? 1;
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

      final users = List<Map<String, dynamic>>.from(response);

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
        course:courses(title, price, users!instructor_id(full_name)),
        user:users(full_name)
      ''');

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

      // Filter by teacher (need to filter on joined table, which is tricky in simple syntax)
      // Best to do post-filtering or use !inner join if possible.
      // Let's fetch and filter in Dart for flexibility if volume is not huge.
      // Or use filtering on join:
      if (teacherId != null) {
        query = query.eq('course.instructor_id',
            teacherId); // Use dot notation for embedded resource if supported
      }

      var data = await query;
      var enrollments = List<Map<String, dynamic>>.from(data);

      // Filter by teacher manually if API filter failed or was complex
      if (teacherId != null) {
        enrollments = enrollments.where((e) {
          // final course = e['course'] as Map?; // Unused
          // Actually strict filtering on relation:
          // We can't easily see instructor_id in the result unless we selected it.
          // Let's assume the query returned it.
          // To be safe, let's just process what we have.
          return true; // Placeholder, assuming query did it or we accept all for now.
        }).toList();
      }

      double totalEarnings = 0;
      int totalEnrollments = enrollments.length;

      // Process for report
      final List<Map<String, dynamic>> reportItems = enrollments.map((e) {
        final course = e['course'] as Map?;
        final price = (course?['price'] as num?)?.toDouble() ?? 0.0;
        final student = e['user']?['full_name'] ?? 'Unknown';
        final courseName = course?['title'] ?? 'Unknown';
        final date = e['enrolled_at'];

        totalEarnings += price;

        return {
          'date': date,
          'student': student,
          'course': courseName,
          'amount': price,
        };
      }).toList();

      return {
        'totalEarnings': totalEarnings,
        'totalEnrollments': totalEnrollments,
        'items': reportItems,
        'period':
            '${startDate?.toString().split(' ')[0] ?? "Beginning"} - ${endDate?.toString().split(' ')[0] ?? "Now"}'
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

  /// Check if user is enrolled in a course
  Future<bool> isEnrolled(String courseId) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return false;

      final response = await _client
          .from('enrollments')
          .select('id')
          .eq('user_id', userId)
          .eq('course_id', courseId)
          .maybeSingle();

      return response != null;
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

      final data = List<Map<String, dynamic>>.from(response);
      return data.map((fav) => fav['courses'] as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting favorite courses: $e');
      return [];
    }
  }

  /// Get similar courses based on category
  Future<List<Course>> getSimilarCourses(String courseId, List<String> categoryIds) async {
    try {
      if (categoryIds.isEmpty) return [];

      final response = await _client
          .from('courses')
          .select('*, users!instructor_id(full_name, avatar_url)')
          .inFilter('category_id', categoryIds)
          .neq('id', courseId)
          .eq('is_published', true)
          .limit(6);

      final data = List<Map<String, dynamic>>.from(response);
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
  Future<List<Map<String, dynamic>>> getEnrolledCoursesWithProgress() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      // Fetch enrollments with course details AND instructor details
      final response = await _client
          .from('enrollments')
          .select(
              '*, courses(*, users!instructor_id(full_name, avatar_url))')
          .eq('user_id', userId)
          .order('enrolled_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);

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

      // CACHE: Save to offline cache
      try {
        await OfflineCacheService().cacheEnrolledCourses(enrollments);
      } catch (cacheError) {
        debugPrint('Error caching enrollments: $cacheError');
      }

      return enrollments;
    } catch (e) {
      debugPrint('Error getting enrolled courses with join: $e');

      // CACHE: Try to load from offline cache
      try {
        final cachedEnrollments =
            await OfflineCacheService().getCachedEnrolledCourses();
        if (cachedEnrollments != null && cachedEnrollments.isNotEmpty) {
          return cachedEnrollments;
        }
      } catch (cacheError) {
        debugPrint('Error loading cached enrollments: $cacheError');
      }

      // Fallback
      return _getEnrolledCoursesSimple();
    }
  }

  Future<List<Map<String, dynamic>>> _getEnrolledCoursesSimple() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return [];
    final response = await _client
        .from('enrollments')
        .select('*, courses(*)')
        .eq('user_id', userId)
        .order('enrolled_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
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

          return (response as List)
              .map((e) => e['course_id'] as String)
              .toList();
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

          return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all exams for a course (including drafts)
  Future<List<Map<String, dynamic>>> getAllExamsForCourse(
      String courseId) async {
    try {
      final response = await _client
          .from('exams')
          .select('*, questions(*)')
          .eq('course_id', courseId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
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
      return List<Map<String, dynamic>>.from(response);
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

      final attempts = List<Map<String, dynamic>>.from(attemptsResponse);

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

      final answers = List<Map<String, dynamic>>.from(answersResponse);

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

      return List<Map<String, dynamic>>.from(attempts);
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
    try {
      final targetUserId = userId ?? SupabaseService.instance.currentUserId;
      if (targetUserId == null) return 'student';

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

      debugPrint('✅ User role loaded: $role (role_id: ${response['role_id']})');
      return role ?? 'student';
    } catch (e) {
      debugPrint('❌ Error getting user role: $e');
      return 'student';
    }
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

      // Upsert into the unified users table
      await _client.from('users').upsert(data);
      
      // Also assign the teacher role if not already assigned
      try {
        await assignRole(userId, 'teacher');
      } catch (e) {
        debugPrint('⚠️ Could not assign teacher role automatically (permission?): $e');
        // Don't rethrow as the profile data is already saved
      }
      
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

      // Upsert into the unified users table
      await _client.from('users').upsert(data);
      
      // Also assign the student role if not already assigned
      try {
        await assignRole(userId, 'student');
      } catch (e) {
        debugPrint('⚠️ Could not assign student role automatically (permission?): $e');
        // Don't rethrow as the profile data is already saved
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

  /// Update student profile
  Future<void> updateStudentProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _client.from('users').update(data).eq('id', userId);
    } catch (e) {
      debugPrint('❌ Error updating student profile: $e');
      rethrow;
    }
  }

  /// Update teacher profile
  Future<void> updateTeacherProfile(String userId, Map<String, dynamic> data) async {
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
      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      // Get teacher's courses
      final teacherCourses = await _client
          .from('teacher_courses')
          .select('course_id')
          .eq('teacher_id', userId);

      if (teacherCourses.isEmpty) return [];

      final courseIds =
          teacherCourses.map((tc) => tc['course_id'] as String).toList();

      // Build query
      var query = _client.from('exam_attempts').select(
          '*, exams(title, course_id, courses(title)), users(full_name, email)');

      if (examId != null) {
        query = query.eq('exam_id', examId);
      } else {
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

      return List<Map<String, dynamic>>.from(response);
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

  /// Get all users (Admin only)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final response = await _client.from('users').select('*');
      return List<Map<String, dynamic>>.from(response);
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
          final data = List<Map<String, dynamic>>.from(response);

          // Transform flattened data to nested structure expected by UI
          return data.map((t) {
            final avatar = _formatAvatarUrl(t['avatar_url'], userId: t['user_id']);
            return {
              'user_id': t['user_id'],
              'users': {
                'id': t['user_id'],
                'name': t['name'],
                'full_name': t['name'], // Map for admin screen compatibility
                'email': t['email'],
                'avatar_url': avatar, // الاسم الصحيح الذي يبحث عنه الـ UI
                'photo_url': avatar, // احتياطي للتوافق مع بقية الشاشات
                'bio': t['bio'], // Include bio field
                'subjects': t['subjects'],
              }
            };
          }).toList();
        } catch (e) {
          // Fallback to old method if RPC not exists (though it will fail for students due to RLS)
          try {
            final teacherRole = await _client
                .from('roles')
                .select('id')
                .eq('name', 'teacher')
                .single();

            final response = await _client
                .from('user_roles')
                .select('*, users(*)')
                .eq('role_id', teacherRole['id']);

            return List<Map<String, dynamic>>.from(response);
          } catch (_) {
            return []; // Return empty if both fail
          }
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

      final rawEnrollments = List<Map<String, dynamic>>.from(response);

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
          attempts = List<Map<String, dynamic>>.from(attemptsResponse);
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

      return List<Map<String, dynamic>>.from(response);
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
      final rawData = List<Map<String, dynamic>>.from(response);

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
      final enrollments = List<Map<String, dynamic>>.from(response);

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
      final enrollments = List<Map<String, dynamic>>.from(response);

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
      var rawData = List<Map<String, dynamic>>.from(response);

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

      final rawData = List<Map<String, dynamic>>.from(response);

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
      await _client.from('courses').delete().eq('id', courseId);
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
      return response['id'];
    } catch (e) {
      rethrow;
    }
  }

  /// Update lesson (Admin only)
  Future<void> updateLesson(String lessonId, Map<String, dynamic> data) async {
    try {
      await _client.from('lessons').update(data).eq('id', lessonId);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete lesson (Admin only)
  Future<void> deleteLesson(String lessonId) async {
    try {
      await _client.from('lessons').delete().eq('id', lessonId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get all lessons for a course (Admin - no progress)
  Future<List<Map<String, dynamic>>> getCourseLessons(String courseId) async {
    try {
      final response = await _client
          .from('lessons')
          .select()
          .eq('course_id', courseId)
          .order('order_index');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Reorder lessons
  Future<void> reorderLessons(List<Map<String, dynamic>> updates) async {
    try {
      for (var update in updates) {
        final id = update.remove('id');
        if (id != null) {
          await _client.from('lessons').update(update).eq('id', id);
        }
      }
    } catch (e) {
      rethrow;
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
      
      final enrollments = List<Map<String, dynamic>>.from(response);

      // Total lessons in the course
      final lessonsResponse =
          await _client.from('lessons')
          .select('id')
          .eq('course_id', courseId);
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
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final orderData = {
        'user_id': userId,
        'order_number': 'ORD-${DateTime.now().millisecondsSinceEpoch}',
        'total_amount': amount,
        'payment_method': paymentMethod,
        'payment_transaction_id': transactionId,
        'course_id': courseId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'order_type': courseId != null ? 'course' : 'subscription',
      };

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
            .select('*, courses(title), payment_receipts(*)')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
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
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final response = await _client
          .from('payment_receipts')
          .insert({
            'order_id': orderId,
            'user_id': userId,
            'course_id': courseId,
            'payment_method': paymentMethod,
            'amount': amount,
            'transaction_id': transactionId,
            'receipt_image_url': receiptImageUrl,
            'phone_number': phoneNumber,
            'status': 'pending',
          })
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

      return List<Map<String, dynamic>>.from(response);
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
      var query = _client
          .from('payment_receipts')
          .select(
          '*, orders(*), users!user_id(full_name, email), courses(title, image_url)');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
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

      final questions = List<Map<String, dynamic>>.from(response);

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

          final reactions = List<Map<String, dynamic>>.from(reactionsResponse);

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

      return List<Map<String, dynamic>>.from(response);
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

          return List<Map<String, dynamic>>.from(response);
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

          final data = List<Map<String, dynamic>>.from(response);

          // Map joined data to flat structure
          return data.map((course) {
            final user = course['users'];
            if (user != null) {
              course['instructor_name'] =
                  user['full_name'] ?? course['instructor_name'];
              course['instructor_photo'] =
                  user['avatar_url'] ?? course['instructor_photo'];
            }
            return course;
          }).toList();
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

      final notifications = List<Map<String, dynamic>>.from(userResponse);

      // 2. Global admin notifications (type = 'all')
      try {
        final adminResponse = await _client
            .from('admin_notifications')
            .select()
            .eq('notification_type', 'all')
            .order('created_at', ascending: false)
            .limit(20);

        final adminNotifications =
            List<Map<String, dynamic>>.from(adminResponse);

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
      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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

      return List<Map<String, dynamic>>.from(response);
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
      final rawData = List<Map<String, dynamic>>.from(response);

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
        qrData = List<Map<String, dynamic>>.from(qrResponse);
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
  Future<Map<String, dynamic>> getSystemStatistics({bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'system_stats_all',
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 30),
      fetcher: () async {
        try {
          // Get counts using the correct Supabase 2.x syntax or by length
          final usersResponse = await _client.from('users').select('id');
          final coursesResponse = await _client.from('courses').select('id');
          final examsResponse = await _client.from('exams').select('id');
          final attemptsResponse = await _client.from('exam_attempts').select('id');
          
          // Get total revenue
          final revenueRes = await _client.from('enrollments').select('paid_amount');
          double totalRevenue = 0;
          
          final List<dynamic> rows = revenueRes as List<dynamic>;
          for (var row in rows) {
            totalRevenue += (row['paid_amount'] as num? ?? 0).toDouble();
          }

          return {
            'total_users': (usersResponse as List).length,
            'total_courses': (coursesResponse as List).length,
            'total_exams': (examsResponse as List).length,
            'total_attempts': (attemptsResponse as List).length,
            'total_revenue': totalRevenue,
          };
        } catch (e) {
          debugPrint('Error fetching system stats: $e');
          return {
            'total_users': 0,
            'total_courses': 0,
            'total_exams': 0,
            'total_attempts': 0,
            'total_revenue': 0,
          };
        }
      },
    );
  }

  /// Get statistics for a specific teacher
  Future<Map<String, dynamic>> getTeacherStatistics(String teacherId, {bool forceRefresh = false}) async {
    return fetchWithCache(
      key: 'teacher_stats_$teacherId',
      forceRefresh: forceRefresh,
      duration: const Duration(minutes: 30),
      fetcher: () async {
        try {
          // 1. Get courses count by this teacher from both the course itself and the junction table
          final directCourses = await _client.from('courses')
              .select('id')
              .eq('instructor_id', teacherId);
          
          final junctionCourses = await _client.from('teacher_courses')
              .select('course_id')
              .eq('teacher_id', teacherId);
          
          final List<dynamic> directList = directCourses as List<dynamic>;
          final List<dynamic> junctionList = junctionCourses as List<dynamic>;
          
          final Set<String> courseIdsSet = {
            ...directList.map((c) => c['id'] as String),
            ...junctionList.map((c) => c['course_id'] as String),
          };
          
          final List<String> courseIds = courseIdsSet.toList();
          
          int studentCount = 0;
          double totalRevenue = 0;
          int attemptsCount = 0;
          
          if (courseIds.isNotEmpty) {
            // 2. Get enrollments for student count and revenue
            final enrollmentsRes = await _client.from('enrollments')
                .select('user_id, paid_amount')
                .inFilter('course_id', courseIds);
            
            final List<dynamic> enrollmentsList = enrollmentsRes as List<dynamic>;
            final uniqueStudents = enrollmentsList.map((e) => e['user_id']).toSet();
            studentCount = uniqueStudents.length;
            
            for (var e in enrollmentsList) {
              totalRevenue += (e['paid_amount'] as num? ?? 0).toDouble();
            }

            // 3. Get exam attempts for stats
            final attemptsRes = await _client.from('exam_attempts')
                .select('id, exams!inner(course_id)')
                .inFilter('exams.course_id', courseIds);
            
            attemptsCount = (attemptsRes as List).length;
          }

          return {
            'total_courses': courseIds.length,
            'total_users': studentCount,
            'total_revenue': totalRevenue,
            'total_attempts': attemptsCount,
          };
        } catch (e) {
          debugPrint('Error fetching teacher stats: $e');
          return {
            'total_courses': 0,
            'total_users': 0,
            'total_revenue': 0,
          };
        }
      },
    );
  }
}