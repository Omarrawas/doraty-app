import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';

class ImageUploadService {
  final SupabaseClient _client = SupabaseService.instance.client;
  final ImagePicker _picker = ImagePicker();

  /// Pick image from gallery or camera
  Future<File?> pickImage({ImageSource source = ImageSource.gallery}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Upload image to Supabase Storage
  Future<String> uploadImage(File imageFile, String bucket,
      {String? folder}) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final filePath = folder != null ? '$folder/$fileName' : fileName;

      await _client.storage.from(bucket).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final url = _client.storage.from(bucket).getPublicUrl(filePath);
      return url;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete image from Supabase Storage
  Future<void> deleteImage(String imageUrl, String bucket) async {
    try {
      // Extract file path from URL
      final uri = Uri.parse(imageUrl);
      final filePath = uri.pathSegments.last;

      await _client.storage.from(bucket).remove([filePath]);
    } catch (e) {
      rethrow;
    }
  }
}
