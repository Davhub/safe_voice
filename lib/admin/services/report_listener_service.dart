import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';
import 'package:safe_voice/admin/services/admin_notification_service.dart';

/// NOT CURRENTLY USED — kept for reference only.
///
/// This used to create a notification + activity-log entry whenever it saw
/// a report added/modified, but report_service.dart (on submission) and
/// AdminReportService (on status change/acknowledge) already reliably
/// create exactly one of each at the point of the actual write. Having
/// both meant every report submitted (or status change made) while an
/// admin dashboard tab happened to be open produced duplicate entries —
/// this listener was the redundant, less reliable side of that pair (it
/// does nothing if no dashboard tab is open when the write happens). Do
/// not re-wire this into the dashboard without removing the other side.
class ReportListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static StreamSubscription<QuerySnapshot>? _subscription;

  // The first snapshot delivered after subscribing reports every existing
  // document as a DocumentChangeType.added — without this flag, every
  // dashboard mount (i.e. every login) would re-create a notification and
  // activity-log entry for every report ever submitted.
  static bool _initialSnapshotHandled = false;

  /// Start listening to report changes
  static void startListening() {
    _initialSnapshotHandled = false;

    // Bound to recent reports for cost control; older reports changing
    // status outside this window won't trigger a notification here.
    _subscription = _firestore
        .collection('reports')
        .orderBy('submittedAt', descending: true)
        .limit(200)
        .snapshots()
        .listen(_handleReportChanges);
  }

  /// Stop listening
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _initialSnapshotHandled = false;
  }

  /// Handle report document changes
  static void _handleReportChanges(QuerySnapshot snapshot) {
    if (!_initialSnapshotHandled) {
      // Skip the initial full snapshot — it isn't new activity, just the
      // current state of the collection.
      _initialSnapshotHandled = true;
      return;
    }

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
