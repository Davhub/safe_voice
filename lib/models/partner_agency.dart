import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kUrgencyLevels = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

/// 'ALL' is a wildcard meaning "every case type" — for partners who handle
/// multi-sectoral cases, so admins don't have to pick every enum value by
/// hand to grant broad access.
const String kAllCaseTypes = 'ALL';
const List<String> kCaseTypeOptions = ['FGM', 'SEXUAL_ASSAULT', 'GBV'];

const List<String> kNotificationChannels = ['email', 'sms', 'whatsapp'];

class PartnerAgency {
  final String id;
  final String organizationName;
  final String contactPersonName;
  final String phone;
  final String email;
  final String? address;

  /// Which report urgency levels trigger a notification to this partner.
  final List<String> urgencyLevels;

  /// Which report case types trigger a notification to this partner.
  /// Contains [kAllCaseTypes] instead of individual values for
  /// multi-sectoral partners.
  final List<String> caseTypes;

  /// Which channels to notify this partner through.
  final List<String> channels;

  final bool isActive;

  PartnerAgency({
    required this.id,
    required this.organizationName,
    required this.contactPersonName,
    required this.phone,
    required this.email,
    this.address,
    required this.urgencyLevels,
    required this.caseTypes,
    required this.channels,
    this.isActive = true,
  });

  bool get handlesAllCaseTypes => caseTypes.contains(kAllCaseTypes);

  bool matches({required String urgency, required String caseType}) {
    if (!isActive) return false;
    if (!urgencyLevels.contains(urgency.toUpperCase())) return false;
    if (handlesAllCaseTypes) return true;
    return caseTypes.contains(caseType.toUpperCase());
  }

  factory PartnerAgency.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PartnerAgency(
      id: doc.id,
      organizationName: data['organizationName'] ?? '',
      contactPersonName: data['contactPersonName'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'] ?? '',
      address: data['address'],
      urgencyLevels: List<String>.from(data['urgencyLevels'] ?? const []),
      caseTypes: List<String>.from(data['caseTypes'] ?? const []),
      channels: List<String>.from(data['channels'] ?? const []),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationName': organizationName,
      'contactPersonName': contactPersonName,
      'phone': phone,
      'email': email,
      'address': address,
      'urgencyLevels': urgencyLevels,
      'caseTypes': caseTypes,
      'channels': channels,
      'isActive': isActive,
    };
  }
}
