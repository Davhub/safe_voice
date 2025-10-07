import 'dart:io';
import 'package:safe_voice/services/report_service.dart';
import 'package:safe_voice/services/offline_storage_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

/// Enhanced report service with offline support and network resilience
class EnhancedReportService {
  static const Uuid _uuid = Uuid();

  /// Quick connectivity check with timeout
  static Future<bool> _quickConnectivityCheck() async {
    try {
      var connectivityResult = await Connectivity().checkConnectivity()
          .timeout(Duration(seconds: 2));
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Quick connectivity check failed: $e');
      return false; // Assume offline if check fails
    }
  }

  /// Submit a text report with offline support
  static Future<String> submitTextReport({
    required String reportText,
    String? location,
    DateTime? incidentDate,
    List<String>? attachmentPaths,
  }) async {
    String caseId = _generateCaseId();
    
    try {
      // Quick connectivity check (timeout after 2 seconds)
      bool isOnline = await _quickConnectivityCheck();
      
      if (isOnline) {
        // Try to submit directly with shorter timeout
        try {
          String submittedCaseId = await ReportService.submitTextReport(
            reportText: reportText,
            location: location,
            incidentDate: incidentDate,
            attachmentUrls: attachmentPaths,
          ).timeout(Duration(seconds: 10)); // 10 second timeout
          
          // Sync pending reports in background (don't wait)
          _syncPendingReports();
          
          return submittedCaseId;
        } catch (e) {
          // If direct submission fails, store offline
          print('Direct submission failed, storing offline: $e');
          await OfflineStorageService.storeTextReportOffline(
            caseId: caseId,
            reportText: reportText,
            location: location,
            incidentDate: incidentDate,
            attachmentPaths: attachmentPaths,
          );
          
          // Start background sync (don't wait)
          _syncPendingReports();
          
          return caseId;
        }
      } else {
        // Store offline immediately if no connection
        print('No internet connection, storing text report offline');
        await OfflineStorageService.storeTextReportOffline(
          caseId: caseId,
          reportText: reportText,
          location: location,
          incidentDate: incidentDate,
          attachmentPaths: attachmentPaths,
        );
        
        return caseId;
      }
    } catch (e) {
      // Fallback to offline storage
      print('Error in text report submission, falling back to offline: $e');
      await OfflineStorageService.storeTextReportOffline(
        caseId: caseId,
        reportText: reportText,
        location: location,
        incidentDate: incidentDate,
        attachmentPaths: attachmentPaths,
      );
      
      return caseId;
    }
  }

  /// Submit a voice report with offline support
  static Future<String> submitVoiceReport({
    required File audioFile,
    String? additionalText,
    String? location,
    DateTime? incidentDate,
  }) async {
    String caseId = _generateCaseId();
    
    try {
      // Quick connectivity check (timeout after 2 seconds)
      bool isOnline = await _quickConnectivityCheck();
      
      if (isOnline) {
        // Try to submit directly with longer timeout for voice files
        try {
          String submittedCaseId = await ReportService.submitVoiceReport(
            audioFile: audioFile,
            additionalText: additionalText,
            location: location,
            incidentDate: incidentDate,
          ).timeout(Duration(seconds: 30)); // Increased timeout to 30 seconds for voice files
          
          // Sync pending reports in background (don't wait)
          _syncPendingReports();
          
          return submittedCaseId;
        } catch (e) {
          // If direct submission fails, store offline
          print('Direct voice submission failed, storing offline: $e');
          await OfflineStorageService.storeVoiceReportOffline(
            caseId: caseId,
            audioFilePath: audioFile.path,
            additionalText: additionalText,
            location: location,
            incidentDate: incidentDate,
          );
          
          // Start background sync (don't wait)
          _syncPendingReports();
          
          return caseId;
        }
      } else {
        // Store offline immediately if no connection
        print('No internet connection, storing voice report offline');
        await OfflineStorageService.storeVoiceReportOffline(
          caseId: caseId,
          audioFilePath: audioFile.path,
          additionalText: additionalText,
          location: location,
          incidentDate: incidentDate,
        );
        
        return caseId;
      }
    } catch (e) {
      // Fallback to offline storage
      print('Error in voice report submission, falling back to offline: $e');
      await OfflineStorageService.storeVoiceReportOffline(
        caseId: caseId,
        audioFilePath: audioFile.path,
        additionalText: additionalText,
        location: location,
        incidentDate: incidentDate,
      );
      
      return caseId;
    }
  }

