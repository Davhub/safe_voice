import 'package:flutter/material.dart';
import 'package:safe_voice/admin/services/partner_agency_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/models/partner_agency.dart';

/// Admin CRUD for partner agencies — who gets notified about a new report,
/// filtered by urgency level and case type, and through which channels.
/// The onReportCreated Cloud Function reads this collection dynamically
/// instead of a fixed list of recipients.
///
/// This is embedded as dashboard tab content inside a SingleChildScrollView,
/// same as every other admin tab — it must NOT be a Scaffold (that assumes
/// bounded/fixed screen constraints, which it doesn't get here) and any
/// internal ListView needs shrinkWrap + NeverScrollableScrollPhysics so it
/// doesn't fight the outer scroll view for unbounded height.
class PartnerAgenciesScreen extends StatelessWidget {
  const PartnerAgenciesScreen({super.key});

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
            label: const Text('Add Partner'),
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<PartnerAgency>>(
          stream: PartnerAgencyService.streamAll(),
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
            final partners = snapshot.data ?? [];
            if (partners.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_add_outlined,
                      size: 72,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No partner agencies onboarded yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Reports currently notify no one until at least one active\npartner is onboarded here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: partners.length,
              itemBuilder: (context, index) {
                final partner = partners[index];
                return _PartnerCard(
                  partner: partner,
                  onEdit: () => _openForm(context, existing: partner),
                  onDelete: () => _confirmDelete(context, partner),
                  onToggleActive:
                      (value) =>
                          PartnerAgencyService.setActive(partner.id, value),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _openForm(BuildContext context, {PartnerAgency? existing}) {
    showDialog(
      context: context,
      builder: (_) => _PartnerFormDialog(existing: existing),
    );
  }

  void _confirmDelete(BuildContext context, PartnerAgency partner) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Remove partner?'),
            content: Text(
              '"${partner.organizationName}" will stop receiving report notifications immediately. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  PartnerAgencyService.delete(partner.id);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Remove', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  final PartnerAgency partner;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;

  const _PartnerCard({
    required this.partner,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  Color _urgencyColor(String level) {
    switch (level) {
      case 'CRITICAL':
        return Colors.red.shade700;
      case 'HIGH':
        return Colors.orange.shade700;
      case 'MEDIUM':
        return Colors.amber.shade600;
      default:
        return Colors.teal.shade600;
    }
  }

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
                    partner.organizationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: partner.isActive,
                  activeThumbColor: AppColors.primary,
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
              '${partner.contactPersonName} · ${partner.phone} · ${partner.email}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...partner.urgencyLevels.map(
                  (level) => Chip(
                    label: Text(
                      level,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    backgroundColor: _urgencyColor(level),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    partner.handlesAllCaseTypes
                        ? 'ALL CASE TYPES'
                        : partner.caseTypes.join(', '),
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (partner.channels.contains('email'))
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.email_outlined, size: 16),
                  ),
                if (partner.channels.contains('sms'))
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.sms_outlined, size: 16),
                  ),
                if (partner.channels.contains('whatsapp'))
                  const Icon(Icons.chat_outlined, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PartnerFormDialog extends StatefulWidget {
  final PartnerAgency? existing;
  const _PartnerFormDialog({this.existing});

  @override
  State<_PartnerFormDialog> createState() => _PartnerFormDialogState();
}

class _PartnerFormDialogState extends State<_PartnerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _orgController;
  late final TextEditingController _contactPersonController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late Set<String> _selectedUrgencyLevels;
  late Set<String> _selectedCaseTypes;
  late bool _allCaseTypes;
  late Set<String> _selectedChannels;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _orgController = TextEditingController(
      text: existing?.organizationName ?? '',
    );
    _contactPersonController = TextEditingController(
      text: existing?.contactPersonName ?? '',
    );
    _phoneController = TextEditingController(text: existing?.phone ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _addressController = TextEditingController(text: existing?.address ?? '');
    _selectedUrgencyLevels = {...(existing?.urgencyLevels ?? const [])};
    _allCaseTypes = existing?.handlesAllCaseTypes ?? false;
    _selectedCaseTypes = {
      ...(existing?.caseTypes.where((t) => t != kAllCaseTypes) ?? const []),
    };
    _selectedChannels = {...(existing?.channels ?? const [])};
  }

  @override
  void dispose() {
    _orgController.dispose();
    _contactPersonController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUrgencyLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one urgency level to notify on'),
        ),
      );
      return;
    }
    if (!_allCaseTypes && _selectedCaseTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select at least one case type, or enable "All case types"',
          ),
        ),
      );
      return;
    }
    if (_selectedChannels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one notification channel')),
      );
      return;
    }

    setState(() => _saving = true);

    final partner = PartnerAgency(
      id: widget.existing?.id ?? '',
      organizationName: _orgController.text.trim(),
      contactPersonName: _contactPersonController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address:
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
      urgencyLevels: _selectedUrgencyLevels.toList(),
      caseTypes: _allCaseTypes ? [kAllCaseTypes] : _selectedCaseTypes.toList(),
      channels: _selectedChannels.toList(),
      isActive: widget.existing?.isActive ?? true,
    );

    try {
      if (widget.existing != null) {
        await PartnerAgencyService.update(widget.existing!.id, partner);
      } else {
        await PartnerAgencyService.create(partner);
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
      title: Text(widget.existing == null ? 'Onboard Partner' : 'Edit Partner'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _orgController,
                  decoration: const InputDecoration(
                    labelText: 'Organization / Agency Name *',
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactPersonController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Person *',
                  ),
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone (E.164, e.g. +234...) *',
                  ),
                  keyboardType: TextInputType.phone,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email *'),
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Notify on urgency *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      kUrgencyLevels.map((level) {
                        final selected = _selectedUrgencyLevels.contains(level);
                        return FilterChip(
                          label: Text(level, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedUrgencyLevels.add(level);
                              } else {
                                _selectedUrgencyLevels.remove(level);
                              }
                            });
                          },
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notify on case type *',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'All (multi-sectoral)',
                          style: TextStyle(fontSize: 12),
                        ),
                        Switch(
                          value: _allCaseTypes,
                          activeThumbColor: AppColors.primary,
                          onChanged:
                              (v) => setState(() => _allCaseTypes = v),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_allCaseTypes)
                  Wrap(
                    spacing: 8,
                    children:
                        kCaseTypeOptions.map((type) {
                          final selected = _selectedCaseTypes.contains(type);
                          return FilterChip(
                            label: Text(type, style: const TextStyle(fontSize: 12)),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedCaseTypes.add(type);
                                } else {
                                  _selectedCaseTypes.remove(type);
                                }
                              });
                            },
                          );
                        }).toList(),
                  ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Notify via *',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children:
                      kNotificationChannels.map((channel) {
                        final selected = _selectedChannels.contains(channel);
                        return FilterChip(
                          label: Text(channel, style: const TextStyle(fontSize: 12)),
                          selected: selected,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedChannels.add(channel);
                              } else {
                                _selectedChannels.remove(channel);
                              }
                            });
                          },
                        );
                      }).toList(),
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
