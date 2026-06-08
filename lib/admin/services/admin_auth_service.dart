import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final StreamController<bool> _authController =
      StreamController<bool>.broadcast();

  static Stream<bool> get authStateChanges => _authController.stream;

  static Future<bool> isAdmin() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        _authController.add(false);
        return false;
      }

      DocumentSnapshot adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();
      bool isAdminUser = adminDoc.exists;
      _authController.add(isAdminUser);
      return isAdminUser;
    } catch (e) {
      _authController.add(false);
      return false;
    }
  }

  static Future<String?> adminLogin(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        bool adminStatus = await isAdmin();
        if (adminStatus) return null;
        await _auth.signOut();
        return 'You do not have admin privileges';
      }
      return 'Login failed';
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  static Future<void> adminLogout() async {
    try {
      await _auth.signOut();
      _authController.add(false);
    } catch (e) {
      // Empty catch block
    }
  }

  static Future<Map<String, dynamic>?> getCurrentAdminInfo() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;
      DocumentSnapshot doc =
          await _firestore.collection('admins').doc(user.uid).get();
      if (!doc.exists) return null;
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['uid'] = user.uid;
      data['email'] = user.email;
      return data;
    } catch (e) {
      return null;
    }
  }

  static void initialize() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) async {
      if (user != null) {
        await isAdmin();
      } else {
        _authController.add(false);
      }
    });

    // Immediately check current user state
    Timer.run(() async {
      User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        await isAdmin();
      } else {
        _authController.add(false);
      }
    });
  }

  static void dispose() {
    _authController.close();
  }
}
