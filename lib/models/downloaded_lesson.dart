import 'package:hive/hive.dart';

part 'downloaded_lesson.g.dart';

@HiveType(typeId: 0)
enum DownloadStatus {
  @HiveField(0)
  notDownloaded,
  @HiveField(1)
  downloading,
  @HiveField(2)
  downloaded,
  @HiveField(3)
  failed,
  @HiveField(4)
  paused,
  @HiveField(5)
  cancelled,
}

@HiveType(typeId: 1)
class DownloadedLesson {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String lessonId;
  @HiveField(2)
  final String courseId;
  @HiveField(3)
  final String title;
  @HiveField(4)
  final String videoUrl; // Source URL
  @HiveField(5)
  final String localPath; // Encrypted local file path
  @HiveField(6)
  final String? thumbnailPath;
  @HiveField(7)
  final int fileSize;
  @HiveField(8)
  final DateTime downloadedAt;
  @HiveField(9)
  final DownloadStatus status;
  @HiveField(10)
  final double progress;
  @HiveField(11)
  final String? errorMessage;

  DownloadedLesson({
    required this.id,
    required this.lessonId,
    required this.courseId,
    required this.title,
    required this.videoUrl,
    required this.localPath,
    this.thumbnailPath,
    required this.fileSize,
    required this.downloadedAt,
    this.status = DownloadStatus.downloaded,
    this.progress = 1.0,
    this.errorMessage,
  });

  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lessonId': lessonId,
      'courseId': courseId,
      'title': title,
      'videoUrl': videoUrl,
      'localPath': localPath,
      'thumbnailPath': thumbnailPath,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
      'status': status.toString(),
      'progress': progress,
      'errorMessage': errorMessage,
    };
  }

  factory DownloadedLesson.fromJson(Map<String, dynamic> json) {
    return DownloadedLesson(
      id: json['id'],
      lessonId: json['lessonId'],
      courseId: json['courseId'],
      title: json['title'],
      videoUrl: json['videoUrl'] ?? '',
      localPath: json['localPath'] ??
          json['videoPath'] ??
          '', // Fallback for backward compat
      thumbnailPath: json['thumbnailPath'],
      fileSize: json['fileSize'],
      downloadedAt: DateTime.parse(json['downloadedAt']),
      status: DownloadStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => DownloadStatus.downloaded,
      ),
      progress: json['progress'] ?? 1.0,
      errorMessage: json['errorMessage'],
    );
  }

  DownloadedLesson copyWith({
    String? id,
    String? lessonId,
    String? courseId,
    String? title,
    String? videoUrl,
    String? localPath,
    String? thumbnailPath,
    int? fileSize,
    DateTime? downloadedAt,
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return DownloadedLesson(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      localPath: localPath ?? this.localPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      fileSize: fileSize ?? this.fileSize,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
