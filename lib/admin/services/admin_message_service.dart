import 'package:cloud_firestore/cloud_firestore.dart';

class AdminMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get real-time stream of admin messages
  static Stream<QuerySnapshot> getMessagesStream() {
    return _firestore.collection('admin_messages').limit(50).snapshots();
  }

  /// Get unread message count
  static Stream<int> getUnreadMessageCountStream() {
    return _firestore
        .collection('admin_messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Mark message as read
  static Future<void> markAsRead(String messageId) async {
    try {
      await _firestore.collection('admin_messages').doc(messageId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  /// Mark all messages as read
  static Future<void> markAllAsRead() async {
    try {
      final unreadMessages =
          await _firestore
              .collection('admin_messages')
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all as read: $e');
    }
  }

  /// Send a message
  static Future<void> sendMessage({
    required String subject,
    required String content,
    required String senderId,
    String? recipientId,
    String? reportId,
    String priority = 'normal',
  }) async {
    try {
      await _firestore.collection('admin_messages').add({
        'subject': subject,
        'content': content,
        'senderId': senderId,
        'recipientId': recipientId,
        'reportId': reportId,
        'priority': priority,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  /// Delete a message
  static Future<void> deleteMessage(String messageId) async {
    try {
      await _firestore.collection('admin_messages').doc(messageId).delete();
    } catch (e) {
      print('Error deleting message: $e');
    }
  }

  /// Format timestamp
  static String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final now = DateTime.now();
    final dateTime = timestamp.toDate();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
