import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Simple, reliable caching service using SharedPreferences (localStorage on web)
/// This persists across page reloads and is much more reliable than Hive on web
class SimpleCacheService {
  // Cache keys
  static const String _reportsKey = 'cached_reports_v1';
  static const String _reportsTimestampKey = 'cached_reports_timestamp';
  static const String _notificationsKey = 'cached_notifications_v1';
  static const String _notificationsTimestampKey =
      'cached_notifications_timestamp';
  static const String _activitiesKey = 'cached_activities_v1';
  static const String _activitiesTimestampKey = 'cached_activities_timestamp';
  static const String _statisticsKey = 'cached_statistics_v1';
  static const String _statisticsTimestampKey = 'cached_statistics_timestamp';

  // Cache duration (30 minutes)
  static const int _cacheDurationMinutes = 30;

  static SharedPreferences? _prefs;

  /// Initialize SharedPreferences
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      print('✅ SimpleCacheService initialized');

      // Log cache status
      _logCacheStatus();
    } catch (e) {
      print('❌ Error initializing SimpleCacheService: $e');
      rethrow;
    }
  }

  /// Log current cache status
  static void _logCacheStatus() {
    final reportsCount = _getCachedCount(_reportsKey);
    final notificationsCount = _getCachedCount(_notificationsKey);
    final activitiesCount = _getCachedCount(_activitiesKey);

    print('📦 Cache Status:');
    print(
      '  - Reports: ${reportsCount > 0 ? '$reportsCount items' : 'EMPTY'} ${_getCacheAge(_reportsTimestampKey)}',
    );
    print(
      '  - Notifications: ${notificationsCount > 0 ? '$notificationsCount items' : 'EMPTY'} ${_getCacheAge(_notificationsTimestampKey)}',
    );
    print(
      '  - Activities: ${activitiesCount > 0 ? '$activitiesCount items' : 'EMPTY'} ${_getCacheAge(_activitiesTimestampKey)}',
    );
  }

  static int _getCachedCount(String key) {
    try {
      final data = _prefs?.getString(key);
      if (data == null) return 0;
      final decoded = jsonDecode(data) as List;
      return decoded.length;
    } catch (e) {
      return 0;
    }
  }

  static String _getCacheAge(String timestampKey) {
    try {
      final timestamp = _prefs?.getInt(timestampKey);
      if (timestamp == null) return '';
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final minutes = (age / 60000).round();
      return '(${minutes}m old)';
    } catch (e) {
      return '';
    }
  }

  /// Check if cache is still valid
  static bool _isCacheValid(String timestampKey) {
    try {
      final timestamp = _prefs?.getInt(timestampKey);
      if (timestamp == null) {
        print('⚠️ No timestamp found for $timestampKey');
        return false;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final ageMinutes = now.difference(cacheTime).inMinutes;

      final isValid = ageMinutes < _cacheDurationMinutes;
      print('🕐 Cache age: $ageMinutes minutes, valid: $isValid');
      return isValid;
    } catch (e) {
      print('❌ Error checking cache validity: $e');
      return false;
    }
  }

  /// Update cache timestamp
  static Future<void> _updateCacheTimestamp(String timestampKey) async {
    await _prefs?.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ============ REPORTS CACHE ============

  /// Cache reports list
  static Future<void> cacheReports(List<Map<String, dynamic>> reports) async {
    try {
      // Serialize all reports
      final serialized =
          reports.map((report) => _serializeFirestoreData(report)).toList();

      // Store as JSON string
      final jsonString = jsonEncode(serialized);
      await _prefs?.setString(_reportsKey, jsonString);
      await _updateCacheTimestamp(_reportsTimestampKey);

      print('💾 Cached ${reports.length} reports (${jsonString.length} bytes)');
    } catch (e) {
      print('❌ Error caching reports: $e');
    }
  }

  /// Get cached reports
  static List<Map<String, dynamic>>? getCachedReports() {
    try {
      if (!_isCacheValid(_reportsTimestampKey)) {
        print('⏰ Reports cache expired');
        return null;
      }

      final jsonString = _prefs?.getString(_reportsKey);
      if (jsonString == null) {
        print('📭 No cached reports found');
        return null;
      }

      final decoded = jsonDecode(jsonString) as List;
      final reports =
          decoded
              .map(
                (item) =>
                    _deserializeFirestoreData(Map<String, dynamic>.from(item)),
              )
              .toList();

      print('⚡ Loaded ${reports.length} reports from cache');
      return reports;
    } catch (e) {
      print('❌ Error loading cached reports: $e');
      return null;
    }
  }

  // ============ NOTIFICATIONS CACHE ============

  /// Cache notifications
  static Future<void> cacheNotifications(
    List<Map<String, dynamic>> notifications,
  ) async {
    try {
      final serialized =
          notifications.map((n) => _serializeFirestoreData(n)).toList();
      final jsonString = jsonEncode(serialized);

      await _prefs?.setString(_notificationsKey, jsonString);
      await _updateCacheTimestamp(_notificationsTimestampKey);

      print('💾 Cached ${notifications.length} notifications');
    } catch (e) {
      print('❌ Error caching notifications: $e');
    }
  }

  /// Get cached notifications
  static List<Map<String, dynamic>>? getCachedNotifications() {
    try {
      if (!_isCacheValid(_notificationsTimestampKey)) {
        print('⏰ Notifications cache expired');
        return null;
      }

      final jsonString = _prefs?.getString(_notificationsKey);
      if (jsonString == null) {
        print('📭 No cached notifications found');
        return null;
      }

      final decoded = jsonDecode(jsonString) as List;
      final notifications =
          decoded
              .map(
                (item) =>
                    _deserializeFirestoreData(Map<String, dynamic>.from(item)),
              )
              .toList();

      print('⚡ Loaded ${notifications.length} notifications from cache');
      return notifications;
    } catch (e) {
      print('❌ Error loading cached notifications: $e');
      return null;
    }
  }

  // ============ ACTIVITIES CACHE ============

  /// Cache activities
  static Future<void> cacheActivities(
    List<Map<String, dynamic>> activities,
  ) async {
    try {
      final serialized =
          activities.map((a) => _serializeFirestoreData(a)).toList();
      final jsonString = jsonEncode(serialized);

      await _prefs?.setString(_activitiesKey, jsonString);
      await _updateCacheTimestamp(_activitiesTimestampKey);

      print('💾 Cached ${activities.length} activities');
    } catch (e) {
      print('❌ Error caching activities: $e');
    }
  }

  /// Get cached activities
  static List<Map<String, dynamic>>? getCachedActivities() {
    try {
      if (!_isCacheValid(_activitiesTimestampKey)) {
        print('⏰ Activities cache expired');
        return null;
      }

      final jsonString = _prefs?.getString(_activitiesKey);
      if (jsonString == null) {
        print('📭 No cached activities found');
        return null;
      }

      final decoded = jsonDecode(jsonString) as List;
      final activities =
          decoded
              .map(
                (item) =>
                    _deserializeFirestoreData(Map<String, dynamic>.from(item)),
              )
              .toList();

      print('⚡ Loaded ${activities.length} activities from cache');
      return activities;
    } catch (e) {
      print('❌ Error loading cached activities: $e');
      return null;
    }
  }

  // ============ STATISTICS CACHE ============

  /// Cache statistics
  static Future<void> cacheStatistics(Map<String, int> stats) async {
    try {
      final jsonString = jsonEncode(stats);
      await _prefs?.setString(_statisticsKey, jsonString);
      await _updateCacheTimestamp(_statisticsTimestampKey);

      print('💾 Cached statistics');
    } catch (e) {
      print('❌ Error caching statistics: $e');
    }
  }

  /// Get cached statistics
  static Map<String, int>? getCachedStatistics() {
    try {
      if (!_isCacheValid(_statisticsTimestampKey)) {
        print('⏰ Statistics cache expired');
        return null;
      }

      final jsonString = _prefs?.getString(_statisticsKey);
      if (jsonString == null) {
        print('📭 No cached statistics found');
        return null;
      }

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final stats = decoded.map((key, value) => MapEntry(key, value as int));

      print('⚡ Loaded statistics from cache');
      return stats;
    } catch (e) {
      print('❌ Error loading cached statistics: $e');
      return null;
    }
  }

  // ============ HELPER METHODS ============

  /// Serialize Firestore data (convert Timestamps to JSON-friendly format)
  static Map<String, dynamic> _serializeFirestoreData(
    Map<String, dynamic> data,
  ) {
    final serialized = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        serialized[key] = {
          '_firestore_timestamp': true,
          'seconds': value.seconds,
          'nanoseconds': value.nanoseconds,
        };
      } else if (value is Map) {
        serialized[key] = _serializeFirestoreData(
          Map<String, dynamic>.from(value),
        );
      } else if (value is List) {
        serialized[key] =
            value.map((item) {
              if (item is Map) {
                return _serializeFirestoreData(Map<String, dynamic>.from(item));
              }
              return item;
            }).toList();
      } else {
        serialized[key] = value;
      }
    });

    return serialized;
  }

  /// Deserialize Firestore data (convert JSON back to Timestamps)
  static Map<String, dynamic> _deserializeFirestoreData(
    Map<String, dynamic> data,
  ) {
    final deserialized = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Map && value['_firestore_timestamp'] == true) {
        deserialized[key] = Timestamp(
          value['seconds'] as int,
          value['nanoseconds'] as int,
        );
      } else if (value is Map) {
        deserialized[key] = _deserializeFirestoreData(
          Map<String, dynamic>.from(value),
        );
      } else if (value is List) {
        deserialized[key] =
            value.map((item) {
              if (item is Map) {
                return _deserializeFirestoreData(
                  Map<String, dynamic>.from(item),
                );
              }
              return item;
            }).toList();
      } else {
        deserialized[key] = value;
      }
    });

    return deserialized;
  }

  /// Clear all caches
  static Future<void> clearAll() async {
    try {
      await _prefs?.remove(_reportsKey);
      await _prefs?.remove(_reportsTimestampKey);
      await _prefs?.remove(_notificationsKey);
      await _prefs?.remove(_notificationsTimestampKey);
      await _prefs?.remove(_activitiesKey);
      await _prefs?.remove(_activitiesTimestampKey);
      await _prefs?.remove(_statisticsKey);
      await _prefs?.remove(_statisticsTimestampKey);

      print('🧹 All caches cleared');
    } catch (e) {
      print('❌ Error clearing caches: $e');
    }
  }

  /// Invalidate specific cache
  static Future<void> invalidateCache(String cacheName) async {
    try {
      switch (cacheName) {
        case 'reports':
          await _prefs?.remove(_reportsTimestampKey);
          break;
        case 'notifications':
          await _prefs?.remove(_notificationsTimestampKey);
          break;
        case 'activities':
          await _prefs?.remove(_activitiesTimestampKey);
          break;
        case 'statistics':
          await _prefs?.remove(_statisticsTimestampKey);
          break;
      }
      print('🔄 Invalidated $cacheName cache');
    } catch (e) {
      print('❌ Error invalidating cache: $e');
    }
  }
}
