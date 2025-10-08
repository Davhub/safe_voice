import 'dart:async';
import 'package:flutter/services.dart';

class NativeLocationService {
  static const MethodChannel _channel = MethodChannel('safe_voice/location');
  
  /// Get current location with human-readable address
  static Future<String> getCurrentLocationAddress() async {
    try {
      // Try to get location with address from native platform
      final result = await _channel.invokeMethod('getCurrentLocationWithAddress');
      if (result != null && result.isNotEmpty) {
        return result as String;
      }
      return 'Unable to detect location';
    } on PlatformException catch (e) {
      print('Location error: ${e.message}');
      if (e.code == 'PERMISSION_DENIED') {
        return 'Location permission denied';
      } else if (e.code == 'LOCATION_DISABLED') {
        return 'Location services disabled';
      }
      return 'Unable to detect location';
    } catch (e) {
      print('Unexpected location error: $e');
      return 'Unable to detect location';
    }
  }
  
  /// Request location permissions
  static Future<bool> requestLocationPermission() async {
    try {
      final result = await _channel.invokeMethod('requestLocationPermission');
      return result as bool? ?? false;
    } catch (e) {
      print('Permission request error: $e');
      return false;
    }
  }
  
  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod('isLocationServiceEnabled');
      return result as bool? ?? false;
    } catch (e) {
      print('Location service check error: $e');
      return false;
    }
  }
  
  /// Open location settings
  static Future<void> openLocationSettings() async {
    try {
      await _channel.invokeMethod('openLocationSettings');
    } catch (e) {
      print('Open settings error: $e');
    }
  }
}
