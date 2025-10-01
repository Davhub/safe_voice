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
      print('🎤 Starting voice report submission...');
      
      // Generate anonymous case ID
      String caseId = _generateCaseId();
      print('🆔 Generated case ID: $caseId');
      
      // Check if file exists and get info
      if (!await audioFile.exists()) {
        throw Exception('Audio file does not exist: ${audioFile.path}');
      }
      
      final fileSize = await audioFile.length();
      print('📁 Audio file: ${audioFile.path} (${fileSize} bytes)');
      
      // Upload audio file to Firebase Storage
      print('☁️ Uploading audio file to Firebase Storage...');
      String audioUrl = await _uploadAudioFile(audioFile, caseId);
      print('✅ Audio uploaded successfully: $audioUrl');
      
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

      print('💾 Saving report to Firestore...');
      // Save to Firestore
      await _firestore
          .collection('reports')
          .doc(caseId)
          .set(reportData);

      print('✅ Voice report saved successfully with case ID: $caseId');
      return caseId;
    } catch (e) {
      print('❌ Voice report submission failed: $e');
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
    String fileName = '${caseId}_voice_report.${_getFileExtension(audioFile.path)}';
    String storagePath = 'voice_reports/$caseId/$fileName';
    
    try {
      print('📤 Uploading to: $storagePath');
      
      Reference ref = _storage.ref().child(storagePath);
      
      print('📤 Starting file upload...');
      UploadTask uploadTask = ref.putFile(audioFile);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('⏳ Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      TaskSnapshot snapshot = await uploadTask;
      print('✅ Upload completed successfully');
      
      // Try to get download URL, but if it fails due to read permissions,
      // return a constructed URL instead
      try {
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print('🔗 Download URL: $downloadUrl');
        return downloadUrl;
      } catch (urlError) {
        print('⚠️ Could not get download URL (likely due to read permissions): $urlError');
        // Return the storage path instead - this is fine for anonymous reports
        // where we don't need to read the files back
        String constructedUrl = 'gs://${ref.bucket}/$storagePath';
        print('🔗 Using constructed storage reference: $constructedUrl');
        return constructedUrl;
      }
      
    } catch (e) {
      print('❌ Audio upload failed: $e');
      
      // More specific error handling
      String errorMessage = e.toString().toLowerCase();
      
      if (errorMessage.contains('network') || errorMessage.contains('timeout')) {
        throw Exception('Network error during upload. Please check your internet connection.');
      } else if (errorMessage.contains('unauthorized') || errorMessage.contains('permission')) {
        // If the upload itself failed due to permissions, that's a real error
        // But if we got here, the upload succeeded and only URL retrieval failed
        throw Exception('Upload permission denied. Please update Firebase Storage rules.');
      } else if (errorMessage.contains('storage/quota-exceeded')) {
        throw Exception('Storage quota exceeded. Please contact support.');
      } else if (errorMessage.contains('storage/invalid-format')) {
        throw Exception('Invalid audio file format. Please try again.');
      } else {
        throw Exception('Failed to upload audio file: $e');
      }
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
