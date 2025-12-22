import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:hive/hive.dart';
import '../core/services/encryption_service.dart';
import '../core/services/local_server_service.dart';
import 'downloaded_lesson.dart';

export 'downloaded_lesson.dart';

class CancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class DownloadManager extends ChangeNotifier {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  List<DownloadedLesson> _downloads = [];
  Box<DownloadedLesson>? _box;
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, CancelToken> _cancelTokens = {};

  // Retry configuration
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  List<DownloadedLesson> get allDownloads => _downloads;

  List<DownloadedLesson> get activeDownloads {
    return _downloads
        .where((d) =>
            d.status == DownloadStatus.downloading ||
            d.status == DownloadStatus.paused)
        .toList();
  }

  List<DownloadedLesson> get downloads =>
      _downloads.where((d) => d.status == DownloadStatus.downloaded).toList();

  int get totalSize {
    return downloads.fold(0, (sum, d) => sum + d.fileSize);
  }

  Future<void> init() async {
    // Open Hive box for downloads
    _box = await Hive.openBox<DownloadedLesson>('downloads');
    _downloads = _box!.values.toList();
    notifyListeners();
  }

  Future<void> _saveToHive(DownloadedLesson lesson) async {
    if (_box != null) {
      await _box!.put(lesson.id, lesson);
    }
  }

  Future<void> _removeFromHive(String id) async {
    if (_box != null) {
      await _box!.delete(id);
    }
  }

  Future<void> startDownload(DownloadedLesson lesson) async {
    await _startDownloadWithRetry(lesson, 0);
  }

