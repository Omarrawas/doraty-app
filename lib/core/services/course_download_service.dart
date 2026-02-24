import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'settings_service.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import 'offline_storage_service.dart';
import 'encryption_service.dart';
import '../../models/download_progress.dart';
import '../../models/offline_course.dart';
import '../../models/offline_lesson.dart';

class CourseDownloadService {
  static final CourseDownloadService _instance = CourseDownloadService._internal();
  factory CourseDownloadService() => _instance;
  CourseDownloadService._internal();
  
  final DatabaseService _db = DatabaseService();
  final OfflineStorageService _storage = OfflineStorageService();
  
  // Track active downloads
  final Map<String, StreamController<DownloadProgress>> _activeDownloads = {};
  final Map<String, bool> _cancelTokens = {};

  Stream<DownloadProgress> downloadCourse(String courseId, {bool includeVideos = false}) {
    if (_activeDownloads.containsKey(courseId)) {
      return _activeDownloads[courseId]!.stream;
    }

    final controller = StreamController<DownloadProgress>.broadcast();
    _activeDownloads[courseId] = controller;
    _cancelTokens[courseId] = false;

    _startDownload(courseId, controller, includeVideos);

    return controller.stream;
  }

  Future<void> _startDownload(
    String courseId,
    StreamController<DownloadProgress> controller,
    bool includeVideos,
  ) async {
    try {
      // 0. Check WiFi Constraint
      if (SettingsService().getWifiOnly()) {
        final connectivityResults = await Connectivity().checkConnectivity();
        if (!connectivityResults.contains(ConnectivityResult.wifi)) {
          throw Exception('Download restricted to WiFi only. Please connect to WiFi or change settings.');
        }
      }

      // 1. Fetch Course Data
      controller.add(DownloadProgress(
        courseId: courseId,
        courseName: 'Fetching details...',
        downloadedBytes: 0,
        totalBytes: 0,
        percentage: 0,
        status: DownloadStatus.pending,
      ));

      final courseData = await _db.getCourseById(courseId);
      if (courseData == null) throw Exception('Course not found');
      
      final String courseTitle = courseData['title'];
      final String? thumbnailUrl = courseData['thumbnail_url'];

      if (_isCancelled(courseId)) return;

      // 2. Fetch Lessons
      final lessonsData = await _db.getLessons(courseId);
      
      // Calculate total steps/size (estimation)
      // Estimate: 1 course image + N lessons * (content + optional video)
      int totalItems = 1 + lessonsData.length;
      int completedItems = 0;
      int totalSize = 0;

      // 3. Download Course Thumbnail
      String? localThumbnailPath;
      if (thumbnailUrl != null) {
        controller.add(DownloadProgress(
          courseId: courseId,
          courseName: courseTitle,
          downloadedBytes: 0,
          totalBytes: 100,
          percentage: 0.05,
          status: DownloadStatus.downloading,
        ));
        
        localThumbnailPath = await _downloadFile(thumbnailUrl, 'courses/$courseId/thumbnail.jpg');
        completedItems++;
      }

      final List<String> lessonIds = [];

      // 4. Process Lessons
      for (var lessonJson in lessonsData) {
        if (_isCancelled(courseId)) {
          controller.add(DownloadProgress(
            courseId: courseId,
            courseName: courseTitle,
            downloadedBytes: 0,
            totalBytes: 0,
            percentage: 0,
            status: DownloadStatus.cancelled,
          ));
          _cleanup(courseId);
          return;
        }

        final lessonId = lessonJson['id'];
        lessonIds.add(lessonId);
        
        // Prepare Lesson Data
        // Download video if requested
        String? localVideoPath;
        if (includeVideos && lessonJson['video_url'] != null) {
          final videoUrl = lessonJson['video_url'];
          controller.add(DownloadProgress(
            courseId: courseId,
            courseName: '$courseTitle (Lesson ${completedItems + 1})',
            downloadedBytes: (completedItems * 1000).toInt(),
            totalBytes: (totalItems * 1000).toInt(),
            percentage: ((completedItems) / totalItems),
            status: DownloadStatus.downloading,
          ));
          
          localVideoPath = await _downloadFile(videoUrl, 'courses/$courseId/lessons/$lessonId.mp4');
        }

        // Save Offline Lesson
        final offlineLesson = OfflineLesson(
          id: lessonId,
          courseId: courseId,
          title: lessonJson['title'],
          videoPath: localVideoPath,
          content: lessonJson['content'] ?? lessonJson['description'], // Assuming content is available
          isDownloaded: true,
          duration: lessonJson['duration']?.toString() ?? '0:00',
          orderIndex: lessonJson['order_index'] ?? 0,
        );

        await _storage.saveLesson(offlineLesson);
        
        completedItems++;
        double percent = completedItems / totalItems;
        
        controller.add(DownloadProgress(
          courseId: courseId,
          courseName: courseTitle,
          downloadedBytes: completedItems * 1000, // Fake bytes
          totalBytes: totalItems * 1000,
          percentage: percent,
          status: DownloadStatus.downloading,
        ));
      }

      // 5. Save Offline Course
      final offlineCourse = OfflineCourse(
        id: courseId,
        title: courseTitle,
        description: courseData['description'],
        thumbnailPath: localThumbnailPath,
        lessonIds: lessonIds,
        downloadedAt: DateTime.now(),
        lastSyncAt: DateTime.now(),
        totalSize: totalSize, // We should track actual file sizes
      );

      await _storage.saveCourse(offlineCourse);

      controller.add(DownloadProgress(
        courseId: courseId,
        courseName: courseTitle,
        downloadedBytes: totalItems * 1000,
        totalBytes: totalItems * 1000,
        percentage: 1.0,
        status: DownloadStatus.completed,
      ));

    } catch (e) {
      debugPrint('Error downloading course: $e');
      controller.add(DownloadProgress(
        courseId: courseId,
        courseName: 'Error',
        downloadedBytes: 0,
        totalBytes: 0,
        percentage: 0,
        status: DownloadStatus.failed,
        error: e.toString(),
      ));
    } finally {
      if (!_activeDownloads[courseId]!.isClosed) {
        // Don't close immediately so UI can see completion
        // _activeDownloads[courseId]!.close();
      }
      _cleanup(courseId);
    }
  }

