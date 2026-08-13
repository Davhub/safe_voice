import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:safe_voice/admin/services/admin_notification_service.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';

class AdminReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Stream<QuerySnapshot> getReportsStream({
    String? status,
    int limit = 100,
    DocumentSnapshot? startAfter,
  }) {
    try {
      Query query = _firestore.collection('reports');

      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      // Order by submission date (most recent first)
      query = query.orderBy('submittedAt', descending: true);

      // Apply pagination if startAfter is provided
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      // Apply limit
      query = query.limit(limit);

      return query.snapshots();
    } catch (e) {
      debugPrint('Error in getReportsStream: $e');
      // Return an empty stream in case of error
      return const Stream.empty();
    }
  }

  /// Get total report count (for accurate statistics)
  static Future<int> getTotalReportCount({String? status}) async {
    try {
      Query query = _firestore.collection('reports');

      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting report count: $e');
      return 0;
    }
  }

  static Future<DocumentSnapshot?> getReportByCaseId(String caseId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateReportStatus({
    required String caseId,
    required String status,
    String? statusMessage,
    String? adminId,
    DateTime? estimatedResolution,
  }) async {
    try {
      print('📝 Updating report status: caseId=$caseId, status=$status');
      print('🔑 Admin ID: $adminId');

      // Get current status before updating
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();

      if (!doc.exists) {
        print('❌ Report document not found: $caseId');
        throw Exception('Report not found');
      }

      String? oldStatus;
      final data = doc.data() as Map<String, dynamic>?;
      oldStatus = data?['status'];
      print('📊 Current status: $oldStatus → New status: $status');

      // Use Timestamp.now() for immediate client updates
      final now = Timestamp.now();

      Map<String, dynamic> updateData = {
        'status': status,
        'lastUpdated':
            now, // Use Timestamp.now() for immediate real-time updates
        'last_updated': now, // Keep for consistency with snake_case
        'admin_updated_by': adminId,
      };
      if (statusMessage != null) updateData['statusMessage'] = statusMessage;
      if (statusMessage != null)
        updateData['status_message'] =
            statusMessage; // Keep both for compatibility
      if (estimatedResolution != null)
        updateData['estimated_resolution'] = Timestamp.fromDate(
          estimatedResolution,
        );

      // Note: serverTimestamp() cannot be used inside arrayUnion(), so we use Timestamp.now()
      updateData['status_history'] = FieldValue.arrayUnion([
        {
          'status': status,
          'timestamp': now,
          'admin_id': adminId,
          'message': statusMessage,
        },
      ]);

      print('📤 Attempting Firestore update...');
      await _firestore.collection('reports').doc(caseId).update(updateData);
      print('✅ Report status updated successfully in Firestore');

      // Log activity for Recent Activities section
      if (oldStatus != null && oldStatus != status) {
        try {
          await AdminActivityService.logReportStatusChange(
            caseId,
            oldStatus,
            status,
            adminId ?? 'admin',
          );
          print('📝 Activity logged for status change');
        } catch (activityError) {
          print('⚠️ Failed to log activity (non-critical): $activityError');
        }
      }

      // Create notification for status change
      if (oldStatus != null && oldStatus != status) {
        try {
          await AdminNotificationService.createStatusChangeNotification(
            caseId,
            oldStatus,
            status,
          );
          print('📬 Status change notification created');
        } catch (notificationError) {
          print(
            '⚠️ Failed to create notification (non-critical): $notificationError',
          );
        }

        if (status == 'resolved') {
          try {
            await AdminActivityService.logReportResolution(
              caseId,
              adminId ?? 'admin',
            );
          } catch (resolutionError) {
            print(
              '⚠️ Failed to log resolution (non-critical): $resolutionError',
            );
          }
        }
      }

      return true;
    } catch (e, stackTrace) {
      print('❌ Error updating report status: $e');
      print('Stack trace: $stackTrace');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  static Future<String?> getAudioDownloadUrl(String caseId) async {
    try {
      // First, try to get the audio URL directly from Firestore
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Check if audioUrl field exists (user app uses 'audioUrl' not 'audio_url')
        if (data['audioUrl'] != null &&
            data['audioUrl'].toString().isNotEmpty) {
          String audioUrl = data['audioUrl'];

          // If it's already a download URL, return it
          if (audioUrl.startsWith('http')) {
            return audioUrl;
          }

          // If it's a gs:// URL, convert it to download URL
          if (audioUrl.startsWith('gs://')) {
            try {
              String path = audioUrl.replaceFirst(RegExp(r'gs://[^/]+/'), '');
              return await _storage.ref(path).getDownloadURL();
            } catch (e) {
              print('Error converting gs:// URL: $e');
            }
          }
        }
      }

      // Fallback: Try to construct the path from caseId
      String path = 'voice_reports/$caseId/${caseId}_voice_report.m4a';
      String downloadUrl = await _storage.ref(path).getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error getting audio download URL: $e');
      return null;
    }
  }

  static Future<bool> deleteReport(String caseId) async {
    try {
      try {
        String path = 'voice_reports/$caseId/${caseId}_voice_report.m4a';
        await _storage.ref(path).delete();
      } catch (e) {}
      await _firestore.collection('reports').doc(caseId).delete();
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, int>> getReportsStatistics() async {
    try {
      // Use count() aggregation for better performance and accuracy
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

      // Calculate start of current week (Sunday)
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      final weekStart = DateTime(
        startOfWeek.year,
        startOfWeek.month,
        startOfWeek.day,
      );
      final weekStartTimestamp = Timestamp.fromDate(weekStart);

      // Count reports from this week
      final thisWeekCount =
          await _firestore
              .collection('reports')
              .where('submittedAt', isGreaterThan: weekStartTimestamp)
              .count()
              .get();

      // Initialize all status counters
      Map<String, int> stats = {
        'total': totalCount.count ?? 0,
        'submitted': submittedCount.count ?? 0,
        'pending': (submittedCount.count ?? 0) + (underReviewCount.count ?? 0),
        'under_review': underReviewCount.count ?? 0,
        'resolved': resolvedCount.count ?? 0,
        'thisWeek': thisWeekCount.count ?? 0,
      };

      print(
        '📊 Report Statistics: Total=${stats['total']}, Pending=${stats['pending']}, Resolved=${stats['resolved']}',
      );

      return stats;
    } catch (e) {
      print('❌ Error getting report statistics: $e');
      return {'total': 0, 'pending': 0, 'resolved': 0, 'thisWeek': 0};
    }
  }

  /// Assigns the case to the acting admin and records it in status_history,
  /// so it's visible in the same timeline as status changes.
  static Future<bool> acknowledgeReport({
    required String caseId,
    required String adminId,
    String? adminEmail,
  }) async {
    try {
      final now = Timestamp.now();

      await _firestore.collection('reports').doc(caseId).update({
        'assignedTo': adminId,
        'acknowledgedAt': now,
        'status_history': FieldValue.arrayUnion([
          {
            'status': 'acknowledged',
            'timestamp': now,
            'admin_id': adminId,
            'message': 'Case acknowledged by ${adminEmail ?? adminId}',
          },
        ]),
      });

      await AdminActivityService.logReportStatusChange(
        caseId,
        'submitted',
        'acknowledged',
        adminId,
      );

      await AdminNotificationService.createStatusChangeNotification(
        caseId,
        'submitted',
        'acknowledged',
      );

      return true;
    } catch (e) {
      debugPrint('Error acknowledging report: $e');
      return false;
    }
  }

  static Future<bool> addAdminNote({
    required String caseId,
    required String note,
    required String adminId,
  }) async {
    try {
      await _firestore.collection('reports').doc(caseId).update({
        'admin_notes': FieldValue.arrayUnion([
          {
            'note': note,
            'admin_id': adminId,
            'timestamp': FieldValue.serverTimestamp(),
          },
        ]),
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getReportTimeline(
    String caseId,
  ) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();
      if (!doc.exists) return [];

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<Map<String, dynamic>> timeline = [];

      // Add submission event
      if (data['submittedAt'] != null || data['submitted_at'] != null) {
        timeline.add({
          'action': 'Report Submitted',
          'timestamp': data['submittedAt'] ?? data['submitted_at'],
          'details': 'Initial report submission',
          'adminId': null,
        });
      }

      // Add status history events
      List<dynamic> statusHistory = data['status_history'] ?? [];
      for (var status in statusHistory) {
        if (status is Map<String, dynamic>) {
          timeline.add({
            'action':
                'Status Updated to ${getStatusDisplayName(status['status'] ?? 'unknown')}',
            'timestamp': status['timestamp'],
            'details': status['message'] ?? 'Status changed',
            'adminId': status['admin_id'],
          });
        }
      }

      // Sort by timestamp (newest first)
      timeline.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return timeline;
    } catch (e) {
      debugPrint('Error getting report timeline: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getAdminNotes(String caseId) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();
      if (!doc.exists) return [];

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<dynamic> adminNotes = data['admin_notes'] ?? [];

      List<Map<String, dynamic>> notes = [];
      for (var note in adminNotes) {
        if (note is Map<String, dynamic>) {
          notes.add({
            'note': note['note'] ?? '',
            'adminId': note['admin_id'] ?? 'Unknown Admin',
            'timestamp': note['timestamp'],
          });
        }
      }

      // Sort by timestamp (newest first)
      notes.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return notes;
    } catch (e) {
      debugPrint('Error getting admin notes: $e');
      return [];
    }
  }

  static List<String> getStatusOptions() => [
    'submitted',
    'under_review',
    'investigating',
    'requires_follow_up',
    'resolved',
    'closed',
  ];

  static String getStatusDisplayName(String status) {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'under_review':
        return 'Under Review';
      case 'investigating':
        return 'Investigating';
      case 'requires_follow_up':
        return 'Requires Follow-up';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.orange;
      case 'under_review':
      case 'investigating':
        return Colors.blue;
      case 'requires_follow_up':
        return Colors.amber;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
