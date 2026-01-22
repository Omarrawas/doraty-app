import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:flutter/foundation.dart';
import '../../models/offline_course.dart';
import '../../models/offline_lesson.dart';

class OfflineStorageService {
  static final OfflineStorageService _instance = OfflineStorageService._internal();
  factory OfflineStorageService() => _instance;
  OfflineStorageService._internal();

  // Box names
  static const String coursesBoxName = 'offline_courses';
  static const String lessonsBoxName = 'offline_lessons';
  static const String syncStatusBoxName = 'sync_status';
  static const String resourcesBoxName = 'offline_resources';

  Box<OfflineCourse>? _coursesBox;
  Box<OfflineLesson>? _lessonsBox;
  Box<Uint8List>? _resourcesBox;
  Box? _syncStatusBox;
  bool _isInitialized = false;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (!kIsWeb) {
        await Hive.initFlutter();
      }
      
      // Register Adapters
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(OfflineCourseAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(OfflineLessonAdapter());
      }

      // Open Boxes
      _coursesBox = await Hive.openBox<OfflineCourse>(coursesBoxName);
      _lessonsBox = await Hive.openBox<OfflineLesson>(lessonsBoxName);
      _resourcesBox = await Hive.openBox<Uint8List>(resourcesBoxName);
      _syncStatusBox = await Hive.openBox(syncStatusBoxName);
      
      _isInitialized = true;
      debugPrint('📦 OfflineStorageService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing OfflineStorageService: $e');
    }
  }

  // --- Course Operations ---

  Future<void> saveCourse(OfflineCourse course) async {
    await _ensureInitialized();
    await _coursesBox!.put(course.id, course);
    debugPrint('💾 Saved course offline: ${course.title}');
  }

  Future<OfflineCourse?> getCourse(String id) async {
    await _ensureInitialized();
    return _coursesBox!.get(id);
  }

  Future<List<OfflineCourse>> getAllCourses() async {
    await _ensureInitialized();
    return _coursesBox!.values.toList();
  }

  Future<void> deleteCourse(String id) async {
    await _ensureInitialized();
    
    // 1. Get course to find related lessons
    final course = _coursesBox!.get(id);
    if (course == null) return;

    // 2. Delete all related lessons
    for (final lessonId in course.lessonIds) {
      await _deleteLesson(lessonId);
    }

    // 3. Delete course cover image if exists
    if (course.thumbnailPath != null) {
      final file = File(course.thumbnailPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 4. Delete course from box
    await _coursesBox!.delete(id);
    debugPrint('🗑️ Deleted course offline: ${course.title}');
  }

  // --- Lesson Operations ---

  Future<void> saveLesson(OfflineLesson lesson) async {
    await _ensureInitialized();
    await _lessonsBox!.put(lesson.id, lesson);
  }

  Future<OfflineLesson?> getLesson(String id) async {
    await _ensureInitialized();
    return _lessonsBox!.get(id);
  }

  Future<List<OfflineLesson>> getCourseLessons(String courseId) async {
    await _ensureInitialized();
    return _lessonsBox!.values.where((l) => l.courseId == courseId).toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
  }

  // --- Resource (Encrypted Attachments) Operations ---

  Future<void> saveResource(
      String lessonId, String fileName, Uint8List encryptedData) async {
    await _ensureInitialized();
    final key = '${lessonId}_$fileName';
    await _resourcesBox!.put(key, encryptedData);
  }

  Future<Uint8List?> getResource(String lessonId, String fileName) async {
    await _ensureInitialized();
    final key = '${lessonId}_$fileName';
    return _resourcesBox!.get(key);
  }

  Future<void> deleteResource(String lessonId, String fileName) async {
    await _ensureInitialized();
    final key = '${lessonId}_$fileName';
    await _resourcesBox!.delete(key);
  }

  Future<void> _deleteLesson(String id) async {
    final lesson = _lessonsBox!.get(id);
    if (lesson == null) return;

    // Delete video file if exists (Native only)
    if (!kIsWeb && lesson.videoPath != null) {
      final file = File(lesson.videoPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Delete all resources for this lesson from Hive (All platforms)
    if (lesson.downloadedResources != null) {
      for (final fileName in lesson.downloadedResources!.keys) {
        await deleteResource(id, fileName);
      }
    }

    await _lessonsBox!.delete(id);
  }

  // --- Storage Management ---

  Future<int> getTotalSize() async {
    await _ensureInitialized();
    int size = 0;
    for (var course in _coursesBox!.values) {
      size += course.totalSize;
    }
    // Add resources sizes
    for (var bytes in _resourcesBox!.values) {
      size += bytes.length;
    }
    return size;
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    
    final courses = await getAllCourses();
    for (var c in courses) {
      await deleteCourse(c.id);
    }
    await _coursesBox!.clear();
    await _lessonsBox!.clear();
    await _resourcesBox!.clear();
    await _syncStatusBox!.clear();
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await init();
    }
  }
}
