import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class AdminReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Stream<QuerySnapshot> getReportsStream({String? status, int limit = 50, DocumentSnapshot? startAfter}) {
    try {
      Query query = _firestore.collection('reports');
      
      // Apply status filter if provided
      if (status != null && status.isNotEmpty) {
        query = query.where('status', isEqualTo: status);
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

  static Future<DocumentSnapshot?> getReportByCaseId(String caseId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('reports').doc(caseId).get();
      return doc.exists ? doc : null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> updateReportStatus({required String caseId, required String status, String? statusMessage, String? adminId, DateTime? estimatedResolution}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': status,
        'last_updated': FieldValue.serverTimestamp(),
        'admin_updated_by': adminId,
      };
      if (statusMessage != null) updateData['status_message'] = statusMessage;
      if (estimatedResolution != null) updateData['estimated_resolution'] = Timestamp.fromDate(estimatedResolution);

      updateData['status_history'] = FieldValue.arrayUnion([
        {'status': status, 'timestamp': FieldValue.serverTimestamp(), 'admin_id': adminId, 'message': statusMessage}
      ]);

      await _firestore.collection('reports').doc(caseId).update(updateData);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getAudioDownloadUrl(String caseId) async {
    try {
      String path = 'voice_reports/$caseId/${caseId}_voice_report.m4a';
      String downloadUrl = await _storage.ref(path).getDownloadURL();
      return downloadUrl;
    } catch (e) {
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
      QuerySnapshot allReports = await _firestore.collection('reports').get();
      Map<String, int> stats = {'total': allReports.docs.length, 'submitted': 0, 'under_review': 0, 'investigating': 0, 'resolved': 0, 'requires_follow_up': 0, 'closed': 0};
      for (var doc in allReports.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'submitted';
        stats[status] = (stats[status] ?? 0) + 1;
      }
      return stats;
    } catch (e) {
      return {'total': 0};
    }
  }

  static Future<bool> addAdminNote({required String caseId, required String note, required String adminId}) async {
    try {
      await _firestore.collection('reports').doc(caseId).update({'admin_notes': FieldValue.arrayUnion([{'note': note, 'admin_id': adminId, 'timestamp': FieldValue.serverTimestamp()}])});
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getReportTimeline(String caseId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('reports').doc(caseId).get();
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
            'action': 'Status Updated to ${getStatusDisplayName(status['status'] ?? 'unknown')}',
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
      DocumentSnapshot doc = await _firestore.collection('reports').doc(caseId).get();
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

  static List<String> getStatusOptions() => ['submitted','under_review','investigating','requires_follow_up','resolved','closed'];

  static String getStatusDisplayName(String status) {
    switch (status) {
      case 'submitted': return 'Submitted';
      case 'under_review': return 'Under Review';
      case 'investigating': return 'Investigating';
      case 'requires_follow_up': return 'Requires Follow-up';
      case 'resolved': return 'Resolved';
      case 'closed': return 'Closed';
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case 'submitted': return Colors.orange;
      case 'under_review':
      case 'investigating': return Colors.blue;
      case 'requires_follow_up': return Colors.amber;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.grey;
    }
  }
}
