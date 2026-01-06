import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBack;
  const SettingsScreen({Key? key, this.showBack = true}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isQuickExitEnabled = true;
  bool _isNotificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        children: [


          // General Section
          const Text(
            'General',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.support_agent, color: AppColors.primary),
                  title: const Text('Contact Support'),
                ),

                const Divider(height: 1, indent: 16, endIndent: 16),
               
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('App Version'),
                  onTap: () {
                    // TODO: Navigate to an "About" page
                  },
                ),
                
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('Privacy Policy'),
                  onTap: () {
                    // TODO: Navigate to an "About" page
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.note, color: AppColors.primary),
                  title: const Text('Terms of Service'),
                  onTap: () {
                    // TODO: Navigate to an "About" page
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}