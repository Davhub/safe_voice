import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final bool showBack;
  const SettingsScreen({Key? key, this.showBack = true}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // App version - update this when releasing new versions
  final String _appVersion = '1.0.0';
  final String _buildNumber = '1';

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
                icon: const Icon(Icons.arrow_back_ios,
                    color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Info Section
          _buildModernCard(
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Contact Support',
                  subtitle: 'Get help from our team',
                  iconColor: AppColors.primary,
                  onTap: () => _showContactSupportModal(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Legal Section
          _buildSectionHeader('Legal'),
          const SizedBox(height: 8),
          _buildModernCard(
            child: Column(
              children: [
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  iconColor: AppColors.info,
                  onTap: () => _showPrivacyPolicyModal(context),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Service',
                  subtitle: 'Our terms and conditions',
                  iconColor: AppColors.secondary,
                  onTap: () => _showTermsOfServiceModal(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 8),
          _buildModernCard(
            child: _buildSettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              subtitle: 'Version $_appVersion \n Build $_buildNumber',
              iconColor: AppColors.success,
              onTap: () => _showAppVersionModal(context),
              showTrailingIcon: false,
            ),
          ),

          const SizedBox(height: 32),

          // Footer
          Center(
            child: Text(
              'Safe Voice © ${DateTime.now().year}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildModernCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    bool showTrailingIcon = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (showTrailingIcon)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        color: AppColors.textSecondary.withOpacity(0.1),
      ),
    );
  }

  void _showContactSupportModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.support_agent_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Contact Support',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildContactCard(
                    icon: Icons.phone_rounded,
                    title: 'Phone Support',
                    value: '+234 813 184 9423',
                    color: AppColors.success,
                    onTap: () async {
                      final Uri phoneUri = Uri.parse('tel:+2348131849423');
                      if (await canLaunchUrl(phoneUri)) {
                        await launchUrl(phoneUri);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    icon: Icons.email_rounded,
                    title: 'Email Support',
                    value: 'contact@trailblazerinitiative.org.ng',
                    color: AppColors.info,
                    onTap: () async {
                      final Uri emailUri = Uri.parse('mailto:contact@trailblazerinitiative.org.ng?subject=Support Request');
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    icon: Icons.language_rounded,
                    title: 'Website',
                    value: 'www.trailblazerinitiative.org.ng',
                    color: AppColors.secondary,
                    onTap: () async {
                      final Uri webUri = Uri.parse('https://trailblazerinitiative.org.ng');
                      if (await canLaunchUrl(webUri)) {
                        await launchUrl(webUri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  // const SizedBox(height: 12),
                  // _buildContactCard(
                  //   icon: Icons.location_on_rounded,
                  //   title: 'Office Address',
                  //   value: 'Trailblazer Initiative\n123 Support Street\nAbuja, Nigeria',
                  //   color: AppColors.error,
                  //   onTap: null,
                  // ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Emergency?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.error)),
                              const SizedBox(height: 4),
                              Text('If you\'re in immediate danger, please call emergency services or your local authorities.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required String title, required String value, required Color color, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.textSecondary.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withOpacity(0.7))),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  void _showAppVersionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, 
              height: 4, 
              margin: const EdgeInsets.only(bottom: 20), 
              decoration: 
              BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3), 
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20), 
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), 
              shape: BoxShape.circle), 
            child: const Icon(
              Icons.shield_rounded, 
              size: 60, 
              color: AppColors.primary,
            ),
          ),
            const SizedBox(height: 5),
            const Text(
              'Safe Voice', 
              style: TextStyle(
                fontSize: 28, fontWeight: 
                FontWeight.bold, 
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), 
              borderRadius: BorderRadius.circular(20)), 
              child: Text(
                'Version $_appVersion', 
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600, 
                color: AppColors.success,
              ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Build $_buildNumber', 
              style: TextStyle(
                fontSize: 12, 
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card, 
                borderRadius: BorderRadius.circular(12),
              ),
              child: 
                Column(
                  children: [
                    Text(
                      'Safe Voice is your confidential platform to report cases of FGM, GBV, and Sexual Assault.', 
                      style: TextStyle(
                        fontSize: 14, 
                        color: AppColors.textSecondary, 
                      ), 
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.lock_rounded, 
                        size: 16, 
                        color: AppColors.success), 
                      const SizedBox(width: 8), 
                        Text(
                          'Secure • Anonymous • Confidential', 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.w600, 
                            color: AppColors.success
                          ),
                        ),
                      ]
                    ),
                  ],
                ),
            ),
            const SizedBox(height: 5),
            Text(
              '© ${DateTime.now().year} Trailblazer Initiative', 
              style: TextStyle(
                fontSize: 12, 
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showPrivacyPolicyModal(
    BuildContext context) {
    _showPolicyModal(
      context, 'Privacy Policy', 
      Icons.privacy_tip_rounded, AppColors.info, 
      _getPrivacyPolicyContent(),
    );
  }

  void _showTermsOfServiceModal(
    BuildContext context) {
    _showPolicyModal(
      context, 'Terms of Service', 
      Icons.description_rounded, AppColors.secondary, 
      _getTermsContent(),
    );
  }

  void _showPolicyModal(
    BuildContext context, String title, IconData icon, Color color, 
  List<Map<String, String>> sections) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.background, 
          borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Container(
                    width: 40, 
                    height: 4, 
                    margin: const EdgeInsets.only(bottom: 20), 
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.3), 
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12), 
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1), 
                          borderRadius: BorderRadius.circular(12)), 
                        child: 
                          Icon(
                            icon, 
                            color: color, 
                            size: 28,
                          ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: 
                          Text(
                            title, 
                            style: const TextStyle(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold, 
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sections.map((section) => _buildPolicySection(section['title']!, section['content']!)),
                    const SizedBox(height: 24),
                    // Container(
                    //   padding: const EdgeInsets.all(16),
                    //   decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    //   child: Row(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       Icon(Icons.info_outline, color: color, size: 20),
                    //       const SizedBox(width: 12),
                    //       Expanded(child: Text('This is a placeholder. Please replace with your organization\'s official $title.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
                    //     ],
                    //   ),
                    // ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        ],
      ),
    );
  }

  List<Map<String, String>> _getPrivacyPolicyContent() {
    return [
      {'title': 'Last Updated', 'content': 'January 15, 2026'},
      {'title': '1. Information We Collect', 'content': 'Safe Voice is committed to protecting your privacy. We collect minimal information necessary to provide our services:\n\n• Report data (text and voice recordings)\n• Device type and basic technical information\n• Anonymous usage statistics\n\nWe DO NOT collect:\n• Personal identifiable information\n• Location data\n• Contact lists or other device data'},
      {'title': '2. How We Use Your Information', 'content': 'Your information is used solely to:\n\n• Process and route your reports to appropriate authorities\n• Improve our services and user experience\n• Generate anonymous statistics for advocacy purposes\n\nWe never sell, rent, or share your data with third parties for marketing purposes.'},
      {'title': '3. Data Security', 'content': 'We employ industry-standard security measures:\n\n• End-to-end encryption for all reports\n• Secure cloud storage with Firebase\n• Regular security audits\n• Automatic data deletion after processing\n\nYour safety and privacy are our top priorities.'},
      {'title': '4. Your Rights', 'content': 'You have the right to:\n\n• Access your submitted reports\n• Request deletion of your data\n• Opt-out of analytics collection\n• Contact us with privacy concerns'},
      {'title': 'Contact Us', 'content': 'For privacy-related questions, contact us at:\ncontact@trailblazerinitiative.org.ng'},
    ];
  }

  List<Map<String, String>> _getTermsContent() {
    return [
      {'title': 'Last Updated', 'content': 'January 15, 2026'},
      {'title': '1. Acceptance of Terms', 'content': 'By accessing and using Safe Voice ("the App"), you accept and agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.'},
      {'title': '2. Service Description', 'content': 'Safe Voice provides a confidential platform for reporting cases of Female Genital Mutilation (FGM), Gender-Based Violence (GBV), and Sexual Assault. The App facilitates anonymous reporting to appropriate authorities and support organizations.'},
      {'title': '3. User Responsibilities', 'content': 'You agree to:\n\n• Provide accurate information in your reports\n• Use the service only for its intended purpose\n• Not submit false or malicious reports\n• Respect the confidentiality of the platform\n• Not attempt to compromise the App\'s security'},
      {'title': '4. Confidentiality and Anonymity', 'content': 'While we strive to maintain your anonymity:\n\n• Reports may need to be shared with authorities for investigation\n• Complete anonymity cannot be guaranteed in legal proceedings\n• Emergency situations may require disclosure of information\n• We will always prioritize your safety'},
      {'title': '5. Disclaimer', 'content': 'Safe Voice is not a substitute for emergency services. In immediate danger, contact local authorities or emergency services directly.\n\nThe App is provided "as is" without warranties of any kind. We do not guarantee specific outcomes from submitted reports.'},
      {'title': 'Contact Information', 'content': 'For questions about these terms:\nontact@trailblazerinitiative.org.ng'},
    ];
  }
}
