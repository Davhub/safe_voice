import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/simple_cache_service.dart';

/// Smart data fetching service that loads from cache first, then syncs with Firestore
/// This eliminates redundant fetching on page reload
class CachedDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream controllers for reactive updates
  static final _reportsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _notificationsController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _activitiesController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  static final _statisticsController =
      StreamController<Map<String, int>>.broadcast();

  // Track active listeners to prevent unnecessary queries
  static StreamSubscription? _reportsSubscription;
  static StreamSubscription? _notificationsSubscription;
  static StreamSubscription? _activitiesSubscription;

  /// Get reports stream with caching
  /// 1. Immediately return cached data if available
  /// 2. Listen to Firestore for updates
  /// 3. Update cache when new data arrives
  static Stream<List<Map<String, dynamic>>> getReportsStream({
    String? status,
    int limit = 100,
  }) {
    print('🔄 getReportsStream called');

    // First, try to load from cache
    final cachedReports = SimpleCacheService.getCachedReports();
    if (cachedReports != null && cachedReports.isNotEmpty) {
      // Immediately emit cached data
      _reportsController.add(cachedReports);
      print('⚡ Emitted ${cachedReports.length} reports from cache INSTANTLY');
    } else {
      print('📭 No cached reports available, will fetch from Firestore');
    }

    // Cancel previous subscription to avoid duplicates
    _reportsSubscription?.cancel();

    // Then subscribe to Firestore for real-time updates
    Query query = _firestore.collection('reports');

    // Apply filters
    if (status != null && status.isNotEmpty) {
      query = query.where('status', isEqualTo: status);
    }

    query = query.orderBy('submittedAt', descending: true).limit(limit);

    _reportsSubscription = query.snapshots().listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          // Convert to maps
          final reports =
              snapshot.docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['id'] = doc.id;
                return data;
              }).toList();

          // Update cache
          SimpleCacheService.cacheReports(reports);

          // Emit to stream
          _reportsController.add(reports);
          print(
            '🔄 Updated ${reports.length} reports from Firestore and cached',
          );
        }
      },
      onError: (error) {
        print('❌ Reports stream error: $error');
        _reportsController.addError(error);
      },
    );

    return _reportsController.stream;
  }

  /// Get notifications stream with caching
  static Stream<List<Map<String, dynamic>>> getNotificationsStream() {
    print('🔄 getNotificationsStream called');

    // Load from cache first
    final cachedNotifications = SimpleCacheService.getCachedNotifications();
    if (cachedNotifications != null && cachedNotifications.isNotEmpty) {
      _notificationsController.add(cachedNotifications);
      print(
        '⚡ Emitted ${cachedNotifications.length} notifications from cache INSTANTLY',
      );
    } else {
      print('📭 No cached notifications available');
    }

    // Cancel previous subscription
    _notificationsSubscription?.cancel();

    // Subscribe to Firestore updates
    _notificationsSubscription = _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              // Convert and emit
              final notifications =
                  snapshot.docs.map((doc) {
                    final data = doc.data();
                    data['id'] = doc.id;
                    return data;
                  }).toList();

              // Update cache
              SimpleCacheService.cacheNotifications(notifications);

              _notificationsController.add(notifications);
              print(
                '🔄 Updated ${notifications.length} notifications from Firestore and cached',
              );
            }
          },
          onError: (error) {
            print('❌ Notifications stream error: $error');
            _notificationsController.addError(error);
          },
        );

    return _notificationsController.stream;
  }

  /// Get activities stream with caching
  static Stream<List<Map<String, dynamic>>> getActivitiesStream({
    int limit = 10,
  }) {
    print('🔄 getActivitiesStream called');

    // Load from cache first
    final cachedActivities = SimpleCacheService.getCachedActivities();
    if (cachedActivities != null && cachedActivities.isNotEmpty) {
      _activitiesController.add(cachedActivities.take(limit).toList());
      print(
        '⚡ Emitted ${cachedActivities.take(limit).length} activities from cache INSTANTLY',
      );
    } else {
      print('📭 No cached activities available');
    }

    // Cancel previous subscription
    _activitiesSubscription?.cancel();

    // Subscribe to Firestore updates
    _activitiesSubscription = _firestore
        .collection('admin_activities')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.docs.isNotEmpty) {
              // Convert and emit
              final activities =
                  snapshot.docs.map((doc) {
                    final data = doc.data();
                    data['id'] = doc.id;
                    return data;
                  }).toList();

              // Update cache
              SimpleCacheService.cacheActivities(activities);

              _activitiesController.add(activities);
              print(
                '🔄 Updated ${activities.length} activities from Firestore and cached',
              );
            }
          },
          onError: (error) {
            print('❌ Activities stream error: $error');
            _activitiesController.addError(error);
          },
        );

    return _activitiesController.stream;
  }

  /// Get statistics with caching
  static Stream<Map<String, int>> getStatisticsStream() {
    // Load from cache first
    final cachedStats = SimpleCacheService.getCachedStatistics();
    if (cachedStats != null) {
      _statisticsController.add(cachedStats);
      print('⚡ Loaded statistics from cache INSTANTLY');
    }

    // Then fetch fresh statistics (use Future, not stream for count queries)
    _fetchFreshStatistics();

    // Set up periodic refresh (every 30 seconds)
    Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchFreshStatistics();
    });

    return _statisticsController.stream;
  }

  /// Fetch fresh statistics from Firestore
  static Future<void> _fetchFreshStatistics() async {
    try {
      final totalCount = await _firestore.collection('reports').count().get();
      final submittedCount =
          await _firestore
              .collection('reports')
              .where('status', isEqualTo: 'submitted')
              .count()
              .get();
      final underReviewCount =
          await _firestore
              .collection('reports')
              .where('status', isEqualTo: 'under_review')
              .count()
              .get();
      final resolvedCount =
          await _firestore
              .collection('reports')
              .where('status', isEqualTo: 'resolved')
              .count()
              .get();

      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      final weekStart = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      final weekStartTimestamp = Timestamp.fromDate(weekStart);

      final thisWeekCount =
          await _firestore
              .collection('reports')
              .where('submittedAt', isGreaterThan: weekStartTimestamp)
              .count()
              .get();

      final stats = {
        'total': totalCount.count ?? 0,
        'submitted': submittedCount.count ?? 0,
        'pending': (submittedCount.count ?? 0) + (underReviewCount.count ?? 0),
        'under_review': underReviewCount.count ?? 0,
        'resolved': resolvedCount.count ?? 0,
        'thisWeek': thisWeekCount.count ?? 0,
      };

      // Update cache and emit
      await SimpleCacheService.cacheStatistics(stats);
      _statisticsController.add(stats);
      print('🔄 Updated statistics from Firestore and cached');
    } catch (e) {
      print('❌ Error fetching statistics: $e');
      _statisticsController.addError(e);
    }
  }

  /// Get unread notification count (always fetch fresh for accuracy)
  static Stream<int> getUnreadNotificationCountStream() {
    return _firestore
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get single report (directly from Firestore - not cached individually)
  static Future<Map<String, dynamic>?> getReport(String reportId) async {
    try {
      final doc = await _firestore.collection('reports').doc(reportId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return data;
      }
    } catch (e) {
      print('❌ Error fetching report: $e');
    }
    return null;
  }

  /// Force refresh - clear cache and refetch
  static Future<void> forceRefresh() async {
    print('🔄 Force refreshing all data...');
    await SimpleCacheService.clearAll();

    // Re-initialize streams to trigger fresh fetches
    _reportsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _activitiesSubscription?.cancel();
  }

  /// Cleanup when app closes
  static void dispose() {
    _reportsSubscription?.cancel();
    _notificationsSubscription?.cancel();
    _activitiesSubscription?.cancel();

    _reportsController.close();
    _notificationsController.close();
    _activitiesController.close();
    _statisticsController.close();
  }
}
