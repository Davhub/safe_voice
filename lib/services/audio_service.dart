import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service for handling audio recording functionality with REAL implementation
class AudioService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static String? _currentRecordingPath;
  static bool _isRecording = false;
  static bool _isPlaying = false;

  /// Check if recording is supported on current platform
  static bool get isPlatformSupported {
    return Platform.isAndroid || Platform.isIOS;
  }

  /// Check if microphone permission is granted
  static Future<bool> checkMicrophonePermission() async {
    try {
      PermissionStatus status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    try {
      PermissionStatus status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Start recording audio (REAL IMPLEMENTATION)
  static Future<bool> startRecording() async {
    try {
      // Check permission first
      bool hasPermission = await checkMicrophonePermission();
      if (!hasPermission) {
        hasPermission = await requestMicrophonePermission();
        if (!hasPermission) {
          throw Exception('Microphone permission denied');
        }
      }

      // Check if device supports recording
      if (!await _recorder.hasPermission()) {
        print('No permission to record audio');
        return false;
      }

      // Get directory for recording
      Directory appDir = await getApplicationDocumentsDirectory();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      _currentRecordingPath = '${appDir.path}/voice_report_$timestamp.m4a';

      // Configure recording settings for high quality
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc, // AAC-LC codec for M4A
        bitRate: 128000, // 128 kbps for good quality
        sampleRate: 44100, // CD quality sample rate
        numChannels: 1, // Mono recording
      );

      // Start recording
      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = true;

      print('✅ Real audio recording started: $_currentRecordingPath');
      return true;
    } catch (e) {
      print('❌ Error starting recording: $e');
      _isRecording = false;
      return false;
    }
  }

  /// Stop recording and return the file
  static Future<File?> stopRecording() async {
    try {
      if (_isRecording) {
        final path = await _recorder.stop();
        _isRecording = false;

        if (path != null && await File(path).exists()) {
          _currentRecordingPath = path;
          final file = File(path);
          final fileSize = await file.length();
          print('✅ Real audio recording stopped: $path (${fileSize} bytes)');
          return file;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  /// Play recorded audio for preview
  static Future<void> playRecording(String filePath) async {
    try {
      if (_isPlaying) {
        await stopPlayback();
      }

      print('🔊 Playing audio: $filePath');
      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;

      // Listen for completion
      _player.onPlayerComplete.listen((_) {
        _isPlaying = false;
        print('✅ Audio playback completed');
      });
    } catch (e) {
      print('❌ Error playing recording: $e');
      _isPlaying = false;
    }
  }

  /// Stop audio playback
  static Future<void> stopPlayback() async {
    try {
      await _player.stop();
      _isPlaying = false;
      print('⏹️ Audio playback stopped');
    } catch (e) {
      print('❌ Error stopping playback: $e');
    }
  }

  /// Get recording duration in seconds
  static Future<int> getRecordingDuration(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        return 0;
      }

      // Use audio player to get duration
      await _player.setSourceDeviceFile(filePath);
      final duration = await _player.getDuration();

      if (duration != null) {
        return duration.inSeconds;
      }

      return 0;
    } catch (e) {
      print('Error getting recording duration: $e');
      // Estimate based on file size (rough approximation)
      try {
        File file = File(filePath);
        int fileSize = await file.length();
        // Estimate: ~128kbps bitrate = 16KB/second
        return (fileSize / 16000).round();
      } catch (e2) {
        return 0;
      }
    }
  }

  /// Check if currently recording
  static bool get isRecording => _isRecording;

  /// Check if currently playing
  static bool get isPlaying => _isPlaying;

  /// Get current recording path
  static String? get currentRecordingPath => _currentRecordingPath;

  /// Clean up resources
  static Future<void> dispose() async {
    try {
      await _recorder.dispose();
      await _player.dispose();
      print('🧹 Audio service disposed');
    } catch (e) {
      print('Error disposing audio service: $e');
    }
  }

  /// Delete recording file
  static Future<void> deleteRecording(String filePath) async {
    try {
      File file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('🗑️ Recording deleted: $filePath');
      }
    } catch (e) {
      print('Error deleting recording: $e');
    }
  }

  /// Format duration for display
  static String formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Check if device supports recording
  static Future<bool> isRecordingSupported() async {
    return await _recorder.hasPermission();
  }

  /// Get file size in human readable format
  static Future<String> getFileSize(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) return '0 KB';

      int bytes = await file.length();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (e) {
      print('Error getting file size: $e');
      return '0 KB';
    }
  }

  /// Get platform support status message
  static String getPlatformStatusMessage() {
    if (Platform.isAndroid) {
      return 'Android audio recording active (AAC-LC 128kbps)';
    } else if (Platform.isIOS) {
      return 'iOS audio recording active (AAC-LC 128kbps)';
    } else {
      return 'Real audio recording enabled';
    }
  }

  /// Cancel recording without saving
  static Future<void> cancelRecording() async {
    try {
      if (_isRecording) {
        await _recorder.stop();
        _isRecording = false;

        // Delete the file if it exists
        if (_currentRecordingPath != null) {
          File file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Recording cancelled and deleted');
          }
        }
        _currentRecordingPath = null;
      }
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  /// Validate audio file
  static Future<bool> validateAudioFile(String filePath) async {
    try {
      File file = File(filePath);
      if (!await file.exists()) {
        print('❌ Audio file does not exist');
        return false;
      }

      int fileSize = await file.length();
      if (fileSize < 1000) {
        print('❌ Audio file too small (${fileSize} bytes)');
        return false;
      }

      print('✅ Audio file validated: ${fileSize} bytes');
      return true;
    } catch (e) {
      print('❌ Error validating audio file: $e');
      return false;
    }
  }

  /// Clean up old recordings
  static Future<void> cleanupOldRecordings() async {
    try {
      Directory appDir = await getApplicationDocumentsDirectory();
      List<FileSystemEntity> files = appDir.listSync();

      int deletedCount = 0;
      for (var file in files) {
        if (file is File &&
            file.path.contains('voice_report_') &&
            file.path.endsWith('.m4a')) {
          // Delete files older than 7 days
          DateTime fileDate = await file.lastModified();
          DateTime now = DateTime.now();
          if (now.difference(fileDate).inDays > 7) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        print('🧹 Cleaned up $deletedCount old recordings');
      }
    } catch (e) {
      print('Error cleaning up old recordings: $e');
    }
  }
}
