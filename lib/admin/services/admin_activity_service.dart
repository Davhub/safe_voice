import 'package:cloud_firestore/cloud_firestore.dart';

class AdminActivityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time stream of recent activities (no time filtering to prevent timestamp refresh)
  static Stream<QuerySnapshot> getRecentActivitiesStream({int limit = 10}) {
    // Don't filter by time - just get latest activities ordered by timestamp
    // This prevents the cutoff from changing on reload
    return _firestore
        .collection('admin_activities')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  /// Check if activities collection has any data
  static Future<bool> hasActivities() async {
    try {
      final snapshot =
          await _firestore.collection('admin_activities').limit(1).get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking activities: $e');
      return false;
    }
  }

  /// Initialize with sample activity only if collection is completely empty
  static Future<void> initializeActivities() async {
    try {
      final hasData = await hasActivities();
      if (!hasData) {
        print('📝 Initializing admin_activities collection...');
        await logActivity(
          type: 'info',
          title: 'System initialized',
          description: 'Admin dashboard activities tracking started',
          userId: 'system',
        );
        print('✅ Activities collection initialized');
      }
    } catch (e) {
      print('⚠️ Error initializing activities: $e');
    }
  }

  /// Log an admin activity
  static Future<void> logActivity({
    required String type,
    required String title,
    required String description,
    String? userId,
    String? reportId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Use Timestamp.now() instead of serverTimestamp() for immediate visibility
      final now = Timestamp.now();

      await _firestore.collection('admin_activities').add({
        'type': type,
        'title': title,
        'description': description,
        'userId': userId,
        'reportId': reportId,
        'metadata': metadata ?? {},
        'timestamp': now,
      });

      print('✅ Activity logged: $title');
    } catch (e) {
      print('❌ Error logging activity: $e');
    }
  }

  /// Get activity icon based on type
  static Map<String, dynamic> getActivityStyle(String type) {
    switch (type.toLowerCase()) {
      case 'report_submitted':
        return {'icon': 'add_circle', 'color': 'green'};
      case 'report_updated':
        return {'icon': 'update', 'color': 'blue'};
      case 'report_resolved':
        return {'icon': 'check_circle', 'color': 'green'};
      case 'user_added':
        return {'icon': 'person_add', 'color': 'purple'};
      case 'user_removed':
        return {'icon': 'person_remove', 'color': 'red'};
      case 'settings_changed':
        return {'icon': 'settings', 'color': 'orange'};
      case 'security_audit':
        return {'icon': 'security', 'color': 'orange'};
      case 'data_export':
        return {'icon': 'download', 'color': 'blue'};
      case 'alert':
        return {'icon': 'warning', 'color': 'red'};
      default:
        return {'icon': 'info', 'color': 'grey'};
    }
  }

  /// Format timestamp for display with accurate relative time
  static String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final dateTime = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // For very recent times
      if (difference.inSeconds < 60) {
        return 'Just now';
      }
      // For times within the last hour
      else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return '$mins ${mins == 1 ? 'minute' : 'minutes'} ago';
      }
      // For times within the last 24 hours
      else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      }
      // For times within the last week
      else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      }
      // For times within the last month
      else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      }
      // For older times, show the actual date
      else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'Unknown';
    }
  }

  /// Create activity log when report is submitted (call this from report submission)
  static Future<void> logReportSubmission(
    String reportId,
    String userId,
  ) async {
    await logActivity(
      type: 'report_submitted',
      title: 'New report submitted',
      description: 'Report #$reportId was submitted',
      reportId: reportId,
      userId: userId,
    );
  }

  /// Create activity log when report status changes
  static Future<void> logReportStatusChange(
    String reportId,
    String oldStatus,
    String newStatus,
    String adminId,
  ) async {
    await logActivity(
      type: 'report_updated',
      title: 'Report status updated',
      description: 'Report #$reportId changed from $oldStatus to $newStatus',
      reportId: reportId,
      userId: adminId,
      metadata: {'oldStatus': oldStatus, 'newStatus': newStatus},
    );
  }

  /// Create activity log when report is resolved
  static Future<void> logReportResolution(
    String reportId,
    String adminId,
  ) async {
    await logActivity(
      type: 'report_resolved',
      title: 'Report resolved',
      description: 'Report #$reportId has been resolved',
      reportId: reportId,
      userId: adminId,
    );
  }
}
