/// Service for handling GitHub-based file storage
/// Converts GitHub URLs to raw content URLs and manages file references
class GitHubStorageService {
  // Base URL for the doraty-files repository
  static const String baseRepoUrl = 'https://github.com/Omarrawas/doraty-files';
  static const String baseRawUrl = 'https://raw.githubusercontent.com/Omarrawas/doraty-files/main';

  /// Convert a GitHub URL to a raw content URL
  /// 
  /// Examples:
  /// - https://github.com/Omarrawas/doraty-files/blob/main/pdfs/worksheet.pdf
  ///   -> https://raw.githubusercontent.com/Omarrawas/doraty-files/main/pdfs/worksheet.pdf
  /// 
  /// - https://raw.githubusercontent.com/Omarrawas/doraty-files/main/audio/lesson.mp3
  ///   -> https://raw.githubusercontent.com/Omarrawas/doraty-files/main/audio/lesson.mp3 (no change)
  static String toRawUrl(String url) {
    // Already a raw URL
    if (url.contains('raw.githubusercontent.com')) {
      return url;
    }

    // Convert blob URL to raw URL
    if (url.contains('github.com') && url.contains('/blob/')) {
      return url
          .replaceAll('github.com', 'raw.githubusercontent.com')
          .replaceAll('/blob/', '/');
    }

    // If it's a relative path, prepend the base raw URL
    if (!url.startsWith('http')) {
      return '$baseRawUrl/${url.startsWith('/') ? url.substring(1) : url}';
    }

    return url;
  }

  /// Build a GitHub raw URL from a file path
  /// 
  /// Example:
  /// buildRawUrl('pdfs/worksheets/biology-01.pdf')
  /// -> https://raw.githubusercontent.com/Omarrawas/doraty-files/main/pdfs/worksheets/biology-01.pdf
  static String buildRawUrl(String filePath) {
    // Remove leading slash if present
    final path = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    return '$baseRawUrl/$path';
  }

  /// Validate if a URL is a valid GitHub URL for doraty-files repo
  static bool isValidGitHubUrl(String url) {
    return url.contains('github.com/Omarrawas/doraty-files') ||
        url.contains('raw.githubusercontent.com/Omarrawas/doraty-files');
  }

  /// Determine file type from URL
  static FileType getFileType(String url) {
    final extension = url.split('.').last.toLowerCase().split('?').first;
    
    switch (extension) {
      case 'pdf':
        return FileType.pdf;
      case 'mp3':
      case 'wav':
      case 'ogg':
      case 'm4a':
        return FileType.audio;
      case 'html':
      case 'htm':
        return FileType.interactiveApp;
      case 'mp4':
      case 'webm':
      case 'mov':
        return FileType.video;
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'svg':
      case 'webp':
        return FileType.image;
      default:
        return FileType.other;
    }
  }

  /// Get the icon name for a file type
  static String getFileIcon(FileType type) {
    switch (type) {
      case FileType.pdf:
        return '📄';
      case FileType.audio:
        return '🔊';
      case FileType.interactiveApp:
        return '📱';
      case FileType.video:
        return '🎥';
      case FileType.image:
        return '🖼️';
      case FileType.other:
        return '📎';
    }
  }

  /// Extract filename from URL
  static String getFilename(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    return segments.isNotEmpty ? segments.last : 'file';
  }

  /// Get file category from path (e.g., pdfs, audio, interactive-apps)
  static String getCategory(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    
    // Look for known categories
    for (final segment in segments) {
      if (['pdfs', 'audio', 'interactive-apps'].contains(segment)) {
        return segment;
      }
    }
    
    return 'other';
  }

  /// Create a resource map for database storage
  static Map<String, String> createResourceMap({
    required String name,
    required String url,
    String? type,
  }) {
    final rawUrl = toRawUrl(url);
    final fileType = type ?? getFileType(rawUrl).name;
    
    return {
      'name': name,
      'url': rawUrl,
      'type': fileType,
    };
  }
}

/// File type enumeration
enum FileType {
  pdf,
  audio,
  interactiveApp,
  video,
  image,
  other,
}
