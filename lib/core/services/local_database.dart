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

  /// Helper for robust type casting (especially for Web minified builds and JSON from Hive)
  static T _safeCast<T>(dynamic data) {
    try {
      if (data is T) return data;

      final typeStr = T.toString();

      if (typeStr.contains('List<Map<String, dynamic>>')) {
        if (data is List) {
          return data.map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            return item;
          }).toList().cast<Map<String, dynamic>>() as T;
        }
      }

      if (typeStr.contains('Map<String, dynamic>')) {
        if (data is Map) {
          return Map<String, dynamic>.from(data) as T;
        }
      }

      if (typeStr.contains('List<String>') || typeStr.contains('Set<String>')) {
        if (data is Iterable) {
          final list = data.map((e) => e.toString()).toList();
          if (typeStr.contains('Set')) return list.toSet() as T;
          return list as T;
        }
      }

      return data as T;
    } catch (e) {
      debugPrint('🚨 SafeCast failed for type $T: $e');
      return data as T;
    }
  }
}
