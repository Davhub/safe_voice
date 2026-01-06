import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time stream of notifications (no time filtering to prevent timestamp refresh)
  static Stream<QuerySnapshot> getNotificationsStream() {
    // Don't filter by time - just get latest notifications ordered by creation
    // This prevents the cutoff from changing on reload
    return _firestore
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  /// Get unread notification count
  static Stream<int> getUnreadNotificationCountStream() {
    return _firestore
        .collection('admin_notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Create notification when report is submitted
  static Future<void> createReportSubmittedNotification(String reportId, Map<String, dynamic> reportData) async {
    try {
      final now = Timestamp.now();  // Use Timestamp.now() for immediate consistency
      
      // Create more specific notification title based on report type
      final reportType = reportData['type'] ?? 'report';
      final title = reportType == 'voice' 
          ? 'New Voice Report Submitted' 
          : 'New Text Report Submitted';
      
      await _firestore.collection('admin_notifications').add({
        'type': 'report_submitted',
        'title': title,
        'message': 'Case ID: ${reportId.substring(0, 10)}... requires review',
        'reportId': reportId,
        'priority': _determinePriority(reportData),
        'isRead': false,
        'createdAt': now,
        'data': {
          'reportType': reportData['type'],
          'location': reportData['location'],
          'status': reportData['status'],
        },
      });
      
      print('✅ Notification created: $title');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  /// Create notification when report status changes
  static Future<void> createStatusChangeNotification(
    String reportId,
    String oldStatus,
    String newStatus,
  ) async {
    try {
      final now = Timestamp.now();  // Use Timestamp.now() for immediate consistency
      
      await _firestore.collection('admin_notifications').add({
        'type': 'status_change',
        'title': 'Report Status Updated',
        'message': 'Report #${reportId.substring(0, 8)} changed from $oldStatus to $newStatus',
        'reportId': reportId,
        'priority': 'normal',
        'isRead': false,
        'createdAt': now,
        'data': {
          'oldStatus': oldStatus,
          'newStatus': newStatus,
        },
      });
      
      print('✅ Status change notification created');
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  /// Create notification for high priority reports
  static Future<void> createHighPriorityNotification(String reportId, String reason) async {
    try {
      final now = Timestamp.now();  // Use Timestamp.now() for immediate consistency
      
      await _firestore.collection('admin_notifications').add({
        'type': 'high_priority',
        'title': 'High Priority Alert',
        'message': reason,
        'reportId': reportId,
        'priority': 'urgent',
        'isRead': false,
        'createdAt': now,
      });
    } catch (e) {
      print('❌ Error creating notification: $e');
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('admin_notifications').doc(notificationId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    try {
      final unreadNotifications = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in unreadNotifications.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('admin_notifications').doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Delete all read notifications
  static Future<void> clearReadNotifications() async {
    try {
      final readNotifications = await _firestore
          .collection('admin_notifications')
          .where('isRead', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in readNotifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error clearing read notifications: $e');
    }
  }

  /// Determine priority based on report data
  static String _determinePriority(Map<String, dynamic> reportData) {
    final content = (reportData['content'] ?? '').toString().toLowerCase();
    final keywords = reportData['keywords'] as List<dynamic>? ?? [];
    
    final urgentKeywords = ['emergency', 'urgent', 'danger', 'help', 'attack', 'violence', 'assault', 'weapon'];
    final highKeywords = ['threat', 'harassment', 'unsafe', 'concern', 'suspicious', 'bullying'];
    
    if (keywords.any((k) => urgentKeywords.contains(k.toString().toLowerCase())) ||
        urgentKeywords.any((k) => content.contains(k))) {
      return 'urgent';
    }
    
    if (keywords.any((k) => highKeywords.contains(k.toString().toLowerCase())) ||
        highKeywords.any((k) => content.contains(k))) {
      return 'high';
    }
    
    return 'normal';
  }

  /// Format timestamp with accurate relative time
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
}
