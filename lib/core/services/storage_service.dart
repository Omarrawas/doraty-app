import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class StorageService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Upload avatar image
  Future<String> uploadAvatar(File file) async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'avatars/$fileName';

      await _client.storage.from('avatars').upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload course thumbnail
  Future<String> uploadCourseThumbnail(File file, String courseId) async {
    try {
      final fileName = '$courseId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'course-thumbnails/$fileName';

      await _client.storage.from('course-thumbnails').upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      final publicUrl =
          _client.storage.from('course-thumbnails').getPublicUrl(path);
      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete file from storage
  Future<void> deleteFile(String bucket, String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (e) {
      rethrow;
    }
  }

  /// Add cache busting to existing URL
  String addCacheBusting(String url) {
    final uri = Uri.parse(url);
    final newQuery = Map<String, String>.from(uri.queryParameters);
    newQuery['cb'] = DateTime.now().millisecondsSinceEpoch.toString();
    final newUri = uri.replace(queryParameters: newQuery);
    return newUri.toString();
  }

  /// Get avatar URL with cache busting
  String getAvatarUrlWithCacheBusting(String userId, {int? timestamp}) {
    final ts = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final baseUrl =
        _client.storage.from('avatars').getPublicUrl('$userId-$ts.jpg');
    return addCacheBusting(baseUrl);
  }
}
