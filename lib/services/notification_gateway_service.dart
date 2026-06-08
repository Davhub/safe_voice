import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationGatewayService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> queueReportAlert({
    required String caseId,
    required String reportType,
    required String urgency,
    required String? location,
    required String status,
    required Map<String, dynamic> reportData,
  }) async {
    final priority = switch (urgency) {
      'CRITICAL' => 'high',
      'HIGH' => 'medium',
      _ => 'normal',
    };

    await _firestore.collection('notification_requests').add({
      'caseId': caseId,
      'reportType': reportType,
      'urgency': urgency,
      'priority': priority,
      'status': 'queued',
      'location': location,
      'targetChannels': ['email', 'sms', 'whatsapp', 'fcm'],
      'createdAt': FieldValue.serverTimestamp(),
      'payload': {
        'report': reportData,
        'message': 'Safe Voice report requires review',
      },
    });
  }
}
