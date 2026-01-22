/// String utility functions for the application.
class StringUtils {
  /// Cleans a teacher's name by removing hardcoded titles like "Dr." or "د.".
  static String cleanTeacherName(String? name) {
    if (name == null || name.isEmpty) return '';

    // Remove common titles and prefixes
    String cleaned = name
        .replaceAll(RegExp(r'^(Dr\.|dr\.|د\.|د/)\s*', caseSensitive: false), '')
        .trim();

    // Remove any extra double spaces that might have been left
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned;
  }
}
