import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'supabase_service.dart';

class FileUploadService {
  final SupabaseClient _client = SupabaseService.instance.client;

  /// Pick files (PDFs, PPTs, etc.)
  Future<List<File>> pickFiles({
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: allowedExtensions != null ? FileType.custom : FileType.any,
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
      );

      if (result != null) {
        return result.paths.map((path) => File(path!)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Upload file to Supabase Storage
  Future<Map<String, String>> uploadFile(
    File file,
    String bucket, {
    String? folder,
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final filePath = folder != null ? '$folder/$fileName' : fileName;

      await _client.storage.from(bucket).upload(
            filePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final url = _client.storage.from(bucket).getPublicUrl(filePath);
      
      return {
        'name': path.basename(file.path),
        'url': url,
        'type': path.extension(file.path).replaceAll('.', ''),
        'size': _formatFileSize(file.lengthSync()),
      };
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}