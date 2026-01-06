/// DEPRECATED: This file is no longer used.
/// The project now uses SimpleCacheService (lib/admin/services/simple_cache_service.dart)
/// which properly implements SharedPreferences caching for web compatibility.
///
/// This stub exists only to prevent import errors if any old references exist.
class CacheService {
  static const String _reportsKey = 'cached_reports';
  static const String _notificationsKey = 'cached_notifications';
  static const String _activitiesKey = 'cached_activities';
  static const String _statisticsKey = 'cached_statistics';
  
  // Cache duration before data is considered stale (in minutes)
  static const int _cacheDurationMinutes = 30; // Increased to 30 minutes
  
  static SharedPreferences? _prefs;
  
  /// Initialize SharedPreferences
  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Check what's in cache
      final reportsCache = _prefs?.getString(_reportsKey);
      final notificationsCache = _prefs?.getString(_notificationsKey);
      final activitiesCache = _prefs?.getString(_activitiesKey);
      
      print('✅ Cache service initialized');
      print('📦 Reports cache: ${reportsCache != null ? 'EXISTS' : 'EMPTY'}');
      print('📦 Notifications cache: ${notificationsCache != null ? 'EXISTS' : 'EMPTY'}');
      print('📦 Activities cache: ${activitiesCache != null ? 'EXISTS' : 'EMPTY'}');
      
