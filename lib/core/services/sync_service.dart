import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'supabase_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'sync_queue.dart';
import 'local_database.dart';

class SyncService extends ChangeNotifier {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseService _db = DatabaseService();
  final SyncQueue _queue = SyncQueue();
  final Connectivity _connectivity = Connectivity();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  int _retryCount = 0;
  static const int maxRetries = 5;
  Timer? _retryTimer;

  StreamSubscription? _connectivitySubscription;

  /// Initialize sync trigger
  void init({bool skipInitialSync = false}) {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _updateOfflineStatus(results);
      if (!_isOffline) {
        // We are back online, reset backoff and sync
        _resetBackoff();
        syncAll();
      }
    });

    // Check initial status
    _connectivity.checkConnectivity().then(_updateOfflineStatus);

    // Run initial check if not skipped
    if (!skipInitialSync) {
      syncAll();
    }
  }

  void _updateOfflineStatus(List<ConnectivityResult> results) {
    final wasOffline = _isOffline;
    _isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
    
    if (wasOffline != _isOffline) {
      debugPrint(_isOffline ? '🌐 [Sync] App is now OFFLINE' : '🌐 [Sync] App is back ONLINE');
      notifyListeners();
    }
  }

  /// Sync all data if conditions are met
  Future<void> syncAll({bool forced = false}) async {
    if (_isSyncing) return;
    
    // Check connectivity again to be sure
    final results = await _connectivity.checkConnectivity();
    _updateOfflineStatus(results);

    if (_isOffline && !forced) {
      debugPrint('📴 [Sync] Skipping sync: Device is offline');
      return;
    }

    _isSyncing = true;
    notifyListeners();
    debugPrint('🔄 [Sync] Starting background synchronization...');

    try {
      // 1. First, process any pending local operations (if implemented)
      await _processPendingOperations();

      // 2. Sync Core Data (Home, Profile, Categories, Tips)
      await syncCoreData();
      
      // 3. Reset backoff on success
      _resetBackoff();
      
      debugPrint('✅ [Sync] Background synchronization completed successfully');
    } catch (e) {
      debugPrint('❌ [Sync] Synchronization failed: $e');
      _scheduleRetry();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void _resetBackoff() {
    _retryCount = 0;
    _retryTimer?.cancel();
  }

  void _scheduleRetry() {
    if (_isOffline || _retryCount >= maxRetries) return;

    _retryCount++;
    // Exponential backoff: 5s, 10s, 20s, 40s, 80s
    final delaySeconds = (math.pow(2, _retryCount) * 2.5).toInt();
    
    debugPrint('🕒 [Sync] Scheduling retry #$_retryCount in ${delaySeconds}s');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      syncAll();
    });
  }

  /// Process pending local operations from SyncQueue
  Future<void> _processPendingOperations() async {
    final tasks = await _queue.getTasks();
    if (tasks.isEmpty) return;

    debugPrint('🔄 [Sync] Processing ${tasks.length} pending operations...');

    for (var task in tasks) {
      bool success = false;
      try {
        switch (task.type) {
          case SyncActionType.toggleLike:
            // Example: rpc for atomic like toggle
            await SupabaseService.instance.client.rpc('toggle_like', params: {
              'item_id': task.entityId,
              'user_id': SupabaseService.instance.currentUserId,
            });
            success = true;
            break;
            
          case SyncActionType.enroll:
            await SupabaseService.instance.client.from('enrollments').upsert({
              'course_id': task.entityId,
              'user_id': SupabaseService.instance.currentUserId,
            });
            success = true;
            break;

          case SyncActionType.update:
            await SupabaseService.instance.client
                .from(task.entity)
                .update(task.data)
                .eq('id', task.entityId);
            success = true;
            break;

          default:
            debugPrint('⚠️ [Sync] No handler for type ${task.type}');
            success = true;
        }

        if (success) {
          await _queue.removeTask(task.id);
        }
      } catch (e) {
        debugPrint('❌ [Sync] Task failed (${task.id}): $e');
        task.retries++;
        if (task.retries >= 3) {
          // Permanently remove failed tasks to avoid blocking the queue
          await _queue.removeTask(task.id);
        } else {
          await _queue.updateTask(task);
        }
      }
    }
  }

  /// Syncs essential data needed for the app to feel "alive" offline
  Future<void> syncCoreData() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      
      // 1. Sync Categories (Low frequency, vital for UI)
      await _db.getCategories(forceRefresh: true);

      // 2. Sync Tips (High priority for social-like feed)
      await _db.getTips(forceRefresh: true);

      if (userId != null) {
        // 3. Sync User Profile (Includes points, streak, etc.)
        await AuthService().loadUserProfile();
        
        // 4. Sync Enrolled Courses (Critical for "My Learning")
        final enrollments = await _db.getEnrolledCoursesWithProgress(forceRefresh: true);

        // 5. Update Notification Subscriptions
        for (final enrollment in enrollments) {
          try {
            final courseData = enrollment['courses'] as Map<String, dynamic>?;
            final courseId = courseData?['id'] ?? enrollment['course_id'];
            if (courseId != null) {
              await NotificationService().subscribeToTopic('course_$courseId');
            }
          } catch (e) {
            // Non-critical, continue
          }
        }
      }

      // 6. Sync Latest Courses (For home featured section)
      await _db.getCourses(forceRefresh: true);

      // Update last sync success metadata in Hive
      final now = DateTime.now().millisecondsSinceEpoch;
      await LocalDatabase().set('last_full_sync_timestamp', now);
      
    } catch (e) {
      debugPrint('⚠️ [Sync] Core sync failed: $e');
      rethrow; // Catch in syncAll for retry
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
