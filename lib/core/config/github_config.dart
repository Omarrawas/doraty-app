import '../env/multi_env.dart';

/// Configuration for GitHub integration
class GitHubConfig {
  // Repository details
  static const String owner = 'Omarrawas';
  static const String repo = 'doraty-files';
  static const String branch = 'main';
  
  /// Get GitHub token from Env class
  static String get token => Env.githubToken;
  
  /// Check if GitHub token is configured
  static bool get isConfigured {
    final t = token;
    return t.isNotEmpty;
  }
  
  /// Get repository URL
  static String get repoUrl => 'https://github.com/$owner/$repo';
  
  /// Get raw content base URL
  static String get rawBaseUrl => 'https://raw.githubusercontent.com/$owner/$repo/$branch';
}
