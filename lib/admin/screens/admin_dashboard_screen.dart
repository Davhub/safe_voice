import 'package:flutter/material.dart';
import 'package:safe_voice/admin/widgets/report_list_widget.dart';
import 'package:safe_voice/admin/widgets/dashboard_stats_widget.dart';
import 'package:safe_voice/admin/widgets/alert_management_widget.dart';
import 'package:safe_voice/admin/services/admin_auth_service.dart';
import 'package:safe_voice/constant/colors.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Map<String, dynamic>? _adminInfo;
  bool _isLoading = true;
  
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard_rounded,
      label: 'Overview',
      description: 'Dashboard & Statistics',
    ),
    NavigationItem(
      icon: Icons.people_rounded,
      label: 'User Management',
      description: 'Manage system users',
    ),
    NavigationItem(
      icon: Icons.notifications_active_rounded,
      label: 'Alert Management',
      description: 'Monitor active alerts',
    ),
    NavigationItem(
      icon: Icons.report_rounded,
      label: 'All Reports',
      description: 'View all submitted reports',
    ),
    NavigationItem(
      icon: Icons.pending_actions_rounded,
      label: 'Pending Review',
      description: 'Reports awaiting action',
    ),
    NavigationItem(
      icon: Icons.check_circle_rounded,
      label: 'Resolved',
      description: 'Completed cases',
    ),
    NavigationItem(
      icon: Icons.message_rounded,
      label: 'Messages',
      description: 'Communication center',
    ),
    NavigationItem(
      icon: Icons.analytics_rounded,
      label: 'Analytics',
      description: 'Reports & trends',
    ),
    NavigationItem(
      icon: Icons.settings_rounded,
      label: 'Settings',
      description: 'System configuration',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _loadAdminInfo();
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminInfo() async {
    try {
      _adminInfo = await AdminAuthService.getCurrentAdminInfo();
      _slideAnimationController.forward();
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark Sidebar Navigation (bSafe style)
          if (!isMobile) _buildDarkSidebar(),
          
          // Main Content Area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SlideTransition(
                    position: _slideAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(30.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDashboardHeader(),
                          const SizedBox(height: 30),
                          _buildPageTitle(),
                          const SizedBox(height: 20),
                          _buildMainContent(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      
      // Mobile drawer
      drawer: isMobile ? _buildMobileDrawer() : null,
    );
  }

  Widget _buildDarkSidebar() {
    return Container(
      width: 280,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Color(0xFF0C1935), // Dark blue background
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Title area
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.teal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Safe Voice Admin',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24),
          
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;
                
                return Container(
                  margin: const EdgeInsets.only(right: 15, bottom: 5),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? Colors.white : Colors.white70,
                      size: 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: item.description != null
                        ? Text(
                            item.description!,
                            style: TextStyle(
                              color: isSelected ? Colors.white60 : Colors.white54,
                              fontSize: 11,
                            ),
                          )
                        : null,
                    onTap: () => setState(() => _selectedIndex = index),
                  ),
                );
              },
            ),
          ),
          
          // Admin User Panel at bottom
          _buildAdminUserPanel(),
        ],
      ),
    );
  }

  Widget _buildAdminUserPanel() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF1E3A8A),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal,
            radius: 20,
            child: Text(
              (_adminInfo?['email'] as String?)?.substring(0, 1).toUpperCase() ?? 'A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _adminInfo?['name'] ?? 'Admin User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'System Administrator',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sign Out', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await AdminAuthService.adminLogout();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader() {
    return Row(
      children: [
        // Search bar
        Expanded(
          flex: 2,
          child: Container(
            height: 45,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search reports, users, alerts...',
                prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        
        // Quick Actions
        _buildQuickActionButton(
          icon: Icons.add_rounded,
          label: 'New Report',
          onTap: () {},
        ),
        const SizedBox(width: 12),
        
        // Notifications
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.notifications_rounded, color: Colors.grey),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        
        // Profile (simplified for header)
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageTitle() {
    return Text(
      _navigationItems[_selectedIndex].label,
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0: // Overview
        return const DashboardStatsWidget();
      case 1: // User Management
        return _buildComingSoonWidget('User Management');
      case 2: // Alert Management
        return Container(
          height: MediaQuery.of(context).size.height - 200,
          child: const AlertManagementWidget(),
        );
      case 3: // All Reports
        return Container(
          height: MediaQuery.of(context).size.height - 200,
          child: const ReportListWidget(),
        );
      case 4: // Pending Review
        return Container(
          height: MediaQuery.of(context).size.height - 200,
          child: const ReportListWidget(status: 'submitted'),
        );
      case 5: // Resolved
        return Container(
          height: MediaQuery.of(context).size.height - 200,
          child: const ReportListWidget(status: 'resolved'),
        );
      case 6: // Messages
        return _buildComingSoonWidget('Messages');
      case 7: // Analytics
        return _buildComingSoonWidget('Analytics');
      case 8: // Settings
        return _buildComingSoonWidget('Settings');
      default:
        return const DashboardStatsWidget();
    }
  }

  Widget _buildComingSoonWidget(String feature) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
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
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.construction_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '$feature Coming Soon',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This feature is currently under development and will be available in the next update.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDrawer() {
    return Drawer(
      child: Container(
        color: const Color(0xFF0C1935),
        child: Column(
          children: [
            // Header
            Container(
              height: 120,
              padding: const EdgeInsets.all(20),
              child: SafeArea(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.teal,
                      child: const Icon(
                        Icons.security_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safe Voice Admin',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Administrator Panel',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const Divider(color: Colors.white24),
            
            // Navigation items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 20),
                itemCount: _navigationItems.length,
                itemBuilder: (context, index) {
                  final item = _navigationItems[index];
                  final isSelected = _selectedIndex == index;
                  
                  return ListTile(
                    leading: Icon(
                      item.icon,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: item.description != null
                        ? Text(
                            item.description!,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          )
                        : null,
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF1E3A8A),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            
            // Logout
            const Divider(color: Colors.white24),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await AdminAuthService.adminLogout();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final String label;
  final String? description;

  NavigationItem({
    required this.icon,
    required this.label,
    this.description,
  });
}
