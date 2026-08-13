import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/models/service_provider.dart';

/// Admin CRUD for the Find Services directory (lib/models/service_provider.dart).
class ServiceDirectoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'services';

  static Stream<List<ServiceProvider>> streamAll() {
    return _firestore
        .collection(_collection)
        .orderBy('organizationName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ServiceProvider.fromFirestore(doc))
                  .toList(),
        );
  }

  static Future<String> create(ServiceProvider service) async {
    final doc = await _firestore.collection(_collection).add(service.toMap());
    return doc.id;
  }

  static Future<void> update(String id, ServiceProvider service) async {
    await _firestore.collection(_collection).doc(id).update(service.toMap());
  }

  static Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  static Future<void> setActive(String id, bool isActive) async {
    await _firestore.collection(_collection).doc(id).update({
      'isActive': isActive,
    });
  }
}
