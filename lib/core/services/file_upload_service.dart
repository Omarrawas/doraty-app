import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class FileUploadService {
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Pick files (PDFs, PPTs, etc.)
  Future<List<PlatformFile>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: true, // Required for web to get bytes
      );

      if (result != null) {
        return result.files;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Delete file from Supabase Storage
  Future<void> deleteFile(String fileUrl, String bucket) async {
    try {
      final uri = Uri.parse(fileUrl);
      final filePath = uri.pathSegments.last;
      await _client.storage.from(bucket).remove([filePath]);
    } catch (e) {
      rethrow;
    }
  }
}