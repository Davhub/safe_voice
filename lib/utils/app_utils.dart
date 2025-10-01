import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:safe_voice/constants/app_constants.dart';

/// Utility functions for the Safe Voice app
class AppUtils {
  /// Generate a random case ID
  static String generateCaseId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final codeUnits = List.generate(
      AppConstants.caseIdLength,
      (index) => chars.codeUnitAt(random.nextInt(chars.length)),
    );
    return '${AppConstants.caseIdPrefix}${String.fromCharCodes(codeUnits)}';
  }
  
  /// Validate case ID format
  static bool isValidCaseId(String caseId) {
    if (caseId.isEmpty) return false;
    if (!caseId.startsWith(AppConstants.caseIdPrefix)) return false;
    if (caseId.length != AppConstants.caseIdPrefix.length + AppConstants.caseIdLength) return false;
    
    final idPart = caseId.substring(AppConstants.caseIdPrefix.length);
    return RegExp(r'^[A-Z0-9]+$').hasMatch(idPart);
  }
  
  /// Validate file size
  static bool isValidFileSize(File file) {
    try {
      final size = file.lengthSync();
      return size <= AppConstants.maxFileSize;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate file type
  static bool isValidFileType(String fileName) {
    final extension = getFileExtension(fileName).toLowerCase();
    return AppConstants.allowedFileTypes.contains(extension);
  }
  
  /// Get file extension from filename
  static String getFileExtension(String fileName) {
    final lastDot = fileName.lastIndexOf('.');
    if (lastDot == -1 || lastDot == fileName.length - 1) {
      return '';
    }
    return fileName.substring(lastDot);
  }
  
  /// Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  /// Format duration for display (e.g., "2:30")
  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Validate text report length
  static bool isValidReportLength(String text) {
    return text.length <= AppConstants.maxReportLength;
  }
  
  /// Truncate text to specified length
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
  
  /// Get current timestamp as string
  static String getCurrentTimestamp() {
    return DateTime.now().toIso8601String();
  }
  
  /// Check if device is online (placeholder - would need connectivity package)
  static Future<bool> isOnline() async {
    try {
      // This is a simple check - in production, use connectivity_plus package
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Sanitize text input (remove excessive whitespace, etc.)
  static String sanitizeText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  
  /// Show loading indicator state
  static bool _isLoading = false;
  static bool get isLoading => _isLoading;
  static set isLoading(bool value) => _isLoading = value;
  
  /// Debounce function for search/input
  static Timer? _debounceTimer;
  static void debounce(Duration duration, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }
}
