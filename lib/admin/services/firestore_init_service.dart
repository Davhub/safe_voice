import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to initialize Firestore collections and create sample data
class FirestoreInitService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Initialize admin collections with sample data
  static Future<void> initializeAdminCollections() async {
    try {
      // Check if collections exist by trying to get one document
      final notificationsSnapshot = await _firestore
          .collection('admin_notifications')
          .limit(1)
          .get();
      
      final messagesSnapshot = await _firestore
          .collection('admin_messages')
          .limit(1)
          .get();
      
      final activitiesSnapshot = await _firestore
          .collection('admin_activities')
          .limit(1)
          .get();

      // Create sample notification if collection is empty
      if (notificationsSnapshot.docs.isEmpty) {
        await _createSampleNotification();
      }

      // Create sample message if collection is empty
      if (messagesSnapshot.docs.isEmpty) {
        await _createSampleMessage();
      }

      // Create sample activity if collection is empty
      if (activitiesSnapshot.docs.isEmpty) {
        await _createSampleActivity();
      }

      print('Firestore collections initialized successfully');
    } catch (e) {
      print('Error initializing Firestore collections: $e');
    }
  }

  static Future<void> _createSampleNotification() async {
    await _firestore.collection('admin_notifications').add({
      'type': 'system',
      'title': 'Welcome to SafeVoice Admin',
      'message': 'Your admin dashboard is ready. Notifications will appear here when reports are submitted.',
      'priority': 'normal',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Sample notification created');
  }

  static Future<void> _createSampleMessage() async {
    await _firestore.collection('admin_messages').add({
      'subject': 'Welcome to SafeVoice Admin',
      'content': 'Welcome to the SafeVoice admin messaging system. Messages and communications will appear here.',
      'senderId': 'system',
      'priority': 'normal',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('Sample message created');
  }

  static Future<void> _createSampleActivity() async {
    await _firestore.collection('admin_activities').add({
      'type': 'system',
      'title': 'System initialized',
      'description': 'SafeVoice admin dashboard initialized successfully',
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('Sample activity created');
  }

  /// Clear all admin data (use with caution!)
  static Future<void> clearAllAdminData() async {
    try {
      // Clear notifications
      final notifications = await _firestore.collection('admin_notifications').get();
      for (var doc in notifications.docs) {
        await doc.reference.delete();
      }

      // Clear messages
      final messages = await _firestore.collection('admin_messages').get();
      for (var doc in messages.docs) {
        await doc.reference.delete();
      }

      // Clear activities
      final activities = await _firestore.collection('admin_activities').get();
      for (var doc in activities.docs) {
        await doc.reference.delete();
      }

      print('All admin data cleared');
    } catch (e) {
      print('Error clearing admin data: $e');
    }
  }
}