  Future<void> _startDownloadWithRetry(
      DownloadedLesson lesson, int retryCount) async {
    // Check if already downloaded/downloading
    final index = _downloads.indexWhere((d) => d.id == lesson.id);
    if (index == -1) {
      _downloads.add(lesson.copyWith(status: DownloadStatus.downloading));
    } else {
      _downloads[index] = lesson.copyWith(status: DownloadStatus.downloading);
    }

    // Save initial state to Hive
    await _saveToHive(_downloads.firstWhere((d) => d.id == lesson.id));
    notifyListeners();

    File? tempFile;
    YoutubeExplode? yt;
    StreamSubscription? streamSubscription;

    try {
      final isYoutube = lesson.videoUrl.contains('youtube.com') ||
          lesson.videoUrl.contains('youtu.be');

      int? totalBytes;
      Stream<List<int>> stream;

      if (isYoutube) {
        yt = YoutubeExplode();
        // Get the video manifest
        final videoId = VideoId(lesson.videoUrl);
        final manifest = await yt.videos.streamsClient.getManifest(videoId);
        // Prioritize muxed (audio+video) streams, specifically mp4 for compatibility
        final streamInfo = manifest.muxed.withHighestBitrate();

        totalBytes = streamInfo.size.totalBytes;
        stream = yt.videos.streamsClient.get(streamInfo);
      } else {
        // Direct file link
        final uri = Uri.parse(lesson.videoUrl);
        final client = http.Client();
        final request = http.Request('GET', uri);
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw Exception(
              'HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
        totalBytes = response.contentLength;
        stream = response.stream;
      }

      // Create cancel token for this download
      final cancelToken = CancelToken();
      _cancelTokens[lesson.id] = cancelToken;

      // 1. Download to temp file
      final dir = await getApplicationDocumentsDirectory();
      final tempFilename = '${lesson.lessonId}_temp.tmp';
      tempFile = File('${dir.path}/$tempFilename');
      final sink = tempFile.openWrite();

      final contentLength = totalBytes ?? 0;
      int bytes = 0;

      // Create stream subscription for cancellation support
      streamSubscription = stream.listen(
        (chunk) {
          if (cancelToken.isCancelled) return;
          sink.add(chunk);
          bytes += chunk.length;

          final progress = contentLength > 0 ? bytes / contentLength : 0.0;
          final updIndex = _downloads.indexWhere((d) => d.id == lesson.id);
          if (updIndex != -1) {
            _downloads[updIndex] = _downloads[updIndex].copyWith(
              progress: progress * 0.9,
            );
            _saveToHive(_downloads[updIndex]);
            notifyListeners();
          }
        },
        onError: (error) {
          throw error;
        },
        onDone: () async {
          if (!cancelToken.isCancelled) {
            await _completeDownload(lesson, tempFile, yt, sink);
          }
        },
        cancelOnError: true,
      );

      _activeSubscriptions[lesson.id] = streamSubscription;

      // Wait for completion or cancellation
      await streamSubscription.asFuture();
    } catch (e) {
      debugPrint('Download Error: $e');
      yt?.close(); // Ensure clean up
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      // Retry logic
      if (retryCount < maxRetries && !_cancelTokens[lesson.id]!.isCancelled) {
        debugPrint('Retrying download in ${retryDelay * (retryCount + 1)}');
        await Future.delayed(retryDelay * (retryCount + 1));
        await _startDownloadWithRetry(lesson, retryCount + 1);
      } else {
        _markFailed(lesson.id, e.toString());
      }
    } finally {
      _activeSubscriptions.remove(lesson.id);
      _cancelTokens.remove(lesson.id);
    }
  }

  Future<void> _completeDownload(DownloadedLesson lesson, File? tempFile,
      YoutubeExplode? yt, IOSink sink) async {
    try {
      await sink.close();
      yt?.close();

      // 2. Encrypt the file
      final dir = await getApplicationDocumentsDirectory();
      final encFilename = '${lesson.lessonId}_secure.enc';
      final encPath = '${dir.path}/$encFilename';

      final encIndex = _downloads.indexWhere((d) => d.id == lesson.id);
      if (encIndex != -1) {
        _downloads[encIndex] = _downloads[encIndex].copyWith(progress: 0.95);
        notifyListeners();
      }

      await EncryptionService().encryptFile(tempFile!, encPath);

      // 3. Cleanup temp
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final finalIndex = _downloads.indexWhere((d) => d.id == lesson.id);
      if (finalIndex != -1) {
        _downloads[finalIndex] = _downloads[finalIndex].copyWith(
          status: DownloadStatus.downloaded,
          localPath: encPath,
          fileSize: await File(encPath).length(),
          downloadedAt: DateTime.now(),
          progress: 1.0,
        );
        await _saveToHive(_downloads[finalIndex]);
        notifyListeners();
      }
    } catch (e) {
      _markFailed(lesson.id, 'فشل في إكمال التحميل: $e');
    }
  }

  void _markFailed(String id, [String? errorMessage]) {
    final index = _downloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.failed,
        errorMessage: errorMessage,
      );
      _saveToHive(_downloads[index]);
      notifyListeners();
    }
  }

  Future<void> pauseDownload(String id) async {
    final subscription = _activeSubscriptions[id];
    if (subscription != null) {
      subscription.pause();
      final index = _downloads.indexWhere((d) => d.id == id);
      if (index != -1) {
        _downloads[index] =
            _downloads[index].copyWith(status: DownloadStatus.paused);
        await _saveToHive(_downloads[index]);
        notifyListeners();
      }
    }
  }

  Future<void> resumeDownload(String id) async {
    final subscription = _activeSubscriptions[id];
    if (subscription != null) {
      subscription.resume();
      final index = _downloads.indexWhere((d) => d.id == id);
      if (index != -1) {
        _downloads[index] =
            _downloads[index].copyWith(status: DownloadStatus.downloading);
        await _saveToHive(_downloads[index]);
        notifyListeners();
      }
    } else {
      // If no active subscription, restart download
      final lesson = _downloads.firstWhere((d) => d.id == id);
      startDownload(lesson);
    }
  }

  Future<void> cancelDownload(String id) async {
    final subscription = _activeSubscriptions[id];
    subscription?.cancel();

    final cancelToken = _cancelTokens[id];
    cancelToken?.cancel();

    _activeSubscriptions.remove(id);
    _cancelTokens.remove(id);

    // Remove from downloads list but keep in Hive for potential resume
    final index = _downloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      final download = _downloads[index];
      if (download.status != DownloadStatus.downloaded) {
        _downloads[index] = download.copyWith(status: DownloadStatus.cancelled);
        await _saveToHive(_downloads[index]);
      }
    }
    notifyListeners();
  }

  Future<void> deleteDownload(String id) async {
    try {
      final index = _downloads.indexWhere((d) => d.id == id);
      if (index != -1) {
        final path = _downloads[index].localPath;
        if (path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (_) {}
    _downloads.removeWhere((d) => d.id == id);
    await _removeFromHive(id);
    notifyListeners();
  }

  bool isDownloaded(String lessonId) {
    return _downloads.any(
      (d) => d.lessonId == lessonId && d.status == DownloadStatus.downloaded,
    );
  }

  DownloadedLesson? getDownload(String lessonId) {
    try {
      return _downloads.firstWhere(
        (d) => d.lessonId == lessonId && d.status == DownloadStatus.downloaded,
      );
    } catch (e) {
      return null;
    }
  }

  // Get playable URL (Localhost or direct path if not encrypted check?)
  // We assume all downloads via this manager are encrypted.
  Future<String?> getPlayableUrl(String lessonId) async {
    final download = getDownload(lessonId);
    if (download == null) return null;

    return await LocalServerService().getPlayableUrl(download.localPath);
  }

  @override
  void dispose() {
    _box?.close();
    for (final subscription in _activeSubscriptions.values) {
      subscription.cancel();
    }
    _activeSubscriptions.clear();
    _cancelTokens.clear();
    super.dispose();
  }
}
