import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/models/partner_agency.dart';

/// Admin CRUD for partner agencies (lib/models/partner_agency.dart) — the
/// dynamic recipient list the onReportCreated Cloud Function reads instead
/// of static secret-based recipients.
class PartnerAgencyService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'partner_agencies';

  static Stream<List<PartnerAgency>> streamAll() {
    return _firestore
        .collection(_collection)
        .orderBy('organizationName')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => PartnerAgency.fromFirestore(doc))
                  .toList(),
        );
  }

  static Future<String> create(PartnerAgency partner) async {
    final doc = await _firestore.collection(_collection).add(partner.toMap());
    return doc.id;
  }

  static Future<void> update(String id, PartnerAgency partner) async {
    await _firestore.collection(_collection).doc(id).update(partner.toMap());
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
