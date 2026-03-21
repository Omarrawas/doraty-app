import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _db = DatabaseService();
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Sync all data if conditions are met
  Future<void> syncAll({bool forced = false}) async {
    if (_isSyncing) return;

    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    if (connectivityResults.contains(ConnectivityResult.none)) {
      debugPrint('📴 No internet connection, skipping sync');
      return;
    }

    _isSyncing = true;
    notifyListeners();
    debugPrint('🔄 Starting comprehensive sync...');

    try {
      // Sync Core Data (Home, Profile, Categories)
      await syncCoreData();
      
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

      // Subscribe to course topics for push notifications
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
      await AuthService().loadUserProfile();

      debugPrint('✨ Core data synced successfully');
    } catch (e) {
      debugPrint('⚠️ Core sync warning: $e');
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

