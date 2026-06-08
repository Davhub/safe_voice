import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';
import 'package:safe_voice/admin/services/admin_notification_service.dart';

/// Service to listen for changes in reports and automatically create
/// notifications and activity logs
class ReportListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot>? _subscription;

  /// Start listening to report changes
  static void startListening() {
    // Listen to all reports
    _subscription = _firestore
        .collection('reports')
        .snapshots()
        .listen(_handleReportChanges);
  }

  /// Stop listening
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Handle report document changes
  static void _handleReportChanges(QuerySnapshot snapshot) {
    for (var change in snapshot.docChanges) {
      final reportId = change.doc.id;
      final reportData = change.doc.data() as Map<String, dynamic>?;

      if (reportData == null) continue;

      switch (change.type) {
        case DocumentChangeType.added:
          _handleReportAdded(reportId, reportData);
          break;
        case DocumentChangeType.modified:
          _handleReportModified(reportId, reportData);
          break;
        case DocumentChangeType.removed:
          // Optionally handle deletions
          break;
      }
    }
  }

  /// Handle new report submission
  static void _handleReportAdded(
    String reportId,
    Map<String, dynamic> reportData,
  ) {
    // Create notification
    AdminNotificationService.createReportSubmittedNotification(
      reportId,
      reportData,
    );

    // Log activity
    AdminActivityService.logActivity(
      type: 'report_submitted',
      title: 'New report submitted',
      description: 'Report #${reportId.substring(0, 8)} was submitted',
      reportId: reportId,
      userId: reportData['userId'],
      metadata: {
        'reportType': reportData['type'],
        'location': reportData['location'],
      },
    );
  }

  /// Handle report status changes
  static void _handleReportModified(
    String reportId,
    Map<String, dynamic> reportData,
  ) {
    final statusHistory = reportData['status_history'] as List<dynamic>?;

    if (statusHistory != null && statusHistory.length >= 2) {
      // Get the last two status entries
      final currentStatus = statusHistory.last;
      final previousStatus = statusHistory[statusHistory.length - 2];

      final oldStatus = previousStatus['status'] as String?;
      final newStatus = currentStatus['status'] as String?;

      if (oldStatus != null && newStatus != null && oldStatus != newStatus) {
        // Status changed
        AdminNotificationService.createStatusChangeNotification(
          reportId,
          oldStatus,
          newStatus,
        );

        AdminActivityService.logReportStatusChange(
          reportId,
          oldStatus,
          newStatus,
          currentStatus['admin_id'] ?? 'system',
        );

        // Check if resolved
        if (newStatus == 'resolved') {
          AdminActivityService.logReportResolution(
            reportId,
            currentStatus['admin_id'] ?? 'system',
          );
        }
      }
    }
  }
}
