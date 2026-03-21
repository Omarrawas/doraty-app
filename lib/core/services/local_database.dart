import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/safe_parser.dart';

/// Production-grade Local Database using Hive.
/// Optimized for Flutter Web minification and type safety.
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  final Map<String, Box> _boxes = {};
  
  // ELITE MODE: Memory Cache Layer
  static final Map<String, dynamic> _memoryCache = {};

  // Standard boxes
  static const String boxGeneral = 'app_local_database';
  static const String boxMetadata = 'app_metadata_box';
  static const String boxVersions = 'app_versions_box'; // New: Version-based invalidation

  /// Initialize Hive and open all required boxes
  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = () async {
      final boxes = <String>[boxGeneral, boxMetadata, boxVersions];

      for (final name in boxes) {
        await _openBox(name);
      }

      _isInitialized = true;
      debugPrint('🚀 LocalDatabase: Elite Version initialized');
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
      final Box box = await Hive.openBox(name);
      _boxes[name] = box;
      return box;
    } catch (e) {
      if (Hive.isBoxOpen(name)) {
        final box = Hive.box(name);
        _boxes[name] = box;
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

  /// DEEP recursive normalization — converts every nested Map to Map<String, dynamic>
  /// and every nested List to List<dynamic>. This is essential for Flutter Web where
  /// Supabase/Dart returns LinkedHashMap<dynamic, dynamic> at every join level.
  dynamic _deepNormalize(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.fromEntries(
        value.entries.map((e) => MapEntry(e.key.toString(), _deepNormalize(e.value))),
      );
    }
    if (value is Iterable && value is! String) {
      return value.map(_deepNormalize).toList();
    }
    return value;
  }

  /// Generic set operation with strict normalization and memory caching
  Future<void> set(String key, dynamic value, {String? boxName, String? version}) async {
    try {
      final box = _getBox(boxName);
      
      // DEEP normalize before saving — converts all nested Maps/Lists recursively.
      // Critical for Flutter Web: Supabase returns LinkedHashMap<dynamic, dynamic>
      // at nested levels which causes type cast failures on minified builds.
      final normalizedValue = _deepNormalize(value);
      
      // PERSISTENT LAYER (Hive)
      await box.put(key, normalizedValue);
      
      // ELITE LAYER (Memory Cache)
      final cacheKey = '${boxName ?? boxGeneral}_$key';
      _memoryCache[cacheKey] = normalizedValue;
      
      // METADATA LAYER (TTL & Versioning)
      final metaBox = _getBox(boxMetadata);
      await metaBox.put('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (version != null) {
        final versionBox = _getBox(boxVersions);
        await versionBox.put(key, version);
      }
      
      debugPrint('✅ LocalDatabase: Saved $key (Memory + Hive)');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error saving $key: $e');
    }
  }

  /// Retrieves data safely with 3-layer check (Memory -> Hive -> Null)
  T? get<T>(String key, {String? boxName, String? requiredVersion}) {
    try {
      final cacheKey = '${boxName ?? boxGeneral}_$key';
      
      // 1. LAYER ONE: Memory Cache (Instant)
      if (_memoryCache.containsKey(cacheKey)) {
        final cached = _memoryCache[cacheKey];
        debugPrint('⚡ LocalDatabase: Memory Cache Hit for $key');
        return _parseData<T>(cached, key);
      }

      // 2. LAYER TWO: Hive Cache (Persistent Fallback)
      final box = _getBox(boxName);
      final rawData = box.get(key);
      if (rawData == null) return null;

      // Check version if required
      if (requiredVersion != null) {
        final versionBox = _getBox(boxVersions);
        final currentVersion = versionBox.get(key);
        if (currentVersion != requiredVersion) {
          debugPrint('⚠️ LocalDatabase: Version mismatch for $key (Expected $requiredVersion, Got $currentVersion)');
          return null;
        }
      }

      // Populate memory cache for next time
      _memoryCache[cacheKey] = rawData;
      
      return _parseData<T>(rawData, key);
    } catch (e) {
      debugPrint('❌ LocalDatabase.get error (Key: $key): $e');
      return null;
    }
  }

  /// Shared parsing logic — uses runtime data-type checks to survive Flutter Web minification.
  /// NOTE: T== comparisons for generic types (List<Map<String,dynamic>>) fail on minified builds.
  T? _parseData<T>(dynamic data, String key) {
    try {
      if (data == null) return null;

      // Use data-instance checks instead of T== (T== breaks on minified Flutter Web)
      if (data is Iterable && data is! String) {
        // Always deep-normalize lists coming from Hive (they may be ReadOnlyList<dynamic>)
        final asList = SafeParser.safeMapList(data);
        try { return asList as T; } catch (_) {}
        // Fallback: try as plain List<dynamic>
        try { return data.toList() as T; } catch (_) {}
      }
      if (data is Map) {
        final asMap = SafeParser.safeMap(data);
        try { return asMap as T; } catch (_) {}
      }

      // Primitive types
      if (data is int)    { try { return data as T; } catch (_) { return SafeParser.toInt(data) as T?; } }
      if (data is double) { try { return data as T; } catch (_) { return SafeParser.toDouble(data) as T?; } }
      if (data is bool)   { try { return data as T; } catch (_) { return SafeParser.toBool(data) as T?; } }
      if (data is String) { try { return data as T; } catch (_) { return SafeParser.toStringSafe(data) as T?; } }

      return data as T?;
    } catch (e) {
      debugPrint('❌ LocalDatabase.parse error for $key: $e');
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

  /// Clear all boxes.
  Future<void> clearAll() async {
    try {
      await init();
      await _getBox(boxGeneral).clear();
      await _getBox(boxMetadata).clear();
      debugPrint('🧹 LocalDatabase: All boxes cleared');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error clearing all boxes: $e');
    }
  }

  /// Clears specific items or the entire box
  Future<void> clear({String? key, String? boxName}) async {
    try {
      final box = _getBox(boxName);
      if (key != null) {
        await box.delete(key);
        final metaBox = _getBox(boxMetadata);
        await metaBox.delete('${key}_timestamp');
      } else {
        // If no key is provided, clear all boxes
        await LocalDatabase().clearAll();
      }
      debugPrint('🗑️ LocalDatabase: ${key != null ? 'Item $key cleared' : 'Box ${boxName ?? boxGeneral} cleared'}');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error clearing data: $e');
    }
  }

  /// Check if data is expired based on TTL
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

  /// REFACTORED: Implementation of "Cache-First, Background-Sync" pattern
  /// Returns cached data IMMEDIATELY and triggers fetch in background.
  /// If no cache exists, it waits for fetcher.
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

      // Requirement: Show cached content instantly
      if (cachedData != null) {
        // If expired or forceRefresh, trigger background update but return cached immediately
        if (expired || forceRefresh) {
          debugPrint('🕰️ LocalDatabase Hit (Stale/Force): $key - Fetching new data in background');
          _backgroundUpdate(key, fetcher, boxName);
        }
        return cachedData;
      }

      // If no cached data, fetch normally and await
      debugPrint('🌐 No cache for $key: Fetching from Supabase...');
      final fetchedData = await fetcher();
      await set(key, fetchedData, boxName: boxName);
      return fetchedData;
    } catch (e) {
      debugPrint('❌ Fetch error for $key: $e');
      // Final fallback if fetch failed and we have even older cache
      final lastResort = get<T>(key, boxName: boxName);
      if (lastResort != null) return lastResort;
      
      // If absolutely nothing, try fetcher one last time (letting exception bubble up if it fails again)
      return await fetcher();
    }
  }

  Future<void> _backgroundUpdate<T>(String key, Future<T> Function() fetcher, String? boxName) async {
    try {
      final newData = await fetcher();
      await set(key, newData, boxName: boxName);
      debugPrint('📡 Background update completed for $key');
    } catch (e) {
      debugPrint('⚠️ Background update failed for $key (silently ignoring): $e');
    }
  }
}