  /// Sync pending reports when network becomes available
  static Future<void> _syncPendingReports() async {
    try {
      if (!await OfflineStorageService.isOnline()) {
        print('Device is offline, skipping sync');
        return;
      }

      List<Map<String, dynamic>> pendingReports = await OfflineStorageService.getPendingReports();
      
      if (pendingReports.isEmpty) {
        print('No pending reports to sync');
        return;
      }

      print('Syncing ${pendingReports.length} pending reports...');

      for (Map<String, dynamic> report in pendingReports) {
        try {
          String caseId = report['caseId'];
          int retryCount = report['retryCount'] ?? 0;
          
          // Skip reports that have failed too many times
          if (retryCount > 5) {
            print('Skipping report $caseId - too many retries ($retryCount)');
            continue;
          }

          bool success = false;
          
          if (report['type'] == 'text') {
            // Sync text report
            List<String>? attachments;
            if (report['attachmentPaths'] != null) {
              attachments = List<String>.from(report['attachmentPaths']);
            }
            
            await ReportService.submitTextReport(
              reportText: report['reportText'] ?? '',
              location: report['location'],
              incidentDate: report['incidentDate'] != null ? 
                DateTime.parse(report['incidentDate']) : null,
              attachmentUrls: attachments,
            );
            success = true;
            
          } else if (report['type'] == 'voice') {
            // Sync voice report
            String audioPath = report['audioFilePath'];
            File audioFile = File(audioPath);
            
            if (await audioFile.exists()) {
              await ReportService.submitVoiceReport(
                audioFile: audioFile,
                additionalText: report['additionalText'],
                location: report['location'],
                incidentDate: report['incidentDate'] != null ? 
                  DateTime.parse(report['incidentDate']) : null,
              );
              success = true;
            } else {
              print('Audio file not found for report $caseId: $audioPath');
              // Remove the report since file is missing
              await OfflineStorageService.removePendingReport(caseId);
              continue;
            }
          }

          if (success) {
            // Remove successfully synced report
            await OfflineStorageService.removePendingReport(caseId);
            print('Successfully synced report: $caseId');
          }

        } catch (e) {
          // Update retry count for failed sync
          String caseId = report['caseId'];
          await OfflineStorageService.updateRetryCount(caseId, e.toString());
          print('Failed to sync report $caseId: $e');
        }
      }

      // Clean up old failed reports
      await OfflineStorageService.clearOldFailedReports();
      
    } catch (e) {
      print('Error during sync: $e');
    }
  }

  /// Start periodic sync when app launches
  static Future<void> startPeriodicSync() async {
    // Initial sync
    await _syncPendingReports();
    
    // Listen for connectivity changes  
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile || 
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet) {
        print('Network reconnected, starting sync...');
        _syncPendingReports();
      }
    });
  }

  /// Get pending reports count for UI display
  static Future<int> getPendingReportsCount() async {
    return await OfflineStorageService.getPendingReportsCount();
  }

  /// Get storage statistics
  static Future<Map<String, int>> getOfflineStats() async {
    return await OfflineStorageService.getStorageStats();
  }

  /// Manual sync trigger (for user-initiated sync)
  static Future<void> manualSync() async {
    await _syncPendingReports();
  }

  /// Generate anonymous case ID
  static String _generateCaseId() {
    String uuid = _uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    return 'SV$uuid';
  }

  /// Check if device is currently online
  static Future<bool> isOnline() async {
    return await OfflineStorageService.isOnline();
  }

  /// Get connectivity status string for UI
  static Future<String> getConnectivityStatus() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    
    if (connectivityResult == ConnectivityResult.wifi) {
      return 'WiFi';
    } else if (connectivityResult == ConnectivityResult.mobile) {
      return 'Mobile Data';
    } else if (connectivityResult == ConnectivityResult.ethernet) {
      return 'Ethernet';
    } else {
      return 'Offline';
    }
  }
}
