import 'package:hive/hive.dart';

part 'offline_lesson.g.dart';

@HiveType(typeId: 3)
class OfflineLesson extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String courseId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String? videoPath; // Local path to video (optional)

  @HiveField(4)
  final String? content; // HTML content or description

  @HiveField(5)
  final bool isDownloaded;
  
  @HiveField(6)
  final int duration; // in seconds/minutes depending on usage, storing as int

  @HiveField(7)
  final int orderIndex;

  OfflineLesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.videoPath,
    this.content,
    required this.isDownloaded,
    this.duration = 0,
    required this.orderIndex,
  });
}
