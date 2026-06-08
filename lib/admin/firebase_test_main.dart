import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FirebaseTestApp());
}

class FirebaseTestApp extends StatelessWidget {
  const FirebaseTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase Test',
      home: const FirebaseTestScreen(),
    );
  }
}

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  String _status = 'Testing Firebase...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _testFirebase();
  }

  Future<void> _testFirebase() async {
    try {
      setState(() {
        _status = 'Step 1: Testing Firebase Auth...';
      });

      // Test 1: Firebase Auth
      User? currentUser = FirebaseAuth.instance.currentUser;
      String authStatus =
          currentUser != null
              ? 'User logged in: ${currentUser.email}'
              : 'No user logged in';

      setState(() {
        _status = 'Step 2: Testing Firestore...\nAuth: $authStatus';
      });

      // Test 2: Firestore connectivity
      await FirebaseFirestore.instance
          .collection('test')
          .doc('connectivity')
          .get();

      setState(() {
        _status =
            'Step 3: Testing Admin Collection...\nAuth: $authStatus\nFirestore: Connected';
      });

      // Test 3: Check admins collection
      QuerySnapshot adminQuery =
          await FirebaseFirestore.instance.collection('admins').limit(1).get();

      setState(() {
        _status = '''✅ Firebase Tests Complete!
        
Auth: $authStatus
Firestore: Connected
Admin Collection: ${adminQuery.docs.length} documents found

Admin UID Check: ${currentUser?.uid ?? 'N/A'}''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = '❌ Firebase Test Failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Connectivity Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_status, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                // Test admin login
                try {
                  UserCredential result = await FirebaseAuth.instance
                      .signInWithEmailAndPassword(
                        email: 'admin@safevoice.com',
                        password: 'admin123',
                      );
                  setState(() {
                    _status = 'Admin login successful: ${result.user?.email}';
                  });
                } catch (e) {
                  setState(() {
                    _status = 'Admin login failed: $e';
                  });
                }
              },
              child: const Text('Test Admin Login'),
            ),
          ],
        ),
      ),
    );
  }
}
