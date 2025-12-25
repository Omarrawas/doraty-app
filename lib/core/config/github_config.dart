import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for GitHub integration
class GitHubConfig {
  // Repository details
  static const String owner = 'Omarrawas';
  static const String repo = 'doraty-files';
  static const String branch = 'main';
  
  /// Get GitHub token from .env file
  static String get token {
    try {
      // Load from .env file
      return dotenv.env['GITHUB_TOKEN'] ?? '';
    } catch (e) {
      return '';
    }
  }
  
  /// Check if GitHub token is configured
  static bool get isConfigured {
    final t = token;
    return t.isNotEmpty && t != 'your_github_token_here';
  }
  
  /// Get repository URL
  static String get repoUrl => 'https://github.com/$owner/$repo';
  
  /// Get raw content base URL
  static String get rawBaseUrl => 'https://raw.githubusercontent.com/$owner/$repo/$branch';
}
