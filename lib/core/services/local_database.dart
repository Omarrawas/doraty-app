import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Database service that uses Hive as the single source of truth for offline/cache data
class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  // Box Names
  static const String _mainBox = 'app_local_database';
  
  late Box<Map> _box;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<Map>(_mainBox);
      _initialized = true;
      debugPrint('📦 LocalDatabase initialized successfully');
    } catch (e) {
      debugPrint('🚨 Failed to initialize LocalDatabase: $e');
      // Fallback or retry logic if needed
      _initialized = false;
    }
  }

  /// Check if data should be refreshed
  bool _isDataStale(int timestamp, Duration maxAge) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) > maxAge.inMilliseconds;
  }

  /// Set data directly
  Future<void> set(String key, dynamic data) async {
    if (!_initialized) return;
    try {
      await _box.put(key, {
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      debugPrint('✅ LocalDatabase: Saved $key');
    } catch (e) {
      debugPrint('❌ LocalDatabase Error setting $key: $e');
    }
  }

  /// Get data directly
  dynamic get(String key) {
    if (!_initialized) return null;
    final entry = _box.get(key);
    if (entry != null) {
      return _safeCast(entry['data']);
    }
    return null;
  }
  
  /// Delete data
  Future<void> remove(String key) async {
    if (!_initialized) return;
    await _box.delete(key);
  }

  /// Clear all local data
  Future<void> clear() async {
    if (!_initialized) return;
    await _box.clear();
  }

  /// Core function: Gets data from local DB if valid, otherwise fetches from Supabase
  /// - `key`: Unique identifier for the data
  /// - `fetcher`: The function to fetch data from Supabase
  /// - `maxAge`: How long the local data is considered fresh
  /// - `forceRefresh`: Ignore local data and fetch from Supabase immediately
  static Future<T> localFirst<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration maxAge = const Duration(minutes: 30),
    bool forceRefresh = false,
  }) async {
    final db = LocalDatabase();
    
    // Safety check if not initialized
    if (!db._initialized) {
      debugPrint('⚠️ LocalDatabase not initialized, fetching directly: $key');
      return await fetcher();
    }

    try {
      final entry = db._box.get(key);
      
      if (!forceRefresh && entry != null) {
        final timestamp = entry['timestamp'] as int?;
        final data = entry['data'];
        
        if (timestamp != null && data != null) {
          final isStale = db._isDataStale(timestamp, maxAge);
          
          if (!isStale) {
            debugPrint('⚡ LocalDatabase Hit (Fresh): $key');
            return _safeCast<T>(data);
          } else {
            debugPrint('🕰️ LocalDatabase Hit (Stale): $key - Fetching new data in background');
            // Data is stale, return local data immediately, but fetch new data in background
            _backgroundFetch(key, fetcher);
            return _safeCast<T>(data);
          }
        }
      }

      // If we reach here, we either forced refresh, or there is no local data
      debugPrint('🌐 Fetching from Supabase: $key');
      final fetchedData = await fetcher();
      
      // Save for next time
      await db.set(key, fetchedData);
      
      return fetchedData;
      
    } catch (e) {
      debugPrint('❌ Fetch error for $key: $e');
      
      // If fetch fails, try to return stale local data as a fallback
      final entry = db._box.get(key);
      if (entry != null && entry['data'] != null) {
        debugPrint('⚠️ Network failed, using stale local data for: $key');
        return _safeCast<T>(entry['data']);
      }
      
      rethrow;
    }
  }

  static Future<void> _backgroundFetch<T>(String key, Future<T> Function() fetcher) async {
    try {
      final data = await fetcher();
      await LocalDatabase().set(key, data);
      debugPrint('🔄 Background update complete for: $key');
    } catch (e) {
      debugPrint('❌ Background update failed for $key: $e');
    }
  }

  static T _safeCast<T>(dynamic data) {
    if (data == null) return null as T;

    // 1. Direct type match - works for basic types
    if (data is T) return data;

    // 2. Numeric handling
    if (data is num) {
      final typeStr = T.toString().toLowerCase();
      if (typeStr.contains('double')) return data.toDouble() as T;
      if (typeStr.contains('int')) return data.toInt() as T;
    }

    // 3. Collection conversion and casting (The major Web issue)
    if (data is Iterable) {
      // First, deep convert elements (recursive)
      final List<dynamic> baseList = data.map((e) => _deepConvert(e)).toList();
      
      // Now, try to satisfy T by increasing specificity of the List container
      // This is necessary because List<dynamic> cannot be cast to List<Map<...>>
      
      // Step A: Attempt direct cast of base list
      try { return baseList as T; } catch (_) {}
      
      // Step B: Attempt cast to List<Map<String, dynamic>>
      try {
        final mapList = List<Map<String, dynamic>>.from(
          baseList.where((e) => e is Map).map((e) => Map<String, dynamic>.from(e as Map))
        );
        return mapList as T;
      } catch (_) {}

      // Step C: Attempt cast to List<String>
      try {
        final stringList = List<String>.from(baseList.map((e) => e.toString()));
        return stringList as T;
      } catch (_) {}

      // Step D: Attempt cast to List<dynamic> (most generic)
      try {
        return List<dynamic>.from(baseList) as T;
      } catch (_) {}
    }

    if (data is Map) {
      final convertedMap = _deepConvert(data);
      try { return convertedMap as T; } catch (_) {}
      try { return Map<String, dynamic>.from(convertedMap) as T; } catch (_) {}
    }

    // 4. Final Fallback
    try {
      return data as T;
    } catch (e) {
      debugPrint('⚠️ LocalDatabase: SafeCast failed for $T. Returning converted as dynamic.');
      try {
        return _deepConvert(data) as T;
      } catch (_) {
        return data as T; // Will likely throw but we've tried everything
      }
    }
  }

  /// Deeply converts Hive data to standard Dart types (Map<String, dynamic>, List, etc.)
  static dynamic _deepConvert(dynamic input) {
    if (input == null) return null;

    if (input is Map) {
      // Hive often returns Map<dynamic, dynamic>
      final Map<String, dynamic> result = {};
      input.forEach((key, value) {
        result[key.toString()] = _deepConvert(value);
      });
      return result;
    } else if (input is Iterable) {
      return input.map((e) => _deepConvert(e)).toList();
    }
    
    // Basic types (String, num, bool) return as is
    return input;
  }
}
