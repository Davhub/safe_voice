import 'package:flutter/material.dart';
import 'package:safe_voice/views/views.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/routing/app_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safe_voice/models/report.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hello, there!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Action Grid (2x2)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 15,
              crossAxisSpacing: 15,
              childAspectRatio: 0.85, // Adjust for card height
              children: [
                // Create a Report Card
                _buildGridCard(
                  icon: Icons.edit_note,
                  title: 'Report a Case',
                  subtitle: 'Submit an anonymous report',
                  color: AppColors.primary,
                  onTap: () => _showCaseTypeSelectionModal(context),
                ),

                // Learn about FGM Card
                _buildGridCard(
                  icon: Icons.school,
                  title: 'Learn about FGM',
                  subtitle: 'Information and Resources',
                  color: AppColors.secondary,
                  onTap: () {
                    final tabNav = TabNavigationProvider.of(context);
                    if (tabNav != null) {
                      tabNav.switchToTab(2); // Switch to Learn tab (index 2)
                    }
                  },
                ),

                // Check Report Status Card
                _buildGridCard(
                  icon: Icons.search,
                  title: 'Check Report Status',
                  subtitle: 'Track your anonymous report',
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CheckStatusScreen(),
                      ),
                    );
                  },
                ),

                // Book a Session Card
                _buildGridCard(
                  icon: Icons.support,
                  title: 'Book a Session',
                  subtitle: 'For Counselling and Psychosocial support',
                  color: AppColors.primary,
                  onTap: () async {
                    // Open WhatsApp with pre-filled message
                    await _launchURL(
                      'https://wa.me/2348032386064?text=Hello%2C%20I%20need%20help%20regarding%20FGM%20support.',
                      context,
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Emergency Quick Actions Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Emergency Support',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildQuickActionButton(
                        icon: Icons.phone,
                        label: 'Call Help',
                        onTap: () async {
                          await _launchURL('tel:+2348131849423', context);
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.message,
                        label: 'Text Help',
                        onTap: () async {
                          // Open WhatsApp with pre-filled message
                          await _launchURL(
                            'https://wa.me/2348032386064?text=Hello%2C%20I%20need%20help%20regarding%20FGM%20support.',
                            context,
                          );
                        },
                      ),
                      _buildQuickActionButton(
                        icon: Icons.location_on,
                        label: 'Find Center',
                        onTap: () async {
                          await _launchURL(
                            'https://trailblazerinitiative.org.ng/contact/',
                            context,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // Community Impact Section
            // Card(
            //   color: AppColors.card,
            //   shape: RoundedRectangleBorder(
            //     borderRadius: BorderRadius.circular(16),
            //   ),
            //   elevation: 2,
            //   child: Padding(
            //     padding: const EdgeInsets.all(20.0),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         const Row(
            //           children: [
            //             Icon(Icons.trending_up, color: AppColors.primary),
            //             SizedBox(width: 8),
            //             Text(
            //               'Community Impact',
            //               style: TextStyle(
            //                 fontSize: 18,
            //                 fontWeight: FontWeight.bold,
            //                 color: AppColors.textPrimary,
            //               ),
            //             ),
            //           ],
            //         ),
            //         const SizedBox(height: 16),
            //         Row(
            //           mainAxisAlignment: MainAxisAlignment.spaceAround,
            //           children: [
            //             _buildStatItem('Reports Filed', '1,247', Icons.report),
            //             _buildStatItem('Lives Helped', '892', Icons.favorite),
            //             _buildStatItem('Active Cases', '156', Icons.pending),
            //           ],
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            const SizedBox(height: 25),

            // Safety Tips Section
            SizedBox(
              height: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'Safety Tips',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _safetyTips.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _safetyTips[index]['title']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Text(
                                  _safetyTips[index]['tip']!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Additional content can be added here for future enhancements
          ],
        ),
      ),
      // bottomNavigationBar removed; handled by shell
    );
  }

  /// Build a grid card widget for the main actions
  Widget _buildGridCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: AppColors.textOnPrimary),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                    height: 1.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildEducationCard(int index) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                // Placeholder for an image
                child: const Center(
                  child: Icon(Icons.image, size: 50, color: Colors.grey),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic $index',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Short description of the topic.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to launch URL with comprehensive error handling
  Future<void> _launchURL(String url, BuildContext context) async {
    try {
      final Uri uri = Uri.parse(url);

      // First, try the simplest approach
      if (await launchUrl(uri)) {
        return; // Success
      }

      // Fallback 1: Try with external application mode
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return; // Success
      }

      // Fallback 2: Try with platform default mode
      if (await launchUrl(uri, mode: LaunchMode.platformDefault)) {
        return; // Success
      }

      // If all methods fail, show error
      throw Exception('Could not launch $url');
    } catch (e) {
      debugPrint('URL Launch Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Build quick action button for emergency section
  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show case type selection modal before navigating to report screen
  void _showCaseTypeSelectionModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.report_problem_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Report Type',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please choose the type of incident you want to report',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                // Case Type Options
                _buildCaseTypeOption(
                  context: context,
                  dialogContext: dialogContext,
                  caseType: CaseType.FGM,
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFE91E63),
                  description: 'Female Genital Mutilation',
                ),
                const SizedBox(height: 12),
                _buildCaseTypeOption(
                  context: context,
                  dialogContext: dialogContext,
                  caseType: CaseType.GBV,
                  icon: Icons.security,
                  color: const Color(0xFF673AB7),
                  description: 'Gender-Based Violence',
                ),
                const SizedBox(height: 12),
                _buildCaseTypeOption(
                  context: context,
                  dialogContext: dialogContext,
                  caseType: CaseType.SEXUAL_ASSAULT,
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF9C27B0),
                  description: 'Sexual Assault',
                ),
                const SizedBox(height: 20),
                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build a single case type option in the modal
  Widget _buildCaseTypeOption({
    required BuildContext context,
    required BuildContext dialogContext,
    required CaseType caseType,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(dialogContext).pop();
        // Set the selected case type in the global notifier
        CaseTypeNotifier.instance.value = caseType;
        print(
          '🎯 Case type selected: ${caseType.displayName} (${caseType.value})',
        );
        print('📢 Notifier value set to: ${CaseTypeNotifier.instance.value}');
        // Navigate to report tab
        final tabNav = TabNavigationProvider.of(context);
        if (tabNav != null) {
          tabNav.switchToTab(1);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    caseType.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  /// Safety tips data
  static const List<Map<String, String>> _safetyTips = [
    {
      'title': 'Trust Your Instincts',
      'tip':
          'If something feels wrong, trust your gut feeling. Your safety matters most.',
    },
    {
      'title': 'Know Your Rights',
      'tip':
          'You have the right to say no to any procedure. No one can force you.',
    },
    {
      'title': 'Find Support',
      'tip':
          'Reach out to trusted friends, family, or counselors. You are not alone.',
    },
    {
      'title': 'Emergency Contacts',
      'tip':
          'Keep emergency numbers saved and easily accessible on your phone.',
    },
    {
      'title': 'Safe Spaces',
      'tip':
          'Identify safe places and people you can go to if you feel threatened.',
    },
  ];
}
