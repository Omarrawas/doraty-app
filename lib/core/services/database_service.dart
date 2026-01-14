import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'supabase_service.dart';
import '../../models/course.dart';
import '../../models/chapter.dart';
import 'offline_cache_service.dart';

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

  // ==================== SEARCH ====================

  /// Search courses with filters
  Future<List<Map<String, dynamic>>> searchCourses({
    String? query,
    String? category,
    String? subject,
    double? minPrice,
    double? maxPrice,
    double? minRating,
  }) async {
    try {
      // Build query
      var dbQuery = _client.from('courses').select('*, users!instructor_id(full_name, avatar_url)');

      // Text Search
      if (query != null && query.isNotEmpty) {
        // Search in title and description using ilike (case-insensitive)
        dbQuery = dbQuery.or('title.ilike.%$query%,description.ilike.%$query%');
      }

      // Category Filter
      if (category != null && category != 'الكل') {
        dbQuery = dbQuery.eq('category', category);
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

  /// Get teacher courses (Alias for compatibility)
  Future<List<Map<String, dynamic>>> getTeacherCourses() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      return await getCoursesByTeacherId(userId);
    } catch (e) {
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
    String? subject,
    bool includeDrafts = false,
    bool forceRefresh = false,
  }) async {
    try {
      // Join with users to get correct instructor details
      var query = _client
          .from('courses')
          .select('*, users!instructor_id(full_name, avatar_url)');

      if (category != null) {
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
        return course;
      }).toList();

      // CACHE: Save to offline cache
      try {
        final coursesList = coursesMapList
            .map((c) => Course(
                  id: c['id'],
                  title: c['title'] ?? '',
                  description: c['description'] ?? '',
                  instructorId: c['instructor_id'],
                  instructorName: c['instructor_name'] ?? '',
                  instructorPhoto: c['instructor_photo'] ?? '',
                  imageUrl: c['image_url'] ?? c['thumbnail'] ?? '',
                  price: (c['price'] as num?)?.toDouble() ?? 0,
                  rating: (c['rating'] as num?)?.toDouble() ?? 0,
                  studentsCount: c['students_count'] ?? 0,
                  lessonsCount: c['lessons_count'] ?? 0,
                  durationHours:
                      c['duration_hours']?.toString() ?? c['duration'],
                  category: c['category'] ?? '',
                  subject: c['subject'] ?? '',
                  curriculum: [],
                  isEnrolled: false,
                ))
            .toList();
        await OfflineCacheService().cacheCourses(coursesList);
      } catch (cacheError) {
        debugPrint('Error caching courses: $cacheError');
      }

      return coursesMapList;
    } catch (e) {
      debugPrint('Error getting courses with join: $e');

      // CACHE: Try to load from offline cache (only if not forcing refresh and not asking for drafts)
      if (!forceRefresh && !includeDrafts) {
        try {
          final cachedCourses = await OfflineCacheService().getCachedCourses();
        if (cachedCourses != null && cachedCourses.isNotEmpty) {
          // Convert back to Map<String, dynamic>
          // Filter manually if needed (category/subject)
          var filtered = cachedCourses;
          if (category != null) {
            filtered = filtered.where((c) => c.category == category).toList();
          }
          if (subject != null) {
            filtered = filtered.where((c) => c.subject == subject).toList();
          }

          return filtered.map((c) {
            return {
              'id': c.id,
              'title': c.title,
              'description': c.description,
              'instructor_id': c.instructorId,
              'instructor_name': c.instructorName,
              'instructor_photo': c.instructorPhoto,
              'image_url': c.imageUrl,
              'price': c.price,
              'rating': c.rating,
              'students_count': c.studentsCount,
              'lessons_count': c.lessonsCount,
              'duration_hours': c.durationHours,
              'category': c.category,
              'subject': c.subject,
            };
          }).toList();
        }
      } catch (cacheError) {
        debugPrint('Error loading cached courses: $cacheError');
      }
      }

      // Fallback to simple select if join fails AND cache fails
      return _getCoursesSimple(
          category: category, subject: subject, includeDrafts: includeDrafts);
    }
  }

  Future<List<Map<String, dynamic>>> _getCoursesSimple({
    String? category,
    String? subject,
    bool includeDrafts = false,
  }) async {
    var query = _client.from('courses').select();
    if (category != null) query = query.eq('category', category);
    if (subject != null) query = query.eq('subject', subject);
    if (!includeDrafts) {
      query = query.eq('is_published', true);
    }
    final response = await query;
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get course by ID
  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      final response = await _client
          .from('courses')
          .select('*, users!instructor_id(full_name, avatar_url)')
          .eq('id', courseId)
          .maybeSingle();

      if (response == null) return null;

      final course = Map<String, dynamic>.from(response);
      final user = course['users'];
      if (user != null) {
        course['instructor_name'] =
            user['full_name'] ?? course['instructor_name'];
        course['instructor_photo'] =
            user['avatar_url'] ?? course['instructor_photo'];
      }
      return course;
    } catch (e) {
      debugPrint('Error getting course by id with join: $e');
      try {
        return await _client
            .from('courses')
            .select()
            .eq('id', courseId)
            .single();
      } catch (_) {
        return null;
      }
    }
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

      // If user is authenticated, get progress for each lesson
      if (userId != null) {
        for (var lesson in lessons) {
          final progress = await _getLessonProgress(lesson['id']);
          if (progress != null) {
            lesson['is_completed'] = progress['is_completed'];
            lesson['watch_time'] = progress['watch_time'];
            lesson['last_position'] = progress['last_position'];
          }
        }
      }

      return lessons;
    } catch (e) {
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

  // ==================== FORUMS ====================

  /// Get all forums
  Future<List<Map<String, dynamic>>> getForums() async {
    try {
      final response = await _client.from('forums').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get forum posts
  Future<List<Map<String, dynamic>>> getForumPosts(String forumId) async {
    try {
      final response = await _client
          .from('forum_posts')
          .select('*, users(full_name, avatar_url)')
          .eq('forum_id', forumId)
          .order('created_at', ascending: false);

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

  // ==================== FORUM POSTS ====================

  /// Create a forum post
  Future<void> createForumPost({
    required String title,
    required String content,
    required String courseId,
    List<String>? tags,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('forum_posts').insert({
        'user_id': userId,
        'title': title,
        'content': content,
        'course_id': courseId,
        'tags': tags,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get comments for a forum post
  Future<List<Map<String, dynamic>>> getForumComments(String postId) async {
    try {
      final response = await _client
          .from('forum_comments')
          .select('*, users(full_name, avatar_url)')
          .eq('post_id', postId)
          .order('created_at');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Add a comment to a forum post
  Future<void> addForumComment({
    required String postId,
    required String content,
  }) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      await _client.from('forum_comments').insert({
        'user_id': userId,
        'post_id': postId,
        'content': content,
      });
    } catch (e) {
      rethrow;
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
          .select('id, progress')
          .eq('user_id', userId)
          .gte('progress', 100);

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
          .eq('user_id', userId);

      double averageScore = 0.0;
      if (examAttemptsResponse.isNotEmpty) {
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
          .select('*, courses(*, users!instructor_id(full_name, avatar_url))')
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

      final response = await _client
          .from('enrollments')
          .select('course_id')
          .eq('user_id', userId);

      return response.map((e) => e['course_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Get user's enrolled courses (without progress)
  Future<List<Map<String, dynamic>>> getEnrolledCourses() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return [];

      final response = await _client
          .from('enrollments')
          .select('*, courses(*)')
          .eq('user_id', userId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
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
  Future<String> getUserRole() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return 'student';

      // Join user_roles with roles table to get role name
      final response = await _client
          .from('user_roles')
          .select('role_id, roles(name)')
          .eq('user_id', userId)
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

  /// Check if user is teacher
  Future<bool> isTeacher() async {
    final role = await getUserRole();
    return role == 'teacher' || role == 'admin' || role == 'super_admin';
  }

  /// Check if user is admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin' || role == 'super_admin';
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

  /// Get user by ID
  Future<Map<String, dynamic>?> getUserById(String userId) async {
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
  }

  /// Get all teachers
  Future<List<Map<String, dynamic>>> getAllTeachers() async {
    try {
      // Use RPC to bypass RLS and get teachers list cleanly
      final response = await _client.rpc('get_all_teachers_public');
      final data = List<Map<String, dynamic>>.from(response);

      // Transform flattened data to nested structure expected by UI
      return data.map((t) {
        return {
          'user_id': t['user_id'],
          'users': {
            'id': t['user_id'],
            'name': t['name'],
            'full_name': t['name'], // Map for admin screen compatibility
            'email': t['email'],
            'photo_url': t['avatar_url'], // Map avatar_url to photo_url for UI
            'branch': t['branch'],
            'bio': t['bio'], // Include bio field
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
  }

  /// Get system statistics (Admin only)
  Future<Map<String, dynamic>> getSystemStatistics() async {
    try {
      final totalUsers = await _client.from('users').select('id');
      final totalCourses = await _client.from('courses').select('id');
      final totalExams = await _client.from('exams').select('id');
      final totalAttempts = await _client.from('exam_attempts').select('id');

      return {
        'total_users': totalUsers.length,
        'total_courses': totalCourses.length,
        'total_exams': totalExams.length,
        'total_attempts': totalAttempts.length,
      };
    } catch (e) {
      return {
        'total_users': 0,
        'total_courses': 0,
        'total_exams': 0,
        'total_attempts': 0,
      };
    }
  }

  // ==================== ADMIN: SUBSCRIPTIONS MANAGEMENT ====================

  /// Get all enrollments (Admin only)
  Future<List<Map<String, dynamic>>> getAllEnrollments({
    String? status,
    String? searchQuery,
  }) async {
    try {
      // Use the administrative view for reliable flattened data
      var query = _client.from('admin_enrollments_view').select();

      if (status != null && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('enrolled_at', ascending: false);
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
  Future<List<Map<String, dynamic>>> getEnrollmentsGroupedByCourse() async {
    try {
      final enrollments = await getAllEnrollments();
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
          };
        }

        grouped[courseId]!['enrollment_count']++;
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
  Future<List<Map<String, dynamic>>> getEnrollmentsGroupedByTeacher() async {
    try {
      // Use the view to get instructor data reliably
      final response = await _client.from('admin_enrollments_view').select();
      final rawData = List<Map<String, dynamic>>.from(response);

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
          };
        }

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

      // Ensure we don't send extra fields if not in schema (though Supabase usually ignores extra properties, better safe)
      // Keeping instructor_id in data if the courses table has it as a column (which likely does based on getCoursesByTeacherId)

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
      // Total enrollments
      final enrollments = await _client
          .from('enrollments')
          .select('id')
          .eq('course_id', courseId);

      // Completed enrollments
      final completed = await _client
          .from('enrollments')
          .select('id')
          .eq('course_id', courseId)
          .eq('status', 'completed');

      // Total lessons
      final lessons =
          await _client.from('lessons').select('id').eq('course_id', courseId);

      // Average progress
      final progressData = await _client
          .from('lesson_progress')
          .select('progress')
          .eq('course_id', courseId);

      double avgProgress = 0;
      if (progressData.isNotEmpty) {
        final total = progressData.fold<double>(
          0,
          (sum, item) => sum + (item['progress'] as num? ?? 0),
        );
        avgProgress = total / progressData.length;
      }

      return {
        'total_enrollments': enrollments.length,
        'completed_enrollments': completed.length,
        'total_lessons': lessons.length,
        'average_progress': avgProgress.round(),
        'completion_rate': enrollments.isEmpty
            ? 0
            : ((completed.length / enrollments.length) * 100).round(),
      };
    } catch (e) {
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
    required String planId,
    required double amount,
    required String paymentMethod,
    String? transactionId,
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final orderData = {
        'user_id': userId,
        'plan_id': planId,
        'amount': amount,
        'payment_method': paymentMethod,
        'transaction_id': transactionId,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
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
            .select()
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

  /// Get active payment accounts
  Future<List<Map<String, dynamic>>> getPaymentAccounts() async {
    try {
      final response = await _client
          .from('payment_accounts')
          .select()
          .eq('is_active', true)
          .order('display_order');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting payment accounts: $e');
      return [];
    }
  }

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
  }) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      final response = await _client
          .from('payment_receipts')
          .insert({
            'order_id': orderId,
            'user_id': userId,
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

  /// Get all payment receipts (Admin only)
  Future<List<Map<String, dynamic>>> getAllPaymentReceipts({
    String? status,
  }) async {
    try {
      var query = _client
          .from('payment_receipts')
          .select('*, orders(*), users!user_id(full_name, email)');

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
          .select('*, orders(*), users!user_id(full_name, email, phone)')
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
      // Get receipt details
      final receipt = await getPaymentReceiptById(receiptId);
      if (receipt == null) throw Exception('Receipt not found');

      // Call database function to approve
      await _client.rpc('approve_payment_receipt', params: {
        'receipt_id_param': receiptId,
        'admin_notes_param': adminNotes,
      });

      // Get order details to activate subscription
      final order = receipt['orders'] as Map<String, dynamic>;
      if (order['order_type'] == 'subscription') {
        // Extract plan details from order
        final planId = order['plan_id'] as String?;
        final userId = order['user_id'] as String;

        if (planId != null) {
          // You'll need to get plan duration - for now assuming it's in order or you query it
          // This is a simplified version - adjust based on your schema
          await activateSubscription(
            userId: userId,
            planId: planId,
            durationMonths: 1, // Get this from the plan or order
          );
        }
      }

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

  /// Update payment account (Admin only)
  Future<void> updatePaymentAccount({
    required String paymentMethod,
    required String accountName,
    required String accountNumber,
    String? instructions,
  }) async {
    try {
      await _client.from('payment_accounts').upsert({
        'payment_method': paymentMethod,
        'account_name': accountName,
        'account_number': accountNumber,
        'instructions': instructions,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'payment_method');

      debugPrint('Payment account updated: $paymentMethod');
    } catch (e) {
      debugPrint('Error updating payment account: $e');
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
      final response = await _client
          .from('lesson_questions')
          .select(
              '*, users!user_id(full_name, avatar_url), question_replies(*)')
          .eq('lesson_id', lessonId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
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
}

