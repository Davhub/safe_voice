import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:safe_voice/admin/screens/admin_login_screen.dart';
import 'package:safe_voice/admin/screens/admin_dashboard_screen.dart';
import 'package:safe_voice/admin/services/admin_auth_service.dart';
import 'package:safe_voice/admin/services/simple_cache_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 Initializing Admin App...');
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('✅ Firebase initialized');
  
  // Initialize cache service to prevent redundant fetching on reload
  await SimpleCacheService.initialize();
  print('✅ Cache service initialized - ready to serve cached data on reload!');
  
  runApp(const SafeVoiceAdminApp());
}

class SafeVoiceAdminApp extends StatelessWidget {
  const SafeVoiceAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Voice Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSwatch().copyWith(primary: AppColors.primary),
      ),
      home: const AdminAuthWrapper(),
    );
  }
}

class AdminAuthWrapper extends StatefulWidget {
  const AdminAuthWrapper({super.key});

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {
  bool _isAdmin = false;
  bool _initialized = false;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    AdminAuthService.initialize();
    
    _authSubscription = AdminAuthService.authStateChanges.listen((isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
        _initialized = true;
      });
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _isAdmin ? const AdminDashboardScreen() : const AdminLoginScreen();
  }
}
