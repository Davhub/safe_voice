import 'package:flutter/material.dart';
import 'package:safe_voice/admin/services/service_directory_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/models/service_provider.dart';

/// Admin CRUD screen for the Find Services directory — the reporter-facing
/// mobile app reads this same 'services' collection read-only.
///
/// This is embedded as dashboard tab content inside a SingleChildScrollView,
/// same as every other admin tab — it must NOT be a Scaffold (that assumes
/// bounded/fixed screen constraints, which it doesn't get here) and any
/// internal ListView needs shrinkWrap + NeverScrollableScrollPhysics so it
/// doesn't fight the outer scroll view for unbounded height.
class ServicesManagementScreen extends StatelessWidget {
  const ServicesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _openForm(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<ServiceProvider>>(
          stream: ServiceDirectoryService.streamAll(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text('Error: ${snapshot.error}'),
              );
            }
            final services = snapshot.data ?? [];
            if (services.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.handshake_outlined,
                      size: 72,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No services added yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap "Add Service" to build the Find Services directory',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                return _ServiceCard(
                  service: service,
                  onEdit: () => _openForm(context, existing: service),
                  onDelete: () => _confirmDelete(context, service),
                  onToggleActive:
                      (value) =>
                          ServiceDirectoryService.setActive(service.id, value),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _openForm(BuildContext context, {ServiceProvider? existing}) {
    showDialog(
      context: context,
      builder: (_) => _ServiceFormDialog(existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, ServiceProvider service) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete service?'),
            content: Text(
              'Remove "${service.organizationName}" from the Find Services directory? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  ServiceDirectoryService.delete(service.id);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceProvider service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    service.organizationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: service.isActive,
                  activeColor: AppColors.primary,
                  onChanged: onToggleActive,
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.red,
                  ),
                  onPressed: onDelete,
                ),
              ],
            ),
            Text(
              service.state.isNotEmpty
                  ? '${service.organizationType} · ${service.state}'
                  : service.organizationType,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    service.address,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone_outlined, size: 16),
                const SizedBox(width: 6),
                Text(service.contactNumber, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.groups_outlined, size: 16),
                const SizedBox(width: 6),
                Text(service.ageRange, style: const TextStyle(fontSize: 13)),
              ],
            ),
            if (service.serviceTypes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children:
                    service.serviceTypes
                        .map(
                          (type) => Chip(
                            label: Text(type, style: const TextStyle(fontSize: 11)),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceFormDialog extends StatefulWidget {
  final ServiceProvider? existing;
  const _ServiceFormDialog({this.existing});

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactController;
  late final TextEditingController _websiteController;
  late final TextEditingController _socialController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  late String _organizationType;
  late String? _state;
  late String _ageRange;
  late Set<String> _selectedServiceTypes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(
      text: existing?.organizationName ?? '',
    );
    _addressController = TextEditingController(text: existing?.address ?? '');
    _contactController = TextEditingController(
      text: existing?.contactNumber ?? '',
    );
    _websiteController = TextEditingController(text: existing?.website ?? '');
    _socialController = TextEditingController(
      text: existing?.socialMediaHandle ?? '',
    );
    _latController = TextEditingController(
      text: existing?.latitude?.toString() ?? '',
    );
    _lngController = TextEditingController(
      text: existing?.longitude?.toString() ?? '',
    );
    _organizationType = existing?.organizationType ?? kOrganizationTypes.first;
    _state =
        (existing?.state.isNotEmpty ?? false) ? existing!.state : null;
    _ageRange = existing?.ageRange ?? kAgeRangeOptions.last;
    _selectedServiceTypes = {...(existing?.serviceTypes ?? [])};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _websiteController.dispose();
    _socialController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_state == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a state')));
      return;
    }
    setState(() => _saving = true);

    final service = ServiceProvider(
      id: widget.existing?.id ?? '',
      organizationName: _nameController.text.trim(),
      organizationType: _organizationType,
      state: _state!,
      address: _addressController.text.trim(),
      contactNumber: _contactController.text.trim(),
      serviceTypes: _selectedServiceTypes.toList(),
      ageRange: _ageRange,
      website:
          _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
      socialMediaHandle:
          _socialController.text.trim().isEmpty
              ? null
              : _socialController.text.trim(),
      latitude: double.tryParse(_latController.text.trim()),
      longitude: double.tryParse(_lngController.text.trim()),
      isActive: widget.existing?.isActive ?? true,
    );

    try {
      if (widget.existing != null) {
        await ServiceDirectoryService.update(widget.existing!.id, service);
      } else {
        await ServiceDirectoryService.create(service);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Service' : 'Edit Service'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Organization / Association Name *',
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _organizationType,
                  decoration: const InputDecoration(
                    labelText: 'Type of Organization *',
                  ),
                  items:
                      kOrganizationTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                  onChanged:
                      (v) => setState(() => _organizationType = v ?? _organizationType),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _state,
                  decoration: const InputDecoration(labelText: 'State *'),
                  items:
                      kNigerianStates
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _state = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Address *'),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number *',
                  ),
                  keyboardType: TextInputType.phone,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _ageRange,
                  decoration: const InputDecoration(labelText: 'Age Range Served'),
                  items:
                      kAgeRangeOptions
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _ageRange = v ?? _ageRange),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Type of Service Rendered',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      kServiceTypeOptions.map((type) {
                        final selected = _selectedServiceTypes.contains(type);
                        return FilterChip(
                          label: Text(type, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedServiceTypes.add(type);
                              } else {
                                _selectedServiceTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  decoration: const InputDecoration(
                    labelText: 'Website (optional)',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _socialController,
                  decoration: const InputDecoration(
                    labelText: 'Social Media Handle (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Coordinates (optional — enables "closest to you" sorting)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child:
              _saving
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Save'),
        ),
      ],
    );
  }
}