  Future<String?> downloadResource({
    required String url,
    required String courseId,
    required String lessonId,
    required String fileName,
  }) async {
    try {
      if (kIsWeb) {
        // 1. Download as bytes
        final dio = Dio();
        final response = await dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );

        if (response.data == null) return null;
        final sourceBytes = Uint8List.fromList(response.data!);

        // 2. Encrypt bytes
        final encryptedBytes =
            await EncryptionService().encryptBytes(sourceBytes);

        // 3. Save to Hive
        await _storage.saveResource(lessonId, fileName, encryptedBytes);

        // 4. Update offline lesson record
        final offlineLesson = await _storage.getLesson(lessonId);
        if (offlineLesson != null) {
          final Map<String, String> currentResources =
              Map.from(offlineLesson.downloadedResources ?? {});
          currentResources[fileName] =
              'hive://$lessonId/$fileName'; // Virtual path for web

          final updatedLesson = OfflineLesson(
            id: offlineLesson.id,
            courseId: offlineLesson.courseId,
            title: offlineLesson.title,
            videoPath: offlineLesson.videoPath,
            content: offlineLesson.content,
            isDownloaded: offlineLesson.isDownloaded,
            duration: offlineLesson.duration,
            orderIndex: offlineLesson.orderIndex,
            downloadedResources: currentResources,
          );
          await _storage.saveLesson(updatedLesson);
        }
        // 5. Update course metadata to show in "Downloads"
        await _updateCourseMetadata(courseId, encryptedBytes.length);
        return 'hive://$lessonId/$fileName';
      }

      // Native implementation
      final appDir = await getApplicationDocumentsDirectory();
      final relativePath =
          'courses/$courseId/lessons/$lessonId/resources/$fileName';
      final savePath = '${appDir.path}/offline/$relativePath';

      // 1. Download to temp file
      final tempPath = '$savePath.tmp';
      final tempFile = File(tempPath);
      await tempFile.create(recursive: true);

      final dio = Dio();
      await dio.download(url, tempPath);

      final fileSize = await tempFile.length();
      final totalAddedSize = fileSize + 16; // Account for IV header

      // 2. Encrypt to final path
      await EncryptionService().encryptFile(tempFile, savePath);

      // 3. Cleanup temp
      await tempFile.delete();

      // 4. Update offline lesson record
      final offlineLesson = await _storage.getLesson(lessonId);
      if (offlineLesson != null) {
        final Map<String, String> currentResources =
            Map.from(offlineLesson.downloadedResources ?? {});
        currentResources[fileName] = savePath;

        final updatedLesson = OfflineLesson(
          id: offlineLesson.id,
          courseId: offlineLesson.courseId,
          title: offlineLesson.title,
          videoPath: offlineLesson.videoPath,
          content: offlineLesson.content,
          isDownloaded: offlineLesson.isDownloaded,
          duration: offlineLesson.duration,
          orderIndex: offlineLesson.orderIndex,
          downloadedResources: currentResources,
        );
        await _storage.saveLesson(updatedLesson);
      }

      // 5. Update course metadata to show in "Downloads"
      await _updateCourseMetadata(courseId, totalAddedSize);

      return savePath;
    } catch (e) {
      debugPrint('Failed to download and encrypt resource: $e');
      return null;
    }
  }

  Future<void> _updateCourseMetadata(String courseId, int addedSize) async {
    try {
      var offlineCourse = await _storage.getCourse(courseId);

      if (offlineCourse == null) {
        // Create skeleton course if it doesn't exist
        final courseData = await _db.getCourseById(courseId);
        if (courseData == null) return;

        // Fetch lesson IDs for the course
        final lessons = await _db.getLessons(courseId);
        final lessonIds = lessons.map((l) => l['id'] as String).toList();

        offlineCourse = OfflineCourse(
          id: courseId,
          title: courseData['title'] ?? 'Unknown Course',
          description: courseData['description'],
          thumbnailPath:
              null, // We could download this too, but let's keep it simple
          lessonIds: lessonIds,
          downloadedAt: DateTime.now(),
          lastSyncAt: DateTime.now(),
          totalSize: addedSize,
        );
      } else {
        // Update size
        offlineCourse = OfflineCourse(
          id: offlineCourse.id,
          title: offlineCourse.title,
          description: offlineCourse.description,
          thumbnailPath: offlineCourse.thumbnailPath,
          lessonIds: offlineCourse.lessonIds,
          downloadedAt: offlineCourse.downloadedAt,
          lastSyncAt: DateTime.now(),
          totalSize: offlineCourse.totalSize + addedSize,
        );
      }

      await _storage.saveCourse(offlineCourse);
    } catch (e) {
      debugPrint('Error updating course metadata: $e');
    }
  }

  Future<String?> _downloadFile(String url, String relativePath) async {
    if (kIsWeb) {
      // On Web, we don't download files to disk.
      // This method is used for course thumbnails etc.
      // For now, return the URL as the "local" path, or we could cache in Hive if needed.
      return url;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDir.path}/offline/$relativePath';
      final file = File(savePath);
      
      if (await file.exists()) return savePath;
      
      await file.create(recursive: true);
      final dio = Dio();
      await dio.download(url, savePath);
      
      return savePath;
    } catch (e) {
      debugPrint('Error downloading file $relativePath: $e');
      return null;
    }
  }

  void cancelDownload(String courseId) {
    if (_activeDownloads.containsKey(courseId)) {
      _cancelTokens[courseId] = true;
    }
  }

  bool _isCancelled(String courseId) {
    return _cancelTokens[courseId] == true;
  }

  void _cleanup(String courseId) {
    _activeDownloads.remove(courseId);
    _cancelTokens.remove(courseId); 
  }
}
