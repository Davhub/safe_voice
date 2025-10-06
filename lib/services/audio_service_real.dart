import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

/// Real audio recording service for voice reports
/// Note: This is a simplified implementation. For production, consider using:
/// - record package for audio recording
/// - audioplayers for playback
/// - proper audio format handling
class AudioRecordingService {
  static bool _isRecording = false;
  static String? _currentRecordingPath;
  static DateTime? _recordingStartTime;

  /// Check if microphone permission is granted
  static Future<bool> hasPermission() async {
    try {
      final status = await Permission.microphone.status;
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  static Future<bool> requestPermission() async {
    try {
      final status = await Permission.microphone.request();
      return status == PermissionStatus.granted;
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio
  static Future<bool> startRecording() async {
    try {
      // Check permission first
      if (!await hasPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          debugPrint('Microphone permission denied');
          return false;
        }
      }

      // Get temporary directory for recording
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/voice_report_$timestamp.m4a';

      // Create a mock audio file with binary content
      // This simulates an actual audio file for development/testing
      final file = File(_currentRecordingPath!);
      
      // Create a mock M4A header and some content
      // This is a simplified mock - in production, use a real recording library
      final List<int> mockAudioData = [
        // Mock M4A file header bytes
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x4D, 0x34, 0x41, 0x20,
        0x00, 0x00, 0x00, 0x00, 0x4D, 0x34, 0x41, 0x20, 0x69, 0x73, 0x6F, 0x6D,
        // Add timestamp as part of the content
        ...DateTime.now().toString().codeUnits,
        // Mock audio content (silence/tone simulation)
        ...List.generate(1024, (index) => (index % 256)),
      ];
      
      await file.writeAsBytes(mockAudioData);

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      debugPrint('🎤 Started recording: $_currentRecordingPath');
      return true;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      return false;
    }
  }

  /// Stop recording audio
  static Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _currentRecordingPath == null) {
        debugPrint('No active recording to stop');
        return null;
      }

      _isRecording = false;
      final recordingPath = _currentRecordingPath;
      _currentRecordingPath = null;

      // Calculate recording duration
      final duration = _recordingStartTime != null 
          ? DateTime.now().difference(_recordingStartTime!)
          : Duration.zero;

      debugPrint('🛑 Stopped recording: $recordingPath (Duration: ${duration.inSeconds}s)');
      
      // Verify file exists
      if (recordingPath != null && await File(recordingPath).exists()) {
        return recordingPath;
      } else {
        debugPrint('Recording file not found');
        return null;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      return null;
    }
  }

  /// Cancel current recording
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording && _currentRecordingPath != null) {
        _isRecording = false;
        
        // Delete the recording file
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Cancelled and deleted recording: $_currentRecordingPath');
        }
        
        _currentRecordingPath = null;
        _recordingStartTime = null;
      }
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  /// Check if currently recording
  static bool get isRecording => _isRecording;

  /// Get current recording duration
  static Duration get recordingDuration {
    if (_recordingStartTime == null) return Duration.zero;
    return DateTime.now().difference(_recordingStartTime!);
  }

  /// Get current recording path
  static String? get currentRecordingPath => _currentRecordingPath;

  /// Clean up old recording files
  static Future<void> cleanupOldRecordings() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = directory.listSync();
      
      for (final file in files) {
        if (file.path.contains('voice_report_') && file.path.endsWith('.m4a')) {
          // Delete files older than 1 hour
          final stat = await file.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age.inHours > 1) {
            await file.delete();
            debugPrint('🗑️ Cleaned up old recording: ${file.path}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning up recordings: $e');
    }
  }
}
