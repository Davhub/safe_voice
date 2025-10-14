import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/firebase_options.dart';

/// Run this script once (flutter run -t lib/admin/setup/create_admin.dart -d chrome)
/// to create the initial admin user in Firebase Auth and Firestore `admins` collection.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const email = 'admin@safevoice.com';
  const password = 'SafeVoice2024!';
  const name = 'System Administrator';

  try {
    UserCredential cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
    final uid = cred.user?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('admins').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'Administrator',
        'created_at': FieldValue.serverTimestamp(),
        'permissions': ['view_reports','update_reports','delete_reports','manage_admins'],
        'is_active': true,
      });
      print('Admin created: $email (uid: $uid)');
    } else {
      print('Failed to create admin user');
    }
  } catch (e) {
    print('Error creating admin: $e');
  }
}
