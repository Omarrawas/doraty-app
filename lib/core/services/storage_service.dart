import 'dart:io';
import 'github_storage_service.dart';
import 'supabase_service.dart';

class StorageService {
  /// Upload avatar image to GitHub
  Future<String> uploadAvatar(File file) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';
      final path = 'avatars/$userId/$fileName';

      return await GitHubStorageService.uploadFile(
        file: file,
        path: path,
        commitMessage: 'Upload avatar for user $userId',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Upload course thumbnail to GitHub
  Future<String> uploadCourseThumbnail(File file, String courseId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';
      final path = 'course-thumbnails/$courseId/$fileName';

      return await GitHubStorageService.uploadFile(
        file: file,
        path: path,
        commitMessage: 'Upload course thumbnail for course $courseId',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Upload teacher document (CV or Certificate) to GitHub
  Future<String> uploadTeacherDocument(File file, String userId, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = file.path.split('.').last;
      final fileName = '${type}_$timestamp.$extension';
      final path = 'teacher-documents/$userId/$fileName';

      return await GitHubStorageService.uploadFile(
        file: file,
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
