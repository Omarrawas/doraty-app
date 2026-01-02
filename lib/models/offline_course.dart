import 'package:hive/hive.dart';

part 'offline_course.g.dart';

@HiveType(typeId: 2)
class OfflineCourse extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? thumbnailPath; // Local path to thumbnail image

  @HiveField(4)
  final List<String> lessonIds;

  @HiveField(5)
  final DateTime downloadedAt;

  @HiveField(6)
  final DateTime lastSyncAt;

  @HiveField(7)
  final int totalSize; // In bytes

  OfflineCourse({
    required this.id,
    required this.title,
    this.description,
    this.thumbnailPath,
    required this.lessonIds,
    required this.downloadedAt,
    required this.lastSyncAt,
    required this.totalSize,
  });
}
