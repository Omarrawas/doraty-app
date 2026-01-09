import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'settings_service.dart';
import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/offline_storage_service.dart';
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
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult != ConnectivityResult.wifi) {
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

  Future<String?> _downloadFile(String url, String relativePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final savePath = '${appDir.path}/offline/$relativePath';
      final file = File(savePath);
      
      if (await file.exists()) {
        // Already exists? Skip or overwrite? For now skip
        return file.path;
      }
      
      await file.create(recursive: true);

      // Use Dio for better large file handling
      final dio = Dio();
      await dio.download(url, savePath);
      
      return savePath;
    } catch (e) {
      debugPrint('Failed to download file: $url, $e');
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
