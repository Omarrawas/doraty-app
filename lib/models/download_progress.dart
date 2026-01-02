enum DownloadStatus {
  pending,
  downloading,
  completed,
  failed,
  paused,
  cancelled,
}

class DownloadProgress {
  final String courseId;
  final String courseName;
  final int downloadedBytes;
  final int totalBytes;
  final double percentage;
  final DownloadStatus status;
  final String? error;

  DownloadProgress({
    required this.courseId,
    required this.courseName,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.percentage,
    required this.status,
    this.error,
  });
}
