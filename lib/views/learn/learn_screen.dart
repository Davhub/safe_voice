import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';

class LearnScreen extends StatelessWidget {
  final bool showBack;
  const LearnScreen({Key? key, this.showBack = true}) : super(key: key);

  // This is our data model for the educational topics.
  final List<Map<String, dynamic>> educationalTopics = const [
    {
      'title': 'What is FGM?',
      'subtitle': 'Learn about FGM and its impact',
      'icon': Icons.book_outlined,
      'color': AppColors.secondary, // Purple
    },
    {
      'title': 'Why it is harmful',
      'subtitle': 'Health and psychological effects',
      'icon': Icons.favorite_outline,
      'color': AppColors.error, // Red
    },
    {
      'title': 'Laws & Rights',
      'subtitle': 'Legal protections and your rights',
      'icon': Icons.balance_outlined,
      'color': AppColors.info, // Blue
    },
    {
      'title': 'How to Get Help',
      'subtitle': 'Support resources and contacts',
      'icon': Icons.help_outline,
      'color': AppColors.success, // Green
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Education Hub',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Introductory text card
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                'Learn about FGM, its impacts, and how to help prevent it. Knowledge is power.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            const SizedBox(height: 16),
            // Dynamically generated list of topic cards
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(), // Allows the outer SingleChildScrollView to handle scrolling
              itemCount: educationalTopics.length,
              itemBuilder: (context, index) {
                final topic = educationalTopics[index];
                return _EducationCard(
                  title: topic['title'],
                  subtitle: topic['subtitle'],
                  icon: topic['icon'],
                  iconColor: topic['color'],
                  onTap: () {
                    // TODO: Navigate to a detailed screen for this topic
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable widget for each educational topic card
class _EducationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _EducationCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
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
                    size: 28,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
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
    );
  }
}