import 'package:cloud_firestore/cloud_firestore.dart';

/// Common organization type categories shown in the admin form dropdown.
/// Kept as plain strings (not an enum) so admins can still type a custom
/// value that isn't in this starter list.
const List<String> kOrganizationTypes = [
  'CSO', // Civil Society Organization
  'CBO', // Community-Based Organization
  'NGO',
  'Government Agency',
  'Hospital / Health Facility',
  'Faith-Based Organization',
  'Law Enforcement',
  'Legal Aid Provider',
  'Other',
];

/// Common service categories, shown as selectable chips in the admin form.
/// Free-form strings rather than the CaseType enum — a service provider's
/// offering (e.g. "Legal Aid", "Shelter") doesn't map 1:1 onto report case
/// types, and one org can offer several.
const List<String> kServiceTypeOptions = [
  'GBV Case Management',
  'Medical / Health',
  'Legal Aid',
  'Counseling / Psychosocial Support',
  'Shelter',
  'Police / Security',
  'FGM Prevention',
  'Child Protection',
  'Economic Empowerment',
];

const List<String> kAgeRangeOptions = [
  'Children',
  'Adolescents',
  'Adults',
  'All Ages',
];

/// Nigeria's 36 states + FCT, kept as a fixed dropdown (not free text) so
/// the Find Services state filter can match on exact values instead of
/// fighting typos/variant spellings.
const List<String> kNigerianStates = [
  'Abia',
  'Adamawa',
  'Akwa Ibom',
  'Anambra',
  'Bauchi',
  'Bayelsa',
  'Benue',
  'Borno',
  'Cross River',
  'Delta',
  'Ebonyi',
  'Edo',
  'Ekiti',
  'Enugu',
  'FCT (Abuja)',
  'Gombe',
  'Imo',
  'Jigawa',
  'Kaduna',
  'Kano',
  'Katsina',
  'Kebbi',
  'Kogi',
  'Kwara',
  'Lagos',
  'Nasarawa',
  'Niger',
  'Ogun',
  'Ondo',
  'Osun',
  'Oyo',
  'Plateau',
  'Rivers',
  'Sokoto',
  'Taraba',
  'Yobe',
  'Zamfara',
];

class ServiceProvider {
  final String id;
  final String organizationName;
  final String organizationType;
  final String state;
  final String address;
  final String contactNumber;
  final List<String> serviceTypes;
  final String ageRange;
  final String? website;
  final String? socialMediaHandle;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  ServiceProvider({
    required this.id,
    required this.organizationName,
    required this.organizationType,
    required this.state,
    required this.address,
    required this.contactNumber,
    required this.serviceTypes,
    required this.ageRange,
    this.website,
    this.socialMediaHandle,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  factory ServiceProvider.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ServiceProvider(
      id: doc.id,
      organizationName: data['organizationName'] ?? '',
      organizationType: data['organizationType'] ?? 'Other',
      state: data['state'] ?? '',
      address: data['address'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      serviceTypes: List<String>.from(data['serviceTypes'] ?? const []),
      ageRange: data['ageRange'] ?? 'All Ages',
      website: data['website'],
      socialMediaHandle: data['socialMediaHandle'],
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'organizationName': organizationName,
      'organizationType': organizationType,
      'state': state,
      'address': address,
      'contactNumber': contactNumber,
      'serviceTypes': serviceTypes,
      'ageRange': ageRange,
      'website': website,
      'socialMediaHandle': socialMediaHandle,
      'latitude': latitude,
      'longitude': longitude,
      'isActive': isActive,
    };
  }
}
