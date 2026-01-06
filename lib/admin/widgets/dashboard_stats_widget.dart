import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_report_service.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';
import 'package:safe_voice/admin/services/cached_data_service.dart';
import 'package:safe_voice/constant/colors.dart';

class DashboardStatsWidget extends StatefulWidget {
  const DashboardStatsWidget({super.key});
  
  @override
  State<DashboardStatsWidget> createState() => _DashboardStatsWidgetState();
}

class _DashboardStatsWidgetState extends State<DashboardStatsWidget> with TickerProviderStateMixin {
  Map<String, int> _stats = {};
  bool _loading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Use cached statistics stream instead of Future
    CachedDataService.getStatisticsStream().listen((stats) {
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
        if (!_animationController.isCompleted) {
          _animationController.forward();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome section
            _buildWelcomeSection(),
            const SizedBox(height: 32),
            
            // Stats cards
            _buildStatsCards(),
            const SizedBox(height: 32),
            
            // Recent activity and quick actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: _buildRecentActivity()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back, Admin!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Here\'s what\'s happening with Safe Voice today',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Last updated: ${TimeOfDay.now().format(context)}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Icons.dashboard_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final stats = [
      StatsCardData(
        title: 'Total Reports',
        value: '${_stats['total'] ?? 0}',
        icon: Icons.report_rounded,
        color: Colors.blue,
        isPositive: true,
      ),
      StatsCardData(
        title: 'Pending Review',
        value: '${_stats['pending'] ?? 0}',
        icon: Icons.pending_actions_rounded,
        color: Colors.orange,
        isPositive: false,
      ),
      StatsCardData(
        title: 'Resolved Cases',
        value: '${_stats['resolved'] ?? 0}',
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        isPositive: true,
      ),
      StatsCardData(
        title: 'This Week',
        value: '${_stats['thisWeek'] ?? 0}',
        icon: Icons.calendar_today_rounded,
        color: Colors.purple,
        isPositive: true,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _buildStatsCard(stats[index]),
    );
  }

  Widget _buildStatsCard(StatsCardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: 24,
                ),
              ),
              
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to all reports
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Real-time activity stream
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: CachedDataService.getActivitiesStream(limit: 5),
            builder: (context, snapshot) {
              // Show loading indicator while waiting
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Handle errors
              if (snapshot.hasError) {
                print('❌ Activity stream error: ${snapshot.error}');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.orange[300], size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Unable to load activities',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {}); // Trigger rebuild to retry
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Check if there's no data
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(Icons.history, color: Colors.grey[300], size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'No recent activity',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Activities will appear here once you perform actions',
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Display activities
              return Column(
                children: snapshot.data!.map((data) {
                  return _buildActivityItem(data);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final type = activity['type'] ?? 'info';
    final title = activity['title'] ?? 'Activity';
    final timestamp = activity['timestamp'] as Timestamp?;
    final style = AdminActivityService.getActivityStyle(type);
    
    // Map icon name to IconData
    IconData icon;
    switch (style['icon']) {
      case 'add_circle':
        icon = Icons.add_circle;
        break;
      case 'update':
        icon = Icons.update;
        break;
      case 'check_circle':
        icon = Icons.check_circle;
        break;
      case 'person_add':
        icon = Icons.person_add;
        break;
      case 'person_remove':
        icon = Icons.person_remove;
        break;
      case 'settings':
        icon = Icons.settings;
        break;
      case 'security':
        icon = Icons.security;
        break;
      case 'download':
        icon = Icons.download;
        break;
      case 'warning':
        icon = Icons.warning;
        break;
      default:
        icon = Icons.info;
    }
    
    // Map color name to Color
    Color color;
    switch (style['color']) {
      case 'green':
        color = Colors.green;
        break;
      case 'blue':
        color = Colors.blue;
        break;
      case 'purple':
        color = Colors.purple;
        break;
      case 'red':
        color = Colors.red;
        break;
      case 'orange':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  AdminActivityService.formatTimestamp(timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatsCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPositive;

  StatsCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isPositive,
  });
}
