import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:safe_voice/services/notification_gateway_service.dart';
import 'package:safe_voice/services/urgency_classifier.dart';
import 'dart:io';

/// Service for handling anonymous report submissions to Firebase
class ReportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const Uuid _uuid = Uuid();

  static String classifyUrgency(String content) =>
      UrgencyClassifier.classify(content);

  // ignore: unused_element
  static String _coarsenLocation(String? location) {
    if (location == null || location.trim().isEmpty) {
      return 'Unknown LGA';
    }

    final firstPart = location.split(',').first.trim();
    return firstPart.isEmpty ? 'Unknown LGA' : firstPart;
  }

  /// Submit an anonymous text report
  static Future<String> submitTextReport({
    required String reportText,
    String? caseType, // NEW: Case type (FGM, SEXUAL_ASSAULT, GBV)
    String? location,
    DateTime? incidentDate,
    List<String>? attachmentUrls,
  }) async {
    try {
      // Generate anonymous case ID
      String caseId = _generateCaseId();

      // Create report document
      final urgency = classifyUrgency(reportText);

      Map<String, dynamic> reportData = {
        'caseId': caseId,
        'type': 'text',
        'caseType':
            caseType ?? 'FGM', // Default to FGM for backward compatibility
        'case_type': caseType ?? 'FGM', // Also store snake_case for consistency
        'content': reportText,
        'location': location,
        'incidentDate': incidentDate?.toIso8601String(),
        'attachments': attachmentUrls ?? [],
        'status': 'submitted',
        'urgency': urgency,
        'jurisdiction': _coarsenLocation(location),
        'notificationSent': false,
        'submittedAt': FieldValue.serverTimestamp(),
        'anonymous': true,
      };

      // Save to Firestore
      await _firestore.collection('reports').doc(caseId).set(reportData);

      await NotificationGatewayService.queueReportAlert(
        caseId: caseId,
        reportType: 'text',
        urgency: urgency,
        location: location,
        status: 'submitted',
        reportData: reportData,
      );

      // Create admin notification
      try {
        await _firestore.collection('admin_notifications').add({
          'type': 'report_submitted',
          'title': 'New Text Report',
          'message': 'A new text report has been submitted',
          'reportId': caseId,
          'priority': 'normal',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'reportType': 'text',
            'location': location,
            'status': 'submitted',
          },
        });
      } catch (notificationError) {
        print(
          '⚠️ Failed to create notification (non-critical): $notificationError',
        );
      }

      return caseId;
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  /// Submit an anonymous voice report
  static Future<String> submitVoiceReport({
    required File audioFile,
    String? additionalText,
    String? caseType, // NEW: Case type (FGM, SEXUAL_ASSAULT, GBV)
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
      final urgency = classifyUrgency(additionalText ?? '');

      Map<String, dynamic> reportData = {
        'caseId': caseId,
        'type': 'voice',
        'caseType':
            caseType ?? 'FGM', // Default to FGM for backward compatibility
        'case_type': caseType ?? 'FGM', // Also store snake_case for consistency
        'audioUrl': audioUrl,
        'additionalText': additionalText,
        'location': location,
        'incidentDate': incidentDate?.toIso8601String(),
        'status': 'submitted',
        'urgency': urgency,
        'jurisdiction': _coarsenLocation(location),
        'notificationSent': false,
        'submittedAt': FieldValue.serverTimestamp(),
        'anonymous': true,
      };

      print('💾 Saving report to Firestore...');
      // Save to Firestore
      await _firestore.collection('reports').doc(caseId).set(reportData);

      await NotificationGatewayService.queueReportAlert(
        caseId: caseId,
        reportType: 'voice',
        urgency: urgency,
        location: location,
        status: 'submitted',
        reportData: reportData,
      );

      // Create admin notification
      try {
        await _firestore.collection('admin_notifications').add({
          'type': 'report_submitted',
          'title': 'New Voice Report',
          'message': 'A new voice report has been submitted',
          'reportId': caseId,
          'priority': 'normal',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'data': {
            'reportType': 'voice',
            'location': location,
            'status': 'submitted',
          },
        });
        print('📬 Admin notification created');
      } catch (notificationError) {
        print(
          '⚠️ Failed to create notification (non-critical): $notificationError',
        );
      }

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
        String fileName =
            '${caseId}_attachment_$i.${_getFileExtension(file.path)}';

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
      DocumentSnapshot doc =
          await _firestore.collection('reports').doc(caseId).get();

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
    String fileName =
        '${caseId}_voice_report.${_getFileExtension(audioFile.path)}';
    String storagePath = 'voice_reports/$caseId/$fileName';

    try {
      print('📤 Uploading to: $storagePath');

      Reference ref = _storage.ref().child(storagePath);

      print('📤 Starting file upload...');

      // Set metadata to ensure proper content type for audio files
      SettableMetadata metadata = SettableMetadata(
        contentType: _getContentType(audioFile.path),
        customMetadata: {
          'caseId': caseId,
          'uploadTime': DateTime.now().toIso8601String(),
        },
      );

      UploadTask uploadTask = ref.putFile(audioFile, metadata);

      TaskSnapshot snapshot = await uploadTask;
      print('✅ Upload completed successfully');

      // Try to get download URL
      try {
        String downloadUrl = await snapshot.ref.getDownloadURL();
        print('🔗 Download URL: $downloadUrl');
        return downloadUrl;
      } catch (urlError) {
        print(
          '⚠️ Could not get download URL (likely due to read permissions): $urlError',
        );
        // Return the storage path instead - this is fine for anonymous reports
        String constructedUrl = 'gs://${ref.bucket}/$storagePath';
        print('🔗 Using constructed storage reference: $constructedUrl');
        return constructedUrl;
      }
    } catch (e) {
      print('❌ Audio upload failed: $e');

      // More specific error handling
      String errorMessage = e.toString().toLowerCase();

      if (errorMessage.contains('network') ||
          errorMessage.contains('timeout')) {
        throw Exception(
          'Network error during upload. Please check your internet connection.',
        );
      } else if (errorMessage.contains('unauthorized') ||
          errorMessage.contains('permission')) {
        throw Exception(
          'Upload permission denied. Please update Firebase Storage rules.',
        );
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

  /// Get content type for file upload
  static String _getContentType(String path) {
    String extension = _getFileExtension(path);
    switch (extension) {
      case 'm4a':
        return 'audio/mp4'; // M4A uses audio/mp4 MIME type
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      case 'webm':
        return 'audio/webm';
      default:
        return 'audio/mp4'; // Default for our mock M4A files
    }
  }

  /// Get anonymous statistics (for admin dashboard - no personal data)
  static Future<Map<String, int>> getAnonymousStatistics() async {
    try {
      QuerySnapshot snapshot = await _firestore.collection('reports').get();

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
        if (data['type'] == 'text')
          stats['textReports'] = stats['textReports']! + 1;
        if (data['type'] == 'voice')
          stats['voiceReports'] = stats['voiceReports']! + 1;

        // Count by status
        if (data['status'] == 'submitted')
          stats['pendingReports'] = stats['pendingReports']! + 1;
        if (data['status'] == 'reviewed')
          stats['reviewedReports'] = stats['reviewedReports']! + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to get statistics: $e');
    }
  }
}
