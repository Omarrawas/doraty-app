import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import '../env/multi_env.dart';

/// Service for interacting with GitHub API to upload files
class GitHubApiService {
  // Repository configuration
  static const String owner = 'Omarrawas';
  static const String repo = 'doraty-files';
  static const String branch = 'main';
  
  // API base URL
  static const String apiBaseUrl = 'https://api.github.com';
  
  // GitHub token (should be loaded from environment or secure storage)
  final String? _token;
  
  GitHubApiService({String? token}) : _token = token ?? Env.githubToken;
  
  /// Upload a file to GitHub repository
  /// 
  /// [bytes] - The file bytes to upload
  /// [fileName] - Original filename
  /// [remotePath] - Path in the repository (e.g., 'pdfs/worksheets/file.pdf')
  /// [commitMessage] - Optional custom commit message
  /// 
  /// Returns the raw URL of the uploaded file
  Future<String> uploadFile({
    required Uint8List bytes,
    required String fileName,
    required String remotePath,
    String? commitMessage,
  }) async {
    if (_token == null || _token.isEmpty) {
      throw Exception('GitHub token is required for file upload');
    }
    
    try {
      // Encode bytes to base64
      final base64Content = base64Encode(bytes);
      
      // Get filename for commit message
      final message = commitMessage ?? 'Upload $fileName via Doraty app';
      
      // Sanitize and encode path segments (important for filenames with spaces)
      final encodedPath = remotePath.split('/').map((s) => Uri.encodeComponent(s)).join('/');
      
      // API URL
      final url = Uri.parse('$apiBaseUrl/repos/$owner/$repo/contents/$encodedPath');
      
      // Check if file already exists
      final existingSha = await _getFileSha(encodedPath);
      
      // Prepare request body
      final body = {
        'message': message,
        'content': base64Content,
        'branch': branch,
      };
      
      // Add SHA if file exists (for update)
      if (existingSha != null) {
        body['sha'] = existingSha;
      }
      
      // Make API request - Use 'Bearer' as it's more standard for GitHub PATs now
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Success - return raw URL
        final rawUrl = _buildRawUrl(encodedPath);
        return rawUrl;
      } else {
        // Error
        final error = jsonDecode(response.body);
        throw Exception('GitHub API error (${response.statusCode}): ${error['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('GitHub Upload Error: $e');
      throw Exception('Failed to upload file to GitHub: $e');
    }
  }
  
  /// Get SHA of existing file (needed for updates)
  Future<String?> _getFileSha(String remotePath) async {
    try {
      final url = Uri.parse('$apiBaseUrl/repos/$owner/$repo/contents/$remotePath');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['sha'] as String?;
      }
      
      return null; // File doesn't exist
    } catch (e) {
      return null; // Assume file doesn't exist
    }
  }
  
  /// Build raw URL for accessing file content
  String _buildRawUrl(String remotePath) {
    return 'https://raw.githubusercontent.com/$owner/$repo/$branch/$remotePath';
  }
  
  /// Generate recommended path for a file based on its type
  static String generatePath(String fileName, {String? customFolder}) {
    final extension = path.extension(fileName).toLowerCase();
    
    // Timestamp for unique filenames
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final uniqueFilename = '${timestamp}_${path.basename(fileName)}';
    
    // Determine folder based on file type
    String folder;
    
    if (customFolder != null) {
      folder = customFolder;
    } else if (extension == '.pdf') {
      folder = 'pdfs/lessons';
    } else if (['.mp3', '.wav', '.ogg', '.m4a'].contains(extension)) {
      folder = 'audio/lessons';
    } else if (['.html', '.htm'].contains(extension)) {
      folder = 'interactive-apps';
    } else {
      folder = 'other';
    }
    
    return '$folder/$uniqueFilename';
  }
  
  /// Validate GitHub token
  Future<bool> validateToken() async {
    if (_token == null || _token.isEmpty) {
      return false;
    }
    
    try {
      final url = Uri.parse('$apiBaseUrl/user');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_token',
          'Accept': 'application/vnd.github.v3+json',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
  
  /// Get repository information
  Future<Map<String, dynamic>?> getRepoInfo() async {
    try {
      final url = Uri.parse('$apiBaseUrl/repos/$owner/$repo');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          if (_token != null && _token.isNotEmpty)
            'Authorization': 'Bearer $_token',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}
