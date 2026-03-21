import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/offline_storage_service.dart';
import '../services/course_download_service.dart';
import '../../models/offline_course.dart';
import 'settings_service.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final OfflineStorageService _storage = OfflineStorageService();
  final DatabaseService _db = DatabaseService();
  final CourseDownloadService _downloader = CourseDownloadService();
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Sync all downloaded courses if conditions are met
  Future<void> syncAll({bool forced = false}) async {
    if (_isSyncing) return;

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      debugPrint('📴 No internet connection, skipping sync');
      return;
    }

    // Check WiFi Setting
    final wifiOnly = SettingsService().getWifiOnly();
    if (wifiOnly &&
        !forced &&
        !connectivityResults.contains(ConnectivityResult.wifi)) {
      debugPrint('📶 Not on WiFi (and restricted), skipping background sync');
      return;
    }

    _isSyncing = true;
    notifyListeners();
    debugPrint('🔄 Starting comprehensive sync...');

    try {
      // 1. Sync Core Data (Home, Profile, Categories)
      await syncCoreData();

      // 2. Sync Offline Downloaded Courses
      final offlineCourses = await _storage.getAllCourses();
      for (final course in offlineCourses) {
        await _syncCourse(course);
      }
      
      debugPrint('✅ All data sync completed');
    } catch (e) {
      debugPrint('❌ Error during sync: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Syncs essential data needed for the app to feel "alive" offline
  Future<void> syncCoreData() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) return;

      debugPrint('📡 Syncing core database items...');

      // Sync Categories
      await _db.getCategories(forceRefresh: true);

      // Sync Enrolled Courses (The "My Courses" tab)
      final enrollments = await _db.getEnrolledCoursesWithProgress(forceRefresh: true);

      // 3. Subscribe to course topics for push notifications
      for (final enrollment in enrollments) {
        final courseData = enrollment['courses'] as Map<String, dynamic>?;
        final courseId = courseData?['id'] ?? enrollment['course_id'];
        if (courseId != null) {
          await NotificationService().subscribeToTopic('course_$courseId');
        }
      }

      // Sync Home Content (Featured/Latest)
      await _db.getCourses(forceRefresh: true); // Get initial courses

      // Sync User Profile
      // This is already handled in AuthService, but we ensure it here
      await AuthService().loadUserProfile();

      debugPrint('✨ Core data synced successfully');
    } catch (e) {
      debugPrint('⚠️ Core sync warning: $e');
    }
  }

  Future<void> _syncCourse(OfflineCourse localCourse) async {
    try {
      // Check for updates
      // Ideally we check an 'updated_at' timestamp from the server
      final remoteCourse = await _db.getCourseById(localCourse.id);
      
      if (remoteCourse == null) {
        // Course deleted on server?
        // Logic to handle this (maybe keep local copy or delete)
        return;
      }

      final remoteUpdatedAt = DateTime.parse(remoteCourse['updated_at'] ??
          remoteCourse['created_at']); // Assuming field exists
      
      if (remoteUpdatedAt.isAfter(localCourse.lastSyncAt)) {
        debugPrint('📥 Update found for course: ${localCourse.title}');
        // Trigger download to update
        // For now, we just re-download. In a real smart sync, we'd diff lessons.
        _downloader.downloadCourse(localCourse.id); 
      }
    } catch (e) {
      debugPrint('Error syncing course ${localCourse.id}: $e');
    }
  }

  /// Initialize sync trigger (e.g. on app start)
  void init({bool skipInitialSync = false}) {
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.wifi)) {
        syncAll();
      }
    });

    // Run initial check if not skipped
    if (!skipInitialSync) {
      syncAll();
    }
  }
}
