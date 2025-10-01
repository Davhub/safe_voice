import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

/// Service for handling anonymous report submissions to Firebase
class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const Uuid _uuid = Uuid();

  /// Submit an anonymous text report
  static Future<String> submitTextReport({
    required String reportText,
    String? location,
    DateTime? incidentDate,
    List<String>? attachmentUrls,
  }) async {
    try {
      // Generate anonymous case ID
      String caseId = _generateCaseId();
      
      // Create report document
      Map<String, dynamic> reportData = {
        'caseId': caseId,
        'type': 'text',
        'content': reportText,
        'location': location,
        'incidentDate': incidentDate?.toIso8601String(),
        'attachments': attachmentUrls ?? [],
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'anonymous': true,
      };

      // Save to Firestore
      await _firestore
          .collection('reports')
          .doc(caseId)
          .set(reportData);

      return caseId;
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Submit an anonymous voice report
  static Future<String> submitVoiceReport({
    required File audioFile,
    String? additionalText,
    String? location,
    DateTime? incidentDate,
  }) async {
    try {
      // Generate anonymous case ID
      String caseId = _generateCaseId();
      
      // Upload audio file to Firebase Storage
      String audioUrl = await _uploadAudioFile(audioFile, caseId);
      
      // Create report document
      Map<String, dynamic> reportData = {
        'caseId': caseId,
        'type': 'voice',
        'audioUrl': audioUrl,
        'additionalText': additionalText,
        'location': location,
        'incidentDate': incidentDate?.toIso8601String(),
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'anonymous': true,
      };

      // Save to Firestore
      await _firestore
          .collection('reports')
          .doc(caseId)
          .set(reportData);

      return caseId;
    } catch (e) {
      throw Exception('Failed to submit voice report: $e');
    }
  }

  /// Upload file attachments (images, documents)
  static Future<List<String>> uploadAttachments({
    required List<File> files,
    required String caseId,
  }) async {
    try {
      List<String> downloadUrls = [];
      
      for (int i = 0; i < files.length; i++) {
        File file = files[i];
        String fileName = '${caseId}_attachment_$i.${_getFileExtension(file.path)}';
        
        // Upload to Firebase Storage
        Reference ref = _storage.ref().child('attachments/$caseId/$fileName');
        UploadTask uploadTask = ref.putFile(file);
        TaskSnapshot snapshot = await uploadTask;
        
        // Get download URL
        String downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
      }
      
      return downloadUrls;
    } catch (e) {
      throw Exception('Failed to upload attachments: $e');
    }
  }

  /// Check report status by case ID (for follow-up)
  static Future<Map<String, dynamic>?> getReportStatus(String caseId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('reports')
          .doc(caseId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        // Return only non-sensitive status information
        return {
          'caseId': data['caseId'],
          'status': data['status'],
          'submittedAt': data['submittedAt'],
          'type': data['type'],
        };
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get report status: $e');
    }
  }

  /// Generate anonymous case ID
  static String _generateCaseId() {
    // Generate a unique, anonymous case ID
    String uuid = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'SV$uuid'; // SV prefix for Safe Voice
  }

  /// Upload audio file to Firebase Storage
  static Future<String> _uploadAudioFile(File audioFile, String caseId) async {
    try {
      String fileName = '${caseId}_voice_report.${_getFileExtension(audioFile.path)}';
      Reference ref = _storage.ref().child('voice_reports/$caseId/$fileName');
      
      UploadTask uploadTask = ref.putFile(audioFile);
      TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload audio file: $e');
    }
  }

  /// Get file extension from path
  static String _getFileExtension(String path) {
    return path.split('.').last.toLowerCase();
  }

  /// Get anonymous statistics (for admin dashboard - no personal data)
  static Future<Map<String, int>> getAnonymousStatistics() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('reports')
          .get();
      
      Map<String, int> stats = {
        'totalReports': snapshot.docs.length,
        'textReports': 0,
        'voiceReports': 0,
        'pendingReports': 0,
        'reviewedReports': 0,
      };
      
      for (QueryDocumentSnapshot doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Count by type
        if (data['type'] == 'text') stats['textReports'] = stats['textReports']! + 1;
        if (data['type'] == 'voice') stats['voiceReports'] = stats['voiceReports']! + 1;
        
        // Count by status
        if (data['status'] == 'submitted') stats['pendingReports'] = stats['pendingReports']! + 1;
        if (data['status'] == 'reviewed') stats['reviewedReports'] = stats['reviewedReports']! + 1;
      }
      
      return stats;
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }
}
