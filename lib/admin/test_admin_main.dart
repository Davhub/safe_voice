import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:safe_voice/admin/screens/admin_login_screen.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TestSafeVoiceAdminApp());
}

class TestSafeVoiceAdminApp extends StatelessWidget {
  const TestSafeVoiceAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Safe Voice Admin - Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.fromSwatch().copyWith(primary: AppColors.primary),
      ),
      home: const TestAdminScreen(),
    );
  }
}

class TestAdminScreen extends StatelessWidget {
  const TestAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Test'),
        backgroundColor: AppColors.primary,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Admin App Test',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text('If you see this, the basic app structure works!'),
            SizedBox(height: 40),
            Text(
              'Next: Test login screen',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
          );
        },
        child: const Icon(Icons.login),
      ),
    );
  }
}
