import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:safe_voice/models/report.dart';

/// Service for tracking and analyzing report data and usage patterns
class AnalyticsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== DAILY TRACKING ====================

  /// Get report count for a specific date
  static Future<int> getDailyReportCount(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot =
          await _firestore
              .collection('reports')
              .where(
                'submittedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where(
                'submittedAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
              )
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error in getDailyReportCount: $e');
      return 0;
    }
  }

  /// Get reports by date with case type breakdown
  static Future<Map<String, dynamic>> getDailyReportDetails(
    DateTime date,
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot =
          await _firestore
              .collection('reports')
              .where(
                'submittedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
              )
              .where(
                'submittedAt',
                isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
              )
              .get();

      int totalCount = snapshot.docs.length;
      Map<String, int> caseTypeCounts = {
        'FGM': 0,
        'SEXUAL_ASSAULT': 0,
        'GBV': 0,
      };
      Map<String, int> statusCounts = {
        'submitted': 0,
        'under_review': 0,
        'resolved': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // Count by case type
        final caseType = data['caseType'] ?? data['case_type'] ?? 'FGM';
        caseTypeCounts[caseType] = (caseTypeCounts[caseType] ?? 0) + 1;

        // Count by status
        final status = data['status'] ?? 'submitted';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return {
        'date': date.toIso8601String(),
        'totalCount': totalCount,
        'caseTypeCounts': caseTypeCounts,
        'statusCounts': statusCounts,
      };
    } catch (e) {
      debugPrint('Error in getDailyReportDetails: $e');
      return {
        'date': date.toIso8601String(),
        'totalCount': 0,
        'caseTypeCounts': {},
        'statusCounts': {},
      };
    }
  }

  // ==================== WEEKLY TRACKING ====================

  /// Get report count for a specific week (starting from weekStart)
  static Future<int> getWeeklyReportCount(DateTime weekStart) async {
    try {
      final startOfWeek = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final snapshot =
          await _firestore
              .collection('reports')
              .where(
                'submittedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
              )
              .where('submittedAt', isLessThan: Timestamp.fromDate(endOfWeek))
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error in getWeeklyReportCount: $e');
      return 0;
    }
  }

  /// Get daily breakdown for a week
  static Future<List<Map<String, dynamic>>> getWeeklyReportBreakdown(
    DateTime weekStart,
  ) async {
    try {
      List<Map<String, dynamic>> weeklyData = [];

      for (int i = 0; i < 7; i++) {
        final currentDay = weekStart.add(Duration(days: i));
        final dailyCount = await getDailyReportCount(currentDay);

        weeklyData.add({
          'date': currentDay.toIso8601String(),
          'dayOfWeek': _getDayName(currentDay.weekday),
          'count': dailyCount,
        });
      }

      return weeklyData;
    } catch (e) {
      debugPrint('Error in getWeeklyReportBreakdown: $e');
      return [];
    }
  }

  // ==================== MONTHLY TRACKING ====================

  /// Get report count for a specific month
  static Future<int> getMonthlyReportCount(int year, int month) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 1);

      final snapshot =
          await _firestore
              .collection('reports')
              .where(
                'submittedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
              )
              .where('submittedAt', isLessThan: Timestamp.fromDate(endOfMonth))
              .count()
              .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error in getMonthlyReportCount: $e');
      return 0;
    }
  }

  /// Get daily breakdown for a month
  static Future<List<Map<String, dynamic>>> getMonthlyReportBreakdown(
    int year,
    int month,
  ) async {
    try {
      List<Map<String, dynamic>> monthlyData = [];
      final daysInMonth = DateTime(year, month + 1, 0).day;

      for (int day = 1; day <= daysInMonth; day++) {
        final currentDay = DateTime(year, month, day);
        final dailyCount = await getDailyReportCount(currentDay);

        monthlyData.add({
          'date': currentDay.toIso8601String(),
          'day': day,
          'count': dailyCount,
        });
      }

      return monthlyData;
    } catch (e) {
      debugPrint('Error in getMonthlyReportBreakdown: $e');
      return [];
    }
  }

  // ==================== CASE TYPE ANALYTICS ====================

  /// Get case type distribution for a date range
  static Future<Map<String, int>> getReportsByCaseType({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('reports');

      if (startDate != null) {
        query = query.where(
          'submittedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'submittedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      Map<String, int> caseTypeCounts = {
        'FGM': 0,
        'SEXUAL_ASSAULT': 0,
        'GBV': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final caseType = data['caseType'] ?? data['case_type'] ?? 'FGM';
        caseTypeCounts[caseType] = (caseTypeCounts[caseType] ?? 0) + 1;
      }

      return caseTypeCounts;
    } catch (e) {
      debugPrint('Error in getReportsByCaseType: $e');
      return {'FGM': 0, 'SEXUAL_ASSAULT': 0, 'GBV': 0};
    }
  }

  /// Get case type distribution as percentages
  static Future<Map<String, double>> getCaseTypeDistribution({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final counts = await getReportsByCaseType(
        startDate: startDate,
        endDate: endDate,
      );

      final total = counts.values.fold<int>(0, (sum, count) => sum + count);

      if (total == 0) {
        return {'FGM': 0.0, 'SEXUAL_ASSAULT': 0.0, 'GBV': 0.0};
      }

      return {
        'FGM': (counts['FGM']! / total) * 100,
        'SEXUAL_ASSAULT': (counts['SEXUAL_ASSAULT']! / total) * 100,
        'GBV': (counts['GBV']! / total) * 100,
      };
    } catch (e) {
      debugPrint('Error in getCaseTypeDistribution: $e');
      return {'FGM': 0.0, 'SEXUAL_ASSAULT': 0.0, 'GBV': 0.0};
    }
  }

  // ==================== LOCATION ANALYTICS ====================

  /// Get top reporting locations with case counts
  static Future<List<Map<String, dynamic>>> getTopReportingLocations({
    int limit = 10,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('reports');

      if (startDate != null) {
        query = query.where(
          'submittedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'submittedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      // Count reports by location
      Map<String, int> locationCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final location = data['location'] ?? 'Unknown';

        if (location.isNotEmpty && location != 'Unknown') {
          locationCounts[location] = (locationCounts[location] ?? 0) + 1;
        }
      }

      // Sort by count and return top locations
      final sortedLocations =
          locationCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      return sortedLocations
          .take(limit)
          .map((entry) => {'location': entry.key, 'count': entry.value})
          .toList();
    } catch (e) {
      debugPrint('Error in getTopReportingLocations: $e');
      return [];
    }
  }

  // ==================== STATUS ANALYTICS ====================

  /// Get report status distribution
  static Future<Map<String, int>> getReportsByStatus({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query query = _firestore.collection('reports');

      if (startDate != null) {
        query = query.where(
          'submittedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'submittedAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      final snapshot = await query.get();

      Map<String, int> statusCounts = {
        'submitted': 0,
        'under_review': 0,
        'resolved': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final status = data['status'] ?? 'submitted';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      debugPrint('Error in getReportsByStatus: $e');
      return {'submitted': 0, 'under_review': 0, 'resolved': 0};
    }
  }

  // ==================== TRENDS & COMPARISON ====================

  /// Compare current period with previous period
  static Future<Map<String, dynamic>> getComparisonData({
    required DateTime currentStart,
    required DateTime currentEnd,
  }) async {
    try {
      final duration = currentEnd.difference(currentStart);
      final previousStart = currentStart.subtract(duration);
      final previousEnd = currentStart;

      // Get counts for both periods
      final currentQuery = _firestore
          .collection('reports')
          .where(
            'submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(currentStart),
          )
          .where(
            'submittedAt',
            isLessThanOrEqualTo: Timestamp.fromDate(currentEnd),
          );

      final previousQuery = _firestore
          .collection('reports')
          .where(
            'submittedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(previousStart),
          )
          .where('submittedAt', isLessThan: Timestamp.fromDate(previousEnd));

      final currentSnapshot = await currentQuery.count().get();
      final previousSnapshot = await previousQuery.count().get();

      final currentCount = currentSnapshot.count ?? 0;
      final previousCount = previousSnapshot.count ?? 0;

      // Calculate percentage change
      double percentageChange = 0.0;
      if (previousCount > 0) {
        percentageChange =
            ((currentCount - previousCount) / previousCount) * 100;
      }

      return {
        'currentCount': currentCount,
        'previousCount': previousCount,
        'percentageChange': percentageChange,
        'isIncrease': currentCount >= previousCount,
      };
    } catch (e) {
      debugPrint('Error in getComparisonData: $e');
      return {
        'currentCount': 0,
        'previousCount': 0,
        'percentageChange': 0.0,
        'isIncrease': false,
      };
    }
  }

  /// Get comprehensive analytics dashboard data.
  /// Passing both startDate and endDate as null means "All Time" — this
  /// must reach the underlying queries as null (no date filter) rather
  /// than being defaulted to the current month, otherwise "All Time"
  /// silently behaves identically to "Month".
  static Future<Map<String, dynamic>> getDashboardAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final isAllTime = startDate == null && endDate == null;

      // Fetch all analytics in parallel. A period-over-period comparison
      // isn't meaningful for "All Time" (there's no "previous all time"),
      // so skip it rather than silently comparing against the current
      // month instead.
      final results = await Future.wait([
        getReportsByCaseType(startDate: startDate, endDate: endDate),
        getReportsByStatus(startDate: startDate, endDate: endDate),
        getTopReportingLocations(
          limit: 5,
          startDate: startDate,
          endDate: endDate,
        ),
        isAllTime
            ? Future.value(<String, dynamic>{})
            : getComparisonData(
              currentStart:
                  startDate ??
                  DateTime(DateTime.now().year, DateTime.now().month, 1),
              currentEnd: endDate ?? DateTime.now(),
            ),
      ]);

      return {
        'caseTypeCounts': results[0],
        'statusCounts': results[1],
        'topLocations': results[2],
        'comparison': results[3],
        'dateRange': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
      };
    } catch (e) {
      debugPrint('Error in getDashboardAnalytics: $e');
      return {};
    }
  }

  // ==================== HELPER METHODS ====================

  /// Convert weekday number to name
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }
}
