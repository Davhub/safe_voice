import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Service for managing anonymous, aggregated app usage analytics
///
/// Privacy-First Architecture:
/// - No PII (Personally Identifiable Information) is collected
/// - All data is aggregated at collection time
/// - Location limited to country/state level only
/// - No device identifiers or user tracking
///
/// Data Structure:
/// /analytics/daily/{YYYY-MM-DD}/metrics
/// /analytics/monthly/{YYYY-MM}/metrics
/// /analytics/aggregated/totals (for all-time stats)
class AppUsageAnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time analytics stream for a specific period
  /// Returns a stream that updates automatically when data changes
  static Stream<Map<String, dynamic>> getAnalyticsStream({
    required DateTime startDate,
    required DateTime endDate,
    String period = 'day',
  }) {
    try {
      final dateFormat = period == 'day' ? 'yyyy-MM-dd' : 'yyyy-MM';
      final startKey = DateFormat(dateFormat).format(startDate);
      final endKey = DateFormat(dateFormat).format(endDate);

      // Query the appropriate collection based on period
      final collection = period == 'day' ? 'daily' : 'monthly';

      return _firestore
          .collection('app_usage_analytics')
          .doc(collection)
          .collection('metrics')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: startKey)
          .where(FieldPath.documentId, isLessThanOrEqualTo: endKey)
          .snapshots()
          .map((snapshot) => _aggregateMetrics(snapshot.docs));
    } catch (e) {
      print('❌ Error getting analytics stream: $e');
      return Stream.value(_getEmptyMetrics());
    }
  }

  /// Aggregate metrics from multiple documents
  static Map<String, dynamic> _aggregateMetrics(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (docs.isEmpty) {
      return _getEmptyMetrics();
    }

    // Initialize aggregation counters
    int totalActiveUsers = 0;
    int totalAppOpens = 0;
    Map<String, int> screenVisits = {};
    Map<String, int> deviceTypes = {};
    Map<String, int> locations = {};

    // Aggregate data from all documents in the period
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Sum active users (unique per day, so we sum for period)
      totalActiveUsers += (data['activeUsers'] as int?) ?? 0;

      // Sum app opens
      totalAppOpens += (data['appOpens'] as int?) ?? 0;

      // Aggregate screen visits
      final docScreenVisits = data['screenVisits'] as Map<String, dynamic>?;
      if (docScreenVisits != null) {
        docScreenVisits.forEach((screen, count) {
          screenVisits[screen] = (screenVisits[screen] ?? 0) + (count as int);
        });
      }

      // Aggregate device types
      final docDeviceTypes = data['deviceTypes'] as Map<String, dynamic>?;
      if (docDeviceTypes != null) {
        docDeviceTypes.forEach((device, count) {
          deviceTypes[device] = (deviceTypes[device] ?? 0) + (count as int);
        });
      }

      // Aggregate coarse locations (country level only)
      final docLocations = data['coarseLocations'] as Map<String, dynamic>?;
      if (docLocations != null) {
        docLocations.forEach((location, count) {
          locations[location] = (locations[location] ?? 0) + (count as int);
        });
      }
    }

    return {
      'dailyActiveUsers': totalActiveUsers,
      'appOpens': totalAppOpens,
      'screenVisits': screenVisits,
      'deviceTypes': deviceTypes,
      'coarseLocations': locations,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Get empty metrics structure (fallback for no data)
  static Map<String, dynamic> _getEmptyMetrics() {
    return {
      'dailyActiveUsers': 0,
      'appOpens': 0,
      'screenVisits': {
        'reportSubmitted': 0,
        'home': 0,
        'aboutUs': 0,
        'resources': 0,
      },
      'deviceTypes': {'android': 0, 'iOS': 0},
      'coarseLocations': {},
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  /// Increment a metric atomically (called from client app)
  /// This is an example - actual implementation would use Cloud Functions
  /// to ensure proper aggregation without exposing write access to clients
  static Future<void> incrementMetric({
    required String metricType,
    String? screen,
    String? deviceType,
    String? country,
  }) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final thisMonth = DateFormat('yyyy-MM').format(DateTime.now());

      // Update daily metrics
      await _updateDailyMetrics(
        today,
        metricType,
        screen: screen,
        deviceType: deviceType,
        country: country,
      );

      // Update monthly metrics
      await _updateMonthlyMetrics(
        thisMonth,
        metricType,
        screen: screen,
        deviceType: deviceType,
        country: country,
      );
    } catch (e) {
      print('❌ Error incrementing metric: $e');
    }
  }

  /// Update daily metrics document
  static Future<void> _updateDailyMetrics(
    String dateKey,
    String metricType, {
    String? screen,
    String? deviceType,
    String? country,
  }) async {
    final docRef = _firestore
        .collection('app_usage_analytics')
        .doc('daily')
        .collection('metrics')
        .doc(dateKey);

    // Use FieldValue.increment for atomic updates
    Map<String, dynamic> updates = {};

    switch (metricType) {
      case 'activeUser':
        updates['activeUsers'] = FieldValue.increment(1);
        break;
      case 'appOpen':
        updates['appOpens'] = FieldValue.increment(1);
        break;
      case 'screenVisit':
        if (screen != null) {
          updates['screenVisits.$screen'] = FieldValue.increment(1);
        }
        break;
      case 'deviceType':
        if (deviceType != null) {
          updates['deviceTypes.$deviceType'] = FieldValue.increment(1);
        }
        break;
      case 'location':
        if (country != null) {
          updates['coarseLocations.$country'] = FieldValue.increment(1);
        }
        break;
    }

    if (updates.isNotEmpty) {
      await docRef.set({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Update monthly metrics document
  static Future<void> _updateMonthlyMetrics(
    String monthKey,
    String metricType, {
    String? screen,
    String? deviceType,
    String? country,
  }) async {
    final docRef = _firestore
        .collection('app_usage_analytics')
        .doc('monthly')
        .collection('metrics')
        .doc(monthKey);

    // Use same logic as daily
    Map<String, dynamic> updates = {};

    switch (metricType) {
      case 'activeUser':
        updates['activeUsers'] = FieldValue.increment(1);
        break;
      case 'appOpen':
        updates['appOpens'] = FieldValue.increment(1);
        break;
      case 'screenVisit':
        if (screen != null) {
          updates['screenVisits.$screen'] = FieldValue.increment(1);
        }
        break;
      case 'deviceType':
        if (deviceType != null) {
          updates['deviceTypes.$deviceType'] = FieldValue.increment(1);
        }
        break;
      case 'location':
        if (country != null) {
          updates['coarseLocations.$country'] = FieldValue.increment(1);
        }
        break;
    }

    if (updates.isNotEmpty) {
      await docRef.set({
        ...updates,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Get date range based on period selection
  static Map<String, DateTime> getDateRange(String period) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (period) {
      case 'Today':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'Month':
      default:
        startDate = DateTime(now.year, now.month, 1);
        break;
    }

    return {'startDate': startDate, 'endDate': endDate};
  }

  /// Check if analytics data exists for a given period
  static Future<bool> hasAnalyticsData(String period) async {
    try {
      final dateRange = getDateRange(period);
      final dateFormat = period == 'Today' ? 'yyyy-MM-dd' : 'yyyy-MM';
      final startKey = DateFormat(dateFormat).format(dateRange['startDate']!);

      final collection = period == 'Today' ? 'daily' : 'monthly';
      final snapshot =
          await _firestore
              .collection('app_usage_analytics')
              .doc(collection)
              .collection('metrics')
              .doc(startKey)
              .get();

      return snapshot.exists;
    } catch (e) {
      print('❌ Error checking analytics data: $e');
      return false;
    }
  }

  /// Initialize analytics collection structure (run once during setup)
  /// This should be called from an admin script or Cloud Function
  static Future<void> initializeAnalyticsStructure() async {
    try {
      print('🔧 Initializing analytics structure...');

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final thisMonth = DateFormat('yyyy-MM').format(DateTime.now());

      print('📅 Creating daily document for: $today');

      // Create initial daily document
      await _firestore
          .collection('app_usage_analytics')
          .doc('daily')
          .collection('metrics')
          .doc(today)
          .set({
            'activeUsers': 0,
            'appOpens': 0,
            'screenVisits': {
              'reportSubmitted': 0,
              'home': 0,
              'aboutUs': 0,
              'resources': 0,
            },
            'deviceTypes': {'android': 0, 'iOS': 0},
            'coarseLocations': {},
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print('📅 Creating monthly document for: $thisMonth');

      // Create initial monthly document
      await _firestore
          .collection('app_usage_analytics')
          .doc('monthly')
          .collection('metrics')
          .doc(thisMonth)
          .set({
            'activeUsers': 0,
            'appOpens': 0,
            'screenVisits': {
              'reportSubmitted': 0,
              'home': 0,
              'aboutUs': 0,
              'resources': 0,
            },
            'deviceTypes': {'android': 0, 'iOS': 0},
            'coarseLocations': {},
            'createdAt': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      print('✅ App usage analytics structure initialized successfully!');
      print('📍 Collection: app_usage_analytics/daily/metrics/$today');
      print('📍 Collection: app_usage_analytics/monthly/metrics/$thisMonth');
    } catch (e) {
      print('❌ Error initializing analytics structure: $e');
      rethrow; // Re-throw to allow UI to handle error
    }
  }
}
