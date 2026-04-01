import 'package:flutter/foundation.dart';
import 'github_storage_service.dart';
import 'supabase_service.dart';

class StorageService {
  /// Upload avatar image to GitHub (Web-friendly)
  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final path = 'avatars/$userId/$timestamp.$extension';

      return await GitHubStorageService.uploadFile(
        bytes: bytes,
        path: path,
        commitMessage: 'Upload avatar for user $userId',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Upload course thumbnail to GitHub (Web-friendly)
  Future<String> uploadCourseThumbnail(Uint8List bytes, String fileName, String courseId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final path = 'course-thumbnails/$courseId/$timestamp.$extension';

      return await GitHubStorageService.uploadFile(
        bytes: bytes,
        path: path,
        commitMessage: 'Upload course thumbnail for course $courseId',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Upload teacher document (Web-friendly)
  Future<String> uploadTeacherDocument(Uint8List bytes, String fileName, String userId, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = fileName.split('.').last;
      final path = 'teacher-documents/$userId/${type}_$timestamp.$extension';

      return await GitHubStorageService.uploadFile(
        bytes: bytes,
        path: path,
        commitMessage: 'Upload $type for teacher $userId',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete file (not directly supported easily on GitHub without sha, so we might skip or use API)
  Future<void> deleteFile(String bucket, String path) async {
    // GitHub deletion requires sha, which we don't store easily.
    // For now, we skip deletion to avoid complexity unless requested.
  }

  /// Add cache busting to existing URL
  String addCacheBusting(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.parse(url);
    final newQuery = Map<String, String>.from(uri.queryParameters);
    newQuery['cb'] = DateTime.now().millisecondsSinceEpoch.toString();
    final newUri = uri.replace(queryParameters: newQuery);
    return newUri.toString();
  }

  /// Get avatar URL with cache busting (GitHub specific)
  String getAvatarUrlWithCacheBusting(String userId, {int? timestamp}) {
    // This assumes we know the filename, but with GitHub we use the returned URL from upload
    // If we need to construct it, it follows the pattern:
    // https://raw.githubusercontent.com/Omarrawas/doraty-files/main/avatars/userId/timestamp.jpg
    return ''; // Usually retrieved from DB profile
  }
}
