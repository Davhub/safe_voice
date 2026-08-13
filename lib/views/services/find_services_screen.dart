import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/models/service_provider.dart';
import 'package:safe_voice/services/native_location_service.dart';

class FindServicesScreen extends StatefulWidget {
  final bool showBack;
  const FindServicesScreen({Key? key, this.showBack = true}) : super(key: key);

  @override
  State<FindServicesScreen> createState() => _FindServicesScreenState();
}

class _FindServicesScreenState extends State<FindServicesScreen> {
  double? _userLat;
  double? _userLng;
  bool _locationResolved = false;
  String? _selectedState; // null = All States

  @override
  void initState() {
    super.initState();
    _resolveUserLocation();
  }

  /// Reuses the same native location channel the report flow already
  /// requests permission for — NativeLocationService only exposes a
  /// human-readable address, but the native side embeds raw coordinates in
  /// it as "... (lat, lng)", same as what's shown in the report screen.
  Future<void> _resolveUserLocation() async {
    try {
      final hasPermission =
          await NativeLocationService.requestLocationPermission();
      if (!hasPermission) {
        setState(() => _locationResolved = true);
        return;
      }
      final address = await NativeLocationService.getCurrentLocationAddress();
      final match = RegExp(
        r'\(([-\d.]+),\s*([-\d.]+)\)',
      ).firstMatch(address);
      if (match != null) {
        setState(() {
          _userLat = double.tryParse(match.group(1)!);
          _userLng = double.tryParse(match.group(2)!);
          _locationResolved = true;
        });
      } else {
        setState(() => _locationResolved = true);
      }
    } catch (_) {
      setState(() => _locationResolved = true);
    }
  }

  double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180);

  List<MapEntry<ServiceProvider, double?>> _sortedByDistance(
    List<ServiceProvider> services,
  ) {
    final withDistance =
        services.map((s) {
          double? distance;
          if (_userLat != null &&
              _userLng != null &&
              s.latitude != null &&
              s.longitude != null) {
            distance = _distanceKm(_userLat!, _userLng!, s.latitude!, s.longitude!);
          }
          return MapEntry(s, distance);
        }).toList();

    withDistance.sort((a, b) {
      if (a.value == null && b.value == null) return 0;
      if (a.value == null) return 1;
      if (b.value == null) return -1;
      return a.value!.compareTo(b.value!);
    });
    return withDistance;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBack,
        title: const Text('Find Services'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('services')
                .where('isActive', isEqualTo: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !_locationResolved) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading services: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      size: 72,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No services listed yet',
                      style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          var services =
              docs.map((doc) => ServiceProvider.fromFirestore(doc)).toList();

          final availableStates =
              services.map((s) => s.state).where((s) => s.isNotEmpty).toSet().toList()
                ..sort();

          if (_selectedState != null) {
            services = services.where((s) => s.state == _selectedState).toList();
          }

          final sorted = _sortedByDistance(services);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (availableStates.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String?>(
                    value: _selectedState,
                    decoration: InputDecoration(
                      labelText: 'Filter by State',
                      prefixIcon: const Icon(Icons.map_outlined),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All States'),
                      ),
                      ...availableStates.map(
                        (state) => DropdownMenuItem<String?>(
                          value: state,
                          child: Text(state),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() => _selectedState = value),
                  ),
                ),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 56,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No services in $_selectedState yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              if (_userLat == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enable location to see services closest to you first.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ...sorted.map(
                (entry) => _ServiceCard(service: entry.key, distanceKm: entry.value),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceProvider service;
  final double? distanceKm;

  const _ServiceCard({required this.service, this.distanceKm});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  service.organizationName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        distanceKm! < 1
                            ? '${(distanceKm! * 1000).round()} m'
                            : '${distanceKm!.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            service.organizationType,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.location_on_outlined, text: service.address),
          const SizedBox(height: 6),
          _InfoRow(icon: Icons.groups_outlined, text: 'Serves: ${service.ageRange}'),
          if (service.serviceTypes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  service.serviceTypes
                      .map(
                        (type) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionChip(
                icon: Icons.call_outlined,
                label: service.contactNumber,
                onTap: () => _launch('tel:${service.contactNumber}'),
              ),
              if (service.website != null && service.website!.isNotEmpty)
                _ActionChip(
                  icon: Icons.language_outlined,
                  label: 'Website',
                  onTap: () => _launch(service.website!),
                ),
              if (service.socialMediaHandle != null &&
                  service.socialMediaHandle!.isNotEmpty)
                _ActionChip(
                  icon: Icons.share_outlined,
                  label: service.socialMediaHandle!,
                  onTap: null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
