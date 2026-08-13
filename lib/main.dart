import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:safe_voice/admin/services/app_usage_analytics_service.dart';
import 'package:safe_voice/constants/app_colors.dart';
import 'package:safe_voice/routing/app_router.dart';
import 'package:safe_voice/routing/route_paths.dart';
import 'package:safe_voice/services/enhanced_report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart' show DefaultFirebaseOptions;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase, handling duplicate app errors gracefully
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // If Firebase is already initialized, continue silently
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized, continuing...');
    } else {
      print('Firebase initialization error: $e');
    }
  }

  // Initialize offline sync service
  try {
    await EnhancedReportService.startPeriodicSync();
    print('Offline sync service initialized successfully');
  } catch (e) {
    print('Failed to initialize offline sync: $e');
  }

  // Fire-and-forget anonymous, aggregated usage tracking for the admin
  // Analytics tab. No device identifiers or PII — see
  // AppUsageAnalyticsService's doc comment.
  unawaited(
    AppUsageAnalyticsService.incrementMetric(metricType: 'appOpen'),
  );
  unawaited(_trackActiveUserOncePerDay());
  unawaited(
    AppUsageAnalyticsService.incrementMetric(
      metricType: 'deviceType',
      deviceType: _currentDeviceType(),
    ),
  );

  runApp(const MyApp());
}

/// "Active Users" counts unique devices per day, not raw app launches
/// (that's what "App Opens" is for) — so this only increments the metric
/// once per calendar day per device, gated by a local flag. No identifier
/// is ever sent to Firestore; the date check happens entirely on-device.
Future<void> _trackActiveUserOncePerDay() async {
  final prefs = await SharedPreferences.getInstance();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final lastCountedDate = prefs.getString('last_active_user_date');

  if (lastCountedDate == today) return;

  await AppUsageAnalyticsService.incrementMetric(metricType: 'activeUser');
  await prefs.setString('last_active_user_date', today);
}

String _currentDeviceType() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'iOS';
    default:
      return 'other';
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Voice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: RoutePaths.onboarding,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