      if (reportsCache != null) {
        try {
          final decoded = jsonDecode(reportsCache) as Map<String, dynamic>;
          final timestamp = decoded['timestamp'] as int?;
          if (timestamp != null) {
            final age = DateTime.now().millisecondsSinceEpoch - timestamp;
            print('📅 Reports cache age: ${(age / 60000).toStringAsFixed(1)} minutes');
          }
        } catch (e) {
          print('⚠️ Error reading cache metadata: $e');
        }
      }
    } catch (e) {
      print('❌ Error initializing cache service: $e');
      rethrow;
    }
  }
  
  /// Clear all caches (for logout or force refresh)
  static Future<void> clearAll() async {
    try {
      await Hive.box(_reportsBox).clear();
      await Hive.box(_notificationsBox).clear();
      await Hive.box(_activitiesBox).clear();
      await Hive.box(_statisticsBox).clear();
      await Hive.box(_metadataBox).clear();
      print('🧹 All caches cleared');
    } catch (e) {
      print('❌ Error clearing cache: $e');
    }
  }
  
  /// Check if cache is still valid based on timestamp
  static bool _isCacheValid(String key) {
    try {
      final metadata = Hive.box(_metadataBox);
      final timestamp = metadata.get('${key}_timestamp') as int?;
      
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(cacheTime).inMinutes;
      
      return difference < _cacheDurationMinutes;
    } catch (e) {
      return false;
    }
  }
  
  /// Update cache timestamp
  static Future<void> _updateCacheTimestamp(String key) async {
    try {
      final metadata = Hive.box(_metadataBox);
      await metadata.put('${key}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error updating cache timestamp: $e');
    }
  }
  
  /// Get last known Firestore document timestamp for incremental sync
  static DateTime? getLastSyncTime(String collectionName) {
    try {
      final metadata = Hive.box(_metadataBox);
      final timestamp = metadata.get('${collectionName}_last_sync') as int?;
      return timestamp != null 
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null;
    } catch (e) {
      return null;
    }
  }
  
  /// Update last sync timestamp
  static Future<void> updateLastSyncTime(String collectionName, DateTime time) async {
    try {
      final metadata = Hive.box(_metadataBox);
      await metadata.put('${collectionName}_last_sync', time.millisecondsSinceEpoch);
    } catch (e) {
      print('Error updating last sync time: $e');
    }
  }
  
  // ============ REPORTS CACHE ============
  
  /// Cache reports list
  static Future<void> cacheReports(List<QueryDocumentSnapshot> docs) async {
    try {
      final box = Hive.box(_reportsBox);
      
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        // Convert Timestamp objects to milliseconds for storage
        final serializedData = _serializeFirestoreData(data);
        await box.put(doc.id, jsonEncode(serializedData));
      }
      
      await _updateCacheTimestamp('reports');
      print('💾 Cached ${docs.length} reports');
    } catch (e) {
      print('Error caching reports: $e');
    }
  }
  
  /// Get cached reports
  static List<Map<String, dynamic>>? getCachedReports() {
    try {
      if (!_isCacheValid('reports')) {
        print('⚠️ Reports cache is stale');
        return null;
      }
      
      final box = Hive.box(_reportsBox);
      if (box.isEmpty) return null;
      
      final reports = <Map<String, dynamic>>[];
      for (var key in box.keys) {
        final jsonData = box.get(key) as String?;
        if (jsonData != null) {
          final data = jsonDecode(jsonData) as Map<String, dynamic>;
          data['id'] = key; // Add document ID
          reports.add(_deserializeFirestoreData(data));
        }
      }
      
      print('✅ Loaded ${reports.length} reports from cache');
      return reports;
    } catch (e) {
      print('Error getting cached reports: $e');
      return null;
    }
  }
  
  /// Cache single report (for detail screen)
  static Future<void> cacheReport(String id, Map<String, dynamic> data) async {
    try {
      final box = Hive.box(_reportsBox);
      final serializedData = _serializeFirestoreData(data);
      await box.put(id, jsonEncode(serializedData));
    } catch (e) {
      print('Error caching report: $e');
    }
  }
  
  /// Get single cached report
  static Map<String, dynamic>? getCachedReport(String id) {
    try {
      final box = Hive.box(_reportsBox);
      final jsonData = box.get(id) as String?;
      if (jsonData != null) {
        final data = jsonDecode(jsonData) as Map<String, dynamic>;
        return _deserializeFirestoreData(data);
      }
    } catch (e) {
      print('Error getting cached report: $e');
    }
    return null;
  }
  
  // ============ NOTIFICATIONS CACHE ============
  
  /// Cache notifications
  static Future<void> cacheNotifications(List<QueryDocumentSnapshot> docs) async {
    try {
      final box = Hive.box(_notificationsBox);
      
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final serializedData = _serializeFirestoreData(data);
        await box.put(doc.id, jsonEncode(serializedData));
      }
      
      await _updateCacheTimestamp('notifications');
      print('💾 Cached ${docs.length} notifications');
    } catch (e) {
      print('Error caching notifications: $e');
    }
  }
  
  /// Get cached notifications
  static List<Map<String, dynamic>>? getCachedNotifications() {
    try {
      if (!_isCacheValid('notifications')) {
        print('⚠️ Notifications cache is stale');
        return null;
      }
      
      final box = Hive.box(_notificationsBox);
      if (box.isEmpty) return null;
      
      final notifications = <Map<String, dynamic>>[];
      for (var key in box.keys) {
        final jsonData = box.get(key) as String?;
        if (jsonData != null) {
          final data = jsonDecode(jsonData) as Map<String, dynamic>;
          data['id'] = key;
          notifications.add(_deserializeFirestoreData(data));
        }
      }
      
      // Sort by createdAt (most recent first)
      notifications.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      print('✅ Loaded ${notifications.length} notifications from cache');
      return notifications;
    } catch (e) {
      print('Error getting cached notifications: $e');
      return null;
    }
  }
  
  // ============ ACTIVITIES CACHE ============
  
  /// Cache activities
  static Future<void> cacheActivities(List<QueryDocumentSnapshot> docs) async {
    try {
      final box = Hive.box(_activitiesBox);
      
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final serializedData = _serializeFirestoreData(data);
        await box.put(doc.id, jsonEncode(serializedData));
      }
      
      await _updateCacheTimestamp('activities');
      print('💾 Cached ${docs.length} activities');
    } catch (e) {
      print('Error caching activities: $e');
    }
  }
  
  /// Get cached activities
  static List<Map<String, dynamic>>? getCachedActivities() {
    try {
      if (!_isCacheValid('activities')) {
        print('⚠️ Activities cache is stale');
        return null;
      }
      
      final box = Hive.box(_activitiesBox);
      if (box.isEmpty) return null;
      
      final activities = <Map<String, dynamic>>[];
      for (var key in box.keys) {
        final jsonData = box.get(key) as String?;
        if (jsonData != null) {
          final data = jsonDecode(jsonData) as Map<String, dynamic>;
          data['id'] = key;
          activities.add(_deserializeFirestoreData(data));
        }
      }
      
      // Sort by timestamp (most recent first)
      activities.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime);
      });
      
      print('✅ Loaded ${activities.length} activities from cache');
      return activities;
    } catch (e) {
      print('Error getting cached activities: $e');
      return null;
    }
  }
  
  // ============ STATISTICS CACHE ============
  
  /// Cache statistics
  static Future<void> cacheStatistics(Map<String, int> stats) async {
    try {
      final box = Hive.box(_statisticsBox);
      await box.put('stats', jsonEncode(stats));
      await _updateCacheTimestamp('statistics');
      print('💾 Cached statistics');
    } catch (e) {
      print('Error caching statistics: $e');
    }
  }
  
  /// Get cached statistics
  static Map<String, int>? getCachedStatistics() {
    try {
      if (!_isCacheValid('statistics')) {
        print('⚠️ Statistics cache is stale');
        return null;
      }
      
      final box = Hive.box(_statisticsBox);
      final jsonData = box.get('stats') as String?;
      if (jsonData != null) {
        final data = jsonDecode(jsonData) as Map<String, dynamic>;
        print('✅ Loaded statistics from cache');
        return data.map((key, value) => MapEntry(key, value as int));
      }
    } catch (e) {
      print('Error getting cached statistics: $e');
    }
    return null;
  }
  
  // ============ HELPER METHODS ============
  
  /// Serialize Firestore data (convert Timestamps to milliseconds)
  static Map<String, dynamic> _serializeFirestoreData(Map<String, dynamic> data) {
    final serialized = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Timestamp) {
        serialized[key] = {
          '_type': 'Timestamp',
          '_seconds': value.seconds,
          '_nanoseconds': value.nanoseconds,
        };
      } else if (value is Map) {
        serialized[key] = _serializeFirestoreData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        serialized[key] = value.map((item) {
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
  
  /// Deserialize Firestore data (convert milliseconds back to Timestamps)
  static Map<String, dynamic> _deserializeFirestoreData(Map<String, dynamic> data) {
    final deserialized = <String, dynamic>{};
    
    data.forEach((key, value) {
      if (value is Map && value['_type'] == 'Timestamp') {
        deserialized[key] = Timestamp(
          value['_seconds'] as int,
          value['_nanoseconds'] as int,
        );
      } else if (value is Map) {
        deserialized[key] = _deserializeFirestoreData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        deserialized[key] = value.map((item) {
          if (item is Map) {
            return _deserializeFirestoreData(Map<String, dynamic>.from(item));
          }
          return item;
        }).toList();
      } else {
        deserialized[key] = value;
      }
    });
    
    return deserialized;
  }
  
  /// Invalidate specific cache
  static Future<void> invalidateCache(String cacheName) async {
    try {
      final metadata = Hive.box(_metadataBox);
      await metadata.delete('${cacheName}_timestamp');
      print('🔄 Invalidated $cacheName cache');
    } catch (e) {
      print('Error invalidating cache: $e');
    }
  }
}
