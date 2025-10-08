import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced service for checking and monitoring report status
class ReportStatusService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final Map<String, StreamSubscription> _statusListeners = {};

  /// Check report status with enhanced error handling and debugging
  static Future<Map<String, dynamic>?> getReportStatus(String caseId) async {
    try {
      // Sanitize case ID
      String cleanCaseId = caseId.trim().toUpperCase();
      
      print('🔍 Checking status for case ID: $cleanCaseId');
      
      // Check connectivity first
      bool isOnline = await _isOnline();
      if (!isOnline) {
        throw Exception('No internet connection. Please check your network and try again.');
      }
      
      // Query Firestore with timeout
      DocumentSnapshot doc = await _firestore
          .collection('reports')
          .doc(cleanCaseId)
          .get()
          .timeout(
            Duration(seconds: 15),
            onTimeout: () => throw TimeoutException('Request timed out. Please try again.'),
          );
      
      print('📄 Document exists: ${doc.exists}');
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('📊 Document data: $data');
        
        // Ensure we have the required fields
        Map<String, dynamic> statusInfo = {
          'caseId': data['caseId'] ?? cleanCaseId,
          'status': data['status'] ?? 'submitted',
          'submittedAt': data['submittedAt'],
          'type': data['type'] ?? 'unknown',
          'lastUpdated': data['lastUpdated'] ?? data['submittedAt'],
        };
        
        // Add optional fields if available
        if (data['statusMessage'] != null) {
          statusInfo['statusMessage'] = data['statusMessage'];
        }
        if (data['estimatedResolution'] != null) {
          statusInfo['estimatedResolution'] = data['estimatedResolution'];
        }
        
        print('✅ Status retrieved successfully: ${statusInfo['status']}');
        return statusInfo;
      } else {
        // Try alternative searches (in case of case sensitivity issues)
        QuerySnapshot querySnapshot = await _firestore
            .collection('reports')
            .where('caseId', isEqualTo: cleanCaseId)
            .limit(1)
            .get()
            .timeout(Duration(seconds: 10));
        
        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot doc = querySnapshot.docs.first;
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          Map<String, dynamic> statusInfo = {
            'caseId': data['caseId'] ?? cleanCaseId,
            'status': data['status'] ?? 'submitted',
            'submittedAt': data['submittedAt'],
            'type': data['type'] ?? 'unknown',
            'lastUpdated': data['lastUpdated'] ?? data['submittedAt'],
          };
          
          print('✅ Status found via query: ${statusInfo['status']}');
          return statusInfo;
        }
        
        print('❌ Case ID not found in database');
        return null;
      }
    } on TimeoutException catch (e) {
      print('⏰ Timeout error: $e');
      throw Exception('Request timed out. Please check your internet connection and try again.');
    } catch (e) {
      print('❌ Error getting report status: $e');
      
      // Provide more specific error messages
      if (e.toString().contains('network') || e.toString().contains('connection')) {
        throw Exception('Network error. Please check your internet connection and try again.');
      } else if (e.toString().contains('permission')) {
        throw Exception('Access denied. Please try again later.');
      } else {
        throw Exception('Unable to check status at this time. Please try again later.');
      }
    }
  }

  /// Start listening for real-time status updates
  static StreamSubscription<DocumentSnapshot>? listenToStatusUpdates(
    String caseId,
    Function(Map<String, dynamic>) onStatusUpdate,
    Function(String) onError,
  ) {
    try {
      String cleanCaseId = caseId.trim().toUpperCase();
      
      // Cancel any existing listener for this case ID
      _statusListeners[cleanCaseId]?.cancel();
      
      print('👂 Starting real-time listener for: $cleanCaseId');
      
      StreamSubscription<DocumentSnapshot> subscription = _firestore
          .collection('reports')
          .doc(cleanCaseId)
          .snapshots()
          .listen(
            (DocumentSnapshot doc) {
              try {
                if (doc.exists) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  
                  Map<String, dynamic> statusInfo = {
                    'caseId': data['caseId'] ?? cleanCaseId,
                    'status': data['status'] ?? 'submitted',
                    'submittedAt': data['submittedAt'],
                    'type': data['type'] ?? 'unknown',
                    'lastUpdated': data['lastUpdated'] ?? data['submittedAt'],
                  };
                  
                  // Add optional fields
                  if (data['statusMessage'] != null) {
                    statusInfo['statusMessage'] = data['statusMessage'];
                  }
                  if (data['estimatedResolution'] != null) {
                    statusInfo['estimatedResolution'] = data['estimatedResolution'];
                  }
                  
                  print('🔄 Status update received: ${statusInfo['status']}');
                  onStatusUpdate(statusInfo);
                } else {
                  print('❌ Document no longer exists');
                  onError('Report not found');
                }
              } catch (e) {
                print('❌ Error processing status update: $e');
                onError('Error processing status update');
              }
            },
            onError: (error) {
              print('❌ Stream error: $error');
              onError('Connection error. Status updates paused.');
            },
          );
      
      _statusListeners[cleanCaseId] = subscription;
      return subscription;
    } catch (e) {
      print('❌ Error setting up status listener: $e');
      onError('Unable to set up real-time updates');
      return null;
    }
  }

  /// Stop listening for status updates
  static void stopListeningToStatus(String caseId) {
    String cleanCaseId = caseId.trim().toUpperCase();
    _statusListeners[cleanCaseId]?.cancel();
    _statusListeners.remove(cleanCaseId);
    print('🛑 Stopped listening for: $cleanCaseId');
  }

  /// Stop all active listeners
  static void stopAllListeners() {
    for (var subscription in _statusListeners.values) {
      subscription.cancel();
    }
    _statusListeners.clear();
    print('🛑 Stopped all status listeners');
  }

  /// Get human-readable status message
  static String getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Your report has been received and is being reviewed';
      case 'under_review':
      case 'underreview':
        return 'Your report is currently under review by our team';
      case 'reviewed':
        return 'Your report has been reviewed and is being processed';
      case 'investigating':
        return 'Your report is being actively investigated';
      case 'requires_follow_up':
      case 'requiresfollowup':
        return 'Additional information may be required for your report';
      case 'resolved':
        return 'Your report has been resolved';
      case 'closed':
        return 'Your report has been closed';
      default:
        return 'Your report status is being updated';
    }
  }

  /// Get status color for UI
  static String getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'orange';
      case 'under_review':
      case 'underreview':
      case 'investigating':
        return 'blue';
      case 'reviewed':
        return 'green';
      case 'requires_follow_up':
      case 'requiresfollowup':
        return 'yellow';
      case 'resolved':
        return 'green';
      case 'closed':
        return 'gray';
      default:
        return 'orange';
    }
  }

  /// Check if device is online
  static Future<bool> _isOnline() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      return false;
    }
  }

  /// Validate case ID format
  static bool isValidCaseId(String caseId) {
    String cleanId = caseId.trim().toUpperCase();
    // Safe Voice case IDs should start with 'SV' followed by 8 characters
    RegExp regExp = RegExp(r'^SV[A-Z0-9]{8}$');
    return regExp.hasMatch(cleanId);
  }

  /// Format case ID properly
  static String formatCaseId(String caseId) {
    return caseId.trim().toUpperCase();
  }
}
