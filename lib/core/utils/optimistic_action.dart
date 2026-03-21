import 'package:flutter/foundation.dart';
import '../services/sync_queue.dart';
import '../services/sync_service.dart';
import 'package:uuid/uuid.dart';

/// Utility class for Optimistic UI actions.
///
/// Usage:
/// ```dart
/// await OptimisticAction.run(
///   optimistic: () => setState(() => liked = true),
///   remote: () => db.toggleLike(tipId),
///   rollback: () => setState(() => liked = false),
///   queue: SyncTask(type: SyncActionType.toggleLike, ...),
/// );
/// ```
class OptimisticAction {
  static const _uuid = Uuid();

  /// Runs an optimistic UI update and fires the remote call in background.
  /// If remote fails and device is offline, queues the task for later.
  /// If remote fails online, rolls back the UI state.
  static Future<void> run({
    required VoidCallback optimistic,
    required Future<void> Function() remote,
    required VoidCallback rollback,
    SyncTask? offlineQueue,
  }) async {
    // 1. Instant UI update
    optimistic();

    // 2. Try remote
    try {
      await remote();
    } catch (e) {
      debugPrint('⚡ [OptimisticAction] Remote failed: $e');

      // 3. If offline and task is queueable, save for later
      if (SyncService().isOffline && offlineQueue != null) {
        debugPrint('📝 [OptimisticAction] Offline — queuing task...');
        await SyncQueue().addTask(offlineQueue);
        // Keep the optimistic state (it will sync when online)
      } else {
        // Online but failed-rollback
        debugPrint('🔙 [OptimisticAction] Rolling back UI state');
        rollback();
      }
    }
  }

  /// Helper to build a SyncTask with a unique ID
  static SyncTask buildTask({
    required SyncActionType type,
    required String entity,
    required String entityId,
    Map<String, dynamic>? data,
  }) {
    return SyncTask(
      id: _uuid.v4(),
      type: type,
      entity: entity,
      entityId: entityId,
      data: data ?? {},
    );
  }
}
