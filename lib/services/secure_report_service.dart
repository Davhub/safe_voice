import 'package:cloud_firestore/cloud_firestore.dart';

/// Enhanced report service that separates sensitive data from status data
class SecureReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit report with separated status tracking
  static Future<String> submitSecureReport({
    required String caseId,
    required Map<String, dynamic> reportData,
  }) async {
    try {
      // Create a batch write to ensure atomicity
      WriteBatch batch = _firestore.batch();

      // Store full report in main collection (admin only access)
      DocumentReference reportRef = _firestore.collection('reports').doc(caseId);
      batch.set(reportRef, reportData);

      // Store only status info in public status collection
      DocumentReference statusRef = _firestore.collection('report_status').doc(caseId);
      batch.set(statusRef, {
        'caseId': caseId,
        'status': 'submitted',
        'type': reportData['type'],
        'submittedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Execute batch
      await batch.commit();
      
      return caseId;
    } catch (e) {
      throw Exception('Failed to submit secure report: $e');
    }
  }

  /// Get status from public status collection
  static Future<Map<String, dynamic>?> getSecureReportStatus(String caseId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('report_status')
          .doc(caseId)
          .get();
      
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get secure report status: $e');
    }
  }
}
