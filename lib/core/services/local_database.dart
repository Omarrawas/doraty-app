import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// A unified local caching service using Hive for persistence.
/// Optimized for Flutter Web minification and type safety.
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  final Map<String, Box> _boxes = {};

  // Standard boxes
  static const String boxGeneral = 'app_local_database';
  static const String boxCourses = 'courses_cache';
  static const String boxLessons = 'lessons_cache';
  static const String boxUserData = 'user_data_cache';
  static const String boxOffline = 'offline_actions';
  static const String boxMetadata = 'cache_metadata';

  /// Initialize Hive and open all required boxes
  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = () async {
      await Hive.initFlutter();

      final boxes = <String>[
        boxGeneral,
        boxCourses,
        boxLessons,
        boxUserData,
        boxOffline,
        boxMetadata,
      ];

      for (final name in boxes) {
        await _openBox(name);
      }

      _isInitialized = true;
      debugPrint('LocalDatabase initialized successfully');
    }();

    try {
      await _initFuture;
    } catch (e) {
      debugPrint('LocalDatabase init error: $e');
    } finally {
      _initFuture = null;
    }
  }

  Future<Box> _openBox(String name) async {
    if (_boxes.containsKey(name)) return _boxes[name]!;

    try {
      final Box box;
      if (Hive.isBoxOpen(name)) {
        box = Hive.box(name);
      } else {
        // Keep type aligned with OfflineCacheService to avoid type mismatches.
        box = await Hive.openBox<Map>(name);
      }

      _boxes[name] = box;
      debugPrint('Got object store box in database $name.');
      return box;
    } catch (e) {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        _boxes[name] = box;
        debugPrint('Got object store box in database $name.');
        return box;
      }
      rethrow;
    }
  }

  /// Get a box by name, defaults to general box
  Box _getBox([String? name]) {
    final boxName = name ?? boxGeneral;
    if (!_boxes.containsKey(boxName) && Hive.isBoxOpen(boxName)) {
      _boxes[boxName] = Hive.box(boxName);
    }
    if (!_boxes.containsKey(boxName)) {
      throw Exception('Box $boxName not opened. Call init() first.');
    }
    return _boxes[boxName]!;
  }

  /// Generic set operation
  Future<void> set(String key, dynamic value, {String? boxName}) async {
    try {
      final box = _getBox(boxName);
      await box.put(key, value);
      
      // Update metadata (timestamp)
      final metaBox = _getBox(boxMetadata);
      await metaBox.put('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('✅ LocalDatabase: Saved $key');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error saving $key: $e');
    }
  }

  /// Generic get operation with safe casting
  T? get<T>(String key, {String? boxName}) {
    try {
      final box = _getBox(boxName);
      final data = box.get(key);
      if (data == null) return null;

      return _safeCast<T>(data);
    } catch (e) {
      debugPrint('❌ LocalDatabase Error getting $key: $e');
      return null;
    }
  }

  /// Remove an item
  Future<void> remove(String key, {String? boxName}) async {
    try {
      final box = _getBox(boxName);
      await box.delete(key);
      final metaBox = _getBox(boxMetadata);
      await metaBox.delete('${key}_timestamp');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error deleting $key: $e');
    }
  }

  /// Check if data is expired
  bool isExpired(String key, Duration maxAge) {
    try {
      final metaBox = _getBox(boxMetadata);
      final timestamp = metaBox.get('${key}_timestamp') as int?;
      if (timestamp == null) return true;

      final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
      return age > maxAge;
    } catch (e) {
      return true;
    }
  }

  /// Implementation of "Local-First" pattern with stale-while-revalidate
  Future<T> localFirst<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration maxAge = const Duration(hours: 1),
    bool forceRefresh = false,
    String? boxName,
  }) async {
    try {
      await init();
      final cachedData = get<T>(key, boxName: boxName);
      final expired = isExpired(key, maxAge);

      if (cachedData != null && !expired && !forceRefresh) {
        return cachedData;
      }

      if (cachedData != null && (expired || forceRefresh)) {
        debugPrint('🕰️ LocalDatabase Hit (Stale): $key - Fetching new data in background');
        _backgroundUpdate(key, fetcher, boxName);
        return cachedData;
      }

      debugPrint('🌐 Fetching from Supabase: $key');
      final fetchedData = await fetcher();
      await set(key, fetchedData, boxName: boxName);
      return fetchedData;
    } catch (e) {
      debugPrint('❌ Fetch error for $key: $e');
      try {
        final lastResort = get<T>(key, boxName: boxName);
        if (lastResort != null) return lastResort;
      } catch (_) {}
      return await fetcher();
    }
  }

  Future<void> _backgroundUpdate<T>(String key, Future<T> Function() fetcher, String? boxName) async {
    try {
      final newData = await fetcher();
      await set(key, newData, boxName: boxName);
    } catch (e) {
      debugPrint('❌ Background update failed for $key: $e');
    }
  }

  /// Safely casts data to type T, with special handling for minified web builds
  static T _safeCast<T>(dynamic data) {
    if (data == null) return null as T;
    if (data is T) return data;

    try {
      return data as T;
    } catch (e) {
      return _complexCast<T>(data);
    }
  }

  /// Heavier casting logic for collections and primitives
  static T _complexCast<T>(dynamic data) {
    // 1. Handling Lists
    if (data is Iterable) {
      final List<dynamic> baseList = data.toList();
      
      if (_isListMapType<T>()) {
        try {
          final converted = baseList.map((item) {
            if (item is Map) return _deepMapConvert(item);
            return _deepConvert(item);
          }).toList();
          return List<Map<String, dynamic>>.from(converted) as T;
        } catch (_) {}
      }

      if (_isStringListType<T>()) {
        try {
          final converted = baseList.map((e) => e.toString()).toList();
          return List<String>.from(converted) as T;
        } catch (_) {}
      }

      try {
        final converted = baseList.map((e) => _deepConvert(e)).toList();
        return converted as T;
      } catch (_) {}
    }

    // 2. Handling Maps
    if (data is Map) {
      if (_isMapType<T>()) {
        try {
          final converted = _deepMapConvert(data);
          return Map<String, dynamic>.from(converted) as T;
        } catch (_) {}
      }
      
      final convertedMap = _deepMapConvert(data);
      try { return convertedMap as T; } catch (_) {}
    }

    // 3. Handling Numbers
    if (data is num) {
      final tStr = T.toString().toLowerCase();
      if (tStr.contains('double')) return data.toDouble() as T;
      if (tStr.contains('int')) return data.toInt() as T;
    }

    // 4. Ultimate Fallback
    final converted = _deepConvert(data);
    return converted as T;
  }

  static bool _isListMapType<T>() {
    final s = T.toString();
    return s.contains('List') && s.contains('Map');
  }
  
  static bool _isMapType<T>() {
    final s = T.toString();
    return s.contains('Map');
  }

  static bool _isStringListType<T>() {
    final s = T.toString();
    return s.contains('List') && s.contains('String');
  }

  static dynamic _deepConvert(dynamic value) {
    if (value == null) return null;
    if (value is Map) return _deepMapConvert(value);
    if (value is Iterable) return value.map((e) => _deepConvert(e)).toList();
    return value;
  }

  static Map<String, dynamic> _deepMapConvert(Map map) {
    final Map<String, dynamic> result = {};
    map.forEach((key, value) {
      result[key.toString()] = _deepConvert(value);
    });
    return result;
  }
}

