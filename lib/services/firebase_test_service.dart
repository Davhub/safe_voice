import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service to test Firebase connectivity and basic operations
class FirebaseTestService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Test Firestore connectivity by writing a test document
  static Future<bool> testFirestoreConnection() async {
    try {
      print('🔥 Testing Firestore connection...');
      
      // Try to write a test document
      DocumentReference testDoc = _firestore.collection('test').doc('connectivity_test');
      await testDoc.set({
        'timestamp': FieldValue.serverTimestamp(),
        'message': 'Firebase connection test successful',
        'platform': 'android_simulator',
      });
      
      print('✅ Firestore write successful');
      
      // Try to read the document back
      DocumentSnapshot snapshot = await testDoc.get();
      if (snapshot.exists) {
        print('✅ Firestore read successful');
        print('📄 Test document data: ${snapshot.data()}');
        
        // Clean up test document
        await testDoc.delete();
        print('🗑️ Test document cleaned up');
        
        return true;
      } else {
        print('❌ Firestore read failed - document not found');
        return false;
      }
    } catch (e) {
      print('❌ Firestore connection test failed: $e');
      return false;
    }
  }

  /// Test Firebase Storage connectivity
  static Future<bool> testStorageConnection() async {
    try {
      print('📦 Testing Firebase Storage connection...');
      
      // Create a test file reference
      Reference testRef = _storage.ref().child('test/connectivity_test.txt');
      
      // Upload a test string
      String testContent = 'Firebase Storage connection test - ${DateTime.now()}';
      await testRef.putString(testContent);
      
      print('✅ Storage upload successful');
      
      // Download the test file
      String downloadedContent = await testRef.getData().then((data) => 
          String.fromCharCodes(data!));
      
      if (downloadedContent.contains('Firebase Storage connection test')) {
        print('✅ Storage download successful');
        print('📄 Downloaded content: $downloadedContent');
        
        // Clean up test file
        await testRef.delete();
        print('🗑️ Test file cleaned up');
        
        return true;
      } else {
        print('❌ Storage download failed - content mismatch');
        return false;
      }
    } catch (e) {
      print('❌ Storage connection test failed: $e');
      return false;
    }
  }

  /// Test creating a sample report to verify the reports collection structure
  static Future<bool> testReportSubmission() async {
    try {
      print('📝 Testing report submission...');
      
      // Create a test report
      Map<String, dynamic> testReport = {
        'caseId': 'TEST-${DateTime.now().millisecondsSinceEpoch}',
        'type': 'text',
        'content': 'This is a test report to verify Firebase connectivity',
        'location': 'Test Location',
        'incidentDate': DateTime.now(),
        'submittedAt': FieldValue.serverTimestamp(),
        'attachments': [],
        'status': 'submitted',
        'anonymous': true,
      };
      
      // Submit to reports collection
      DocumentReference reportDoc = await _firestore.collection('reports').add(testReport);
      print('✅ Test report submitted with ID: ${reportDoc.id}');
      
      // Verify the report was saved
      DocumentSnapshot snapshot = await reportDoc.get();
      if (snapshot.exists) {
        print('✅ Test report verified in database');
        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        print('📄 Report data: ${data['caseId']} - ${data['content']}');
        
        // Clean up test report
        await reportDoc.delete();
        print('🗑️ Test report cleaned up');
        
        return true;
      } else {
        print('❌ Test report verification failed');
        return false;
      }
    } catch (e) {
      print('❌ Report submission test failed: $e');
      return false;
    }
  }

  /// Run all Firebase connectivity tests
  static Future<Map<String, bool>> runAllTests() async {
    print('🚀 Starting Firebase connectivity tests...\n');
    
    Map<String, bool> results = {};
    
    // Test Firestore
    results['firestore'] = await testFirestoreConnection();
    print('');
    
    // Test Storage
    results['storage'] = await testStorageConnection();
    print('');
    
    // Test Reports collection
    results['reports'] = await testReportSubmission();
    print('');
    
    // Print summary
    print('📊 Test Results Summary:');
    results.forEach((test, passed) {
      print('  ${passed ? '✅' : '❌'} $test: ${passed ? 'PASSED' : 'FAILED'}');
    });
    
    bool allPassed = results.values.every((result) => result);
    print('\n${allPassed ? '🎉' : '⚠️'} Overall: ${allPassed ? 'ALL TESTS PASSED' : 'SOME TESTS FAILED'}');
    
    return results;
  }
}
