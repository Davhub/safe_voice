import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to create test reports for status checking functionality
class TestReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a test report for status checking
  static Future<String> createTestReport() async {
    try {
      String testCaseId = 'SVTEST${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      
      Map<String, dynamic> testReport = {
        'caseId': testCaseId,
        'type': 'text',
        'content': 'This is a test report for status checking functionality',
        'location': 'Test Location',
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'statusMessage': 'Your test report has been received and is being processed',
      };

      await _firestore
          .collection('reports')
          .doc(testCaseId)
          .set(testReport);

      print('✅ Test report created with Case ID: $testCaseId');
      return testCaseId;
    } catch (e) {
      print('❌ Error creating test report: $e');
      throw Exception('Failed to create test report: $e');
    }
  }

  /// Update test report status (simulates admin action)
  static Future<void> updateTestReportStatus(String caseId, String newStatus, {String? statusMessage}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (statusMessage != null) {
        updateData['statusMessage'] = statusMessage;
      }

      await _firestore
          .collection('reports')
          .doc(caseId)
          .update(updateData);

      print('✅ Test report status updated: $caseId -> $newStatus');
    } catch (e) {
      print('❌ Error updating test report: $e');
      throw Exception('Failed to update test report: $e');
    }
  }

  /// Delete test report
  static Future<void> deleteTestReport(String caseId) async {
    try {
      await _firestore
          .collection('reports')
          .doc(caseId)
          .delete();

      print('✅ Test report deleted: $caseId');
    } catch (e) {
      print('❌ Error deleting test report: $e');
    }
  }
}
