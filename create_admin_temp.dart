import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:safe_voice/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  try {
    print('🔄 Attempting to sign in admin...');
    
    // Sign in with existing admin
    UserCredential result = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: 'admin@safevoice.com',
      password: 'SafeVoice2024!',
    );
    
    print('✅ Admin signed in: ${result.user!.uid}');
    
    // Create admin document with correct UID
    await FirebaseFirestore.instance.collection('admins').doc(result.user!.uid).set({
      'name': 'System Administrator',
      'email': 'admin@safevoice.com',
      'role': 'Administrator',
      'created_at': FieldValue.serverTimestamp(),
      'is_active': true,
      'permissions': ['view_reports', 'update_reports', 'delete_reports'],
    });
    
    print('✅ Admin document created for UID: ${result.user!.uid}');
    print('🎯 You can now login to the admin dashboard!');
    
  } catch (e) {
    print('❌ Error: $e');
    print('💡 Make sure you created the admin user in Firebase Console first');
  }
}