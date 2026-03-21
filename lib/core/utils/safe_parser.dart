import 'package:flutter/foundation.dart';

/// A production-grade utility for safe type parsing in Flutter.
/// Specifically designed to handle Flutter Web minification (JS) issues
/// and prevent "minified:aI is not a subtype of minified:B0" errors.
class SafeParser {
  
  /// Safely converts a dynamic value to a `List<Map<String, dynamic>>`.
  /// Handles cases where the input is a List of JS objects (on Web).
  static List<Map<String, dynamic>> safeMapList(dynamic raw) {
    if (raw == null || raw is! Iterable) return [];
    
    try {
      return raw.map((item) => safeMap(item)).toList();
    } catch (e) {
      debugPrint('❌ SafeParser.safeMapList error: $e');
      return [];
    }
  }

  /// Safely converts a dynamic value to a `Map<String, dynamic>`.
  /// Prevents direct casting errors by recreating the map.
  static Map<String, dynamic> safeMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    
    try {
      // Re-create the map to ensure it's truly Map<String, dynamic>
      // on all platforms, including web minified builds.
      final result = <String, dynamic>{};
      raw.forEach((key, value) {
        result[key.toString()] = value;
      });
      return result;
    } catch (e) {
      debugPrint('❌ SafeParser.safeMap error: $e');
      return {};
    }
  }

  /// Safely converts a dynamic value to an Integer.
  static int toInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    }
    return fallback;
  }

  /// Safely converts a dynamic value to a Double.
  static double toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safely converts a dynamic value to a Boolean.
  static bool toBool(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      final s = value.toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
    }
    return fallback;
  }

  /// Safely converts a dynamic value to a String.
  static String toStringSafe(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    if (value is String) return value;
    return value.toString();
  }

  /// Safely converts a dynamic value to a List of Strings.
  static List<String> toStringList(dynamic raw) {
    if (raw == null || raw is! Iterable) return [];
    try {
      return raw.map((e) => toStringSafe(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Safely converts a dynamic value to a DateTime.
  static DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
