import 'package:flutter/foundation.dart';
import 'local_database.dart';

enum SyncActionType { create, update, delete, toggleLike, enroll }

class SyncTask {
  final String id;
  final SyncActionType type;
  final String entity; // e.g., 'tips', 'courses'
  final String entityId;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  int retries;

  SyncTask({
    required this.id,
    required this.type,
    required this.entity,
    required this.entityId,
    required this.data,
    DateTime? timestamp,
    this.retries = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.index,
    'entity': entity,
    'entityId': entityId,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
    'retries': retries,
  };

  factory SyncTask.fromJson(Map<String, dynamic> json) => SyncTask(
    id: json['id'],
    type: SyncActionType.values[json['type']],
    entity: json['entity'],
    entityId: json['entityId'],
    data: json['data'] ?? {},
    timestamp: DateTime.parse(json['timestamp']),
    retries: json['retries'] ?? 0,
  );
}

class SyncQueue {
  static final SyncQueue _instance = SyncQueue._internal();
  factory SyncQueue() => _instance;
  SyncQueue._internal();

  static const String _boxName = 'sync_queue';
  final LocalDatabase _localDb = LocalDatabase();

  /// Add a task to the queue
  Future<void> addTask(SyncTask task) async {
    final tasks = await getTasks();
    tasks.add(task);
    await _saveTasks(tasks);
    debugPrint('📝 [SyncQueue] Added task: ${task.type} on ${task.entity}:${task.entityId}');
  }

  /// Get all pending tasks
  Future<List<SyncTask>> getTasks() async {
    final raw = _localDb.get<List<dynamic>>('pending_tasks', boxName: _boxName);
    if (raw == null) return [];
    return raw.map((e) => SyncTask.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Remove a task by ID
  Future<void> removeTask(String id) async {
    final tasks = await getTasks();
    tasks.removeWhere((t) => t.id == id);
    await _saveTasks(tasks);
  }

  /// Update a task (e.g. increment retries)
  Future<void> updateTask(SyncTask task) async {
    final tasks = await getTasks();
    final index = tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      await _saveTasks(tasks);
    }
  }

  Future<void> _saveTasks(List<SyncTask> tasks) async {
    final data = tasks.map((t) => t.toJson()).toList();
    await _localDb.set('pending_tasks', data, boxName: _boxName);
  }

  Future<void> clear() async {
    await _localDb.clear(boxName: _boxName);
  }
}
