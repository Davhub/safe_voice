import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Simple Firebase connectivity test
class FirebaseConnectivityTest {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Test basic Firestore connection
  static Future<bool> testFirestoreConnection() async {
    try {
      print('🔥 Testing Firestore connection...');
      
      // Try to write a simple test document
      await _firestore.collection('test').doc('connectivity').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': 'connectivity_check',
      });
      
      print('✅ Firestore connection successful');
      
      // Clean up test document
      await _firestore.collection('test').doc('connectivity').delete();
      print('🗑️ Test document cleaned up');
      
      return true;
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      return false;
    }
  }

  /// Test Firebase Storage connection with a real file
  static Future<bool> testStorageConnection() async {
    try {
      print('📦 Testing Firebase Storage connection...');
      
      // Create a small test file
      final directory = Directory.systemTemp;
      final testFile = File('${directory.path}/test_upload.txt');
      await testFile.writeAsString('Test upload content - ${DateTime.now()}');
      
      print('📁 Created test file: ${testFile.path}');
      
      // Try to upload the file
      final ref = _storage.ref().child('test/connectivity_test.txt');
      final uploadTask = ref.putFile(testFile);
      
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('⏳ Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
      });
      
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('✅ Storage upload successful: $downloadUrl');
      
      // Clean up
      await ref.delete();
      await testFile.delete();
      print('🗑️ Test file cleaned up');
      
      return true;
    } catch (e) {
      print('❌ Storage connection failed: $e');
      return false;
    }
  }

  /// Run all connectivity tests
  static Future<Map<String, bool>> runAllTests() async {
    print('🚀 Starting Firebase connectivity tests...\n');
    
    final results = <String, bool>{};
    
    // Test Firestore
    results['firestore'] = await testFirestoreConnection();
    print('');
    
    // Test Storage
    results['storage'] = await testStorageConnection();
    print('');
    
    // Print summary
    print('📊 Test Results:');
    results.forEach((test, passed) {
      print('  ${passed ? '✅' : '❌'} $test: ${passed ? 'PASSED' : 'FAILED'}');
    });
    
    final allPassed = results.values.every((result) => result);
    print('\n${allPassed ? '🎉' : '⚠️'} Overall: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}');
    
    return results;
  }
}
