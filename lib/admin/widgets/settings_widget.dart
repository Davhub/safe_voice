import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/constant/colors.dart';

class SettingsWidget extends StatefulWidget {
  const SettingsWidget({super.key});

  @override
  State<SettingsWidget> createState() => _SettingsWidgetState();
}

class _SettingsWidgetState extends State<SettingsWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // System Settings
  bool _emailNotifications = true;
  bool _pushNotifications = true;
  bool _autoAssignReports = false;
  bool _requireApproval = true;
  bool _enableAuditLog = true;
  bool _maintenanceMode = false;
  
  // Security Settings
  bool _twoFactorAuth = false;
  bool _sessionTimeout = true;
  int _sessionTimeoutMinutes = 30;
  
  // Report Settings
  int _autoArchiveDays = 90;
  String _defaultPriority = 'medium';
  bool _allowAnonymousReports = true;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('admin_settings').doc('system').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _emailNotifications = data['emailNotifications'] ?? true;
          _pushNotifications = data['pushNotifications'] ?? true;
          _autoAssignReports = data['autoAssignReports'] ?? false;
          _requireApproval = data['requireApproval'] ?? true;
          _enableAuditLog = data['enableAuditLog'] ?? true;
          _maintenanceMode = data['maintenanceMode'] ?? false;
          _twoFactorAuth = data['twoFactorAuth'] ?? false;
          _sessionTimeout = data['sessionTimeout'] ?? true;
          _sessionTimeoutMinutes = data['sessionTimeoutMinutes'] ?? 30;
          _autoArchiveDays = data['autoArchiveDays'] ?? 90;
          _defaultPriority = data['defaultPriority'] ?? 'medium';
          _allowAnonymousReports = data['allowAnonymousReports'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _firestore.collection('admin_settings').doc('system').set({
        'emailNotifications': _emailNotifications,
        'pushNotifications': _pushNotifications,
        'autoAssignReports': _autoAssignReports,
        'requireApproval': _requireApproval,
        'enableAuditLog': _enableAuditLog,
        'maintenanceMode': _maintenanceMode,
        'twoFactorAuth': _twoFactorAuth,
        'sessionTimeout': _sessionTimeout,
        'sessionTimeoutMinutes': _sessionTimeoutMinutes,
        'autoArchiveDays': _autoArchiveDays,
        'defaultPriority': _defaultPriority,
        'allowAnonymousReports': _allowAnonymousReports,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          
          // Settings sections
          _buildGeneralSettings(),
          const SizedBox(height: 24),
          _buildSecuritySettings(),
          const SizedBox(height: 24),
          _buildReportSettings(),
          const SizedBox(height: 24),
          _buildNotificationSettings(),
          const SizedBox(height: 24),
          _buildSystemMaintenance(),
          const SizedBox(height: 24),
          _buildDangerZone(),
          const SizedBox(height: 24),
          
          // Save button
          _buildSaveButton(),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding:  EdgeInsets.all(24),
      decoration: BoxDecoration(
      color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Configure system preferences and security options',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return _buildSettingsCard(
      title: 'General Settings',
      icon: Icons.tune_rounded,
      color: Colors.blue,
      children: [
        _buildSwitchTile(
          'Email Notifications',
          'Receive email alerts for important events',
          _emailNotifications,
          (value) => setState(() => _emailNotifications = value),
        ),
        Divider(),
        _buildSwitchTile(
          'Push Notifications',
          'Receive push notifications on your device',
          _pushNotifications,
          (value) => setState(() => _pushNotifications = value),
        ),
        Divider(),
        _buildSwitchTile(
          'Auto-assign Reports',
          'Automatically assign new reports to available admins',
          _autoAssignReports,
          (value) => setState(() => _autoAssignReports = value),
        ),
        Divider(),
        _buildSwitchTile(
          'Require Approval',
          'Require admin approval for report status changes',
          _requireApproval,
          (value) => setState(() => _requireApproval = value),
        ),
      ],
    );
  }

  Widget _buildSecuritySettings() {
    return _buildSettingsCard(
      title: 'Security Settings',
      icon: Icons.security_rounded,
      color: Colors.red,
      children: [
        _buildSwitchTile(
          'Two-Factor Authentication',
          'Add an extra layer of security to your account',
          _twoFactorAuth,
          (value) => setState(() => _twoFactorAuth = value),
        ),
        _buildSwitchTile(
          'Session Timeout',
          'Automatically log out after period of inactivity',
          _sessionTimeout,
          (value) => setState(() => _sessionTimeout = value),
        ),
        if (_sessionTimeout) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Timeout after: '),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _sessionTimeoutMinutes.toDouble(),
                    min: 5,
                    max: 120,
                    divisions: 23,
                    label: '$_sessionTimeoutMinutes minutes',
                    onChanged: (value) => setState(() => _sessionTimeoutMinutes = value.toInt()),
                  ),
                ),
                Text('$_sessionTimeoutMinutes min'),
              ],
            ),
          ),
        ],
        _buildSwitchTile(
          'Enable Audit Log',
          'Track all admin actions and system changes',
          _enableAuditLog,
          (value) => setState(() => _enableAuditLog = value),
        ),
      ],
    );
  }

  Widget _buildReportSettings() {
    return _buildSettingsCard(
      title: 'Report Management',
      icon: Icons.report_rounded,
      color: Colors.orange,
      children: [
        _buildSwitchTile(
          'Allow Anonymous Reports',
          'Users can submit reports without creating an account',
          _allowAnonymousReports,
          (value) => setState(() => _allowAnonymousReports = value),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Default Priority Level',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _defaultPriority,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (value) => setState(() => _defaultPriority = value!),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-archive Reports',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Automatically archive resolved reports after specified days',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 100,
                child: TextField(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixText: 'days',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  keyboardType: TextInputType.number,
                  controller: TextEditingController(text: _autoArchiveDays.toString()),
                  onChanged: (value) {
                    final days = int.tryParse(value);
                    if (days != null && days > 0) {
                      setState(() => _autoArchiveDays = days);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationSettings() {
    return _buildSettingsCard(
      title: 'Notification Preferences',
      icon: Icons.notifications_rounded,
      color: Colors.green,
      children: [
        _buildInfoTile(
          'New Report Notifications',
          'Get notified when new reports are submitted',
          Icons.add_alert,
          Colors.blue,
        ),
        _buildInfoTile(
          'Status Update Notifications',
          'Get notified when report statuses change',
          Icons.update,
          Colors.orange,
        ),
        _buildInfoTile(
          'System Alerts',
          'Receive critical system and security alerts',
          Icons.warning_amber_rounded,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildSystemMaintenance() {
    return _buildSettingsCard(
      title: 'System Maintenance',
      icon: Icons.build_rounded,
      color: Colors.purple,
      children: [
        _buildSwitchTile(
          'Maintenance Mode',
          'Put system in maintenance mode (users cannot submit reports)',
          _maintenanceMode,
          (value) => setState(() => _maintenanceMode = value),
        ),
        if (_maintenanceMode)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'System is currently in maintenance mode. Users cannot submit new reports.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ListTile(
          leading: const Icon(Icons.cleaning_services, color: Colors.blue),
          title: const Text('Clear Cache'),
          subtitle: const Text('Clear system cache and temporary files'),
          trailing: ElevatedButton(
            onPressed: () => _showClearCacheDialog(),
            child: const Text('Clear'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.storage, color: Colors.green),
          title: const Text('Database Backup'),
          subtitle: const Text('Create a backup of the database'),
          trailing: ElevatedButton(
            onPressed: () => _showBackupDialog(),
            child: const Text('Backup'),
          ),
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 12),
              const Text(
                'Danger Zone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Clear All Data'),
            subtitle: const Text('Permanently delete all reports and user data'),
            trailing: ElevatedButton(
              onPressed: () => _showClearDataDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.orange),
            title: const Text('Reset to Defaults'),
            subtitle: const Text('Reset all settings to default values'),
            trailing: ElevatedButton(
              onPressed: () => _showResetDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reset'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton.icon(
        onPressed: _saveSettings,
        icon: const Icon(Icons.save),
        label: const Text('Save Settings'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Widget _buildInfoTile(String title, String subtitle, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.check_circle, color: Colors.green),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('Are you sure you want to clear the system cache? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement cache clearing
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared successfully')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Backup'),
        content: const Text('Create a backup of the current database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement backup
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup created successfully')),
              );
            },
            child: const Text('Backup'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'WARNING: This will permanently delete all reports and user data. This action cannot be undone!\n\nType "DELETE" to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Require confirmation
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Reset to defaults
              setState(() {
                _emailNotifications = true;
                _pushNotifications = true;
                _autoAssignReports = false;
                _requireApproval = true;
                _enableAuditLog = true;
                _maintenanceMode = false;
                _twoFactorAuth = false;
                _sessionTimeout = true;
                _sessionTimeoutMinutes = 30;
                _autoArchiveDays = 90;
                _defaultPriority = 'medium';
                _allowAnonymousReports = true;
              });
              Navigator.pop(context);
              _saveSettings();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
