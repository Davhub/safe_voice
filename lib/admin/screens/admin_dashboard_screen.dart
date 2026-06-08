import 'package:flutter/material.dart';
import 'package:safe_voice/admin/widgets/report_list_widget.dart';
import 'package:safe_voice/admin/widgets/dashboard_stats_widget.dart';
import 'package:safe_voice/admin/widgets/usage_analytics_widget.dart';
import 'package:safe_voice/admin/widgets/notifications_widget.dart';
import 'package:safe_voice/admin/widgets/settings_widget.dart';
import 'package:safe_voice/admin/services/admin_auth_service.dart';
import 'package:safe_voice/admin/services/admin_notification_service.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';
import 'package:safe_voice/admin/services/report_listener_service.dart';
import 'package:safe_voice/admin/services/firestore_init_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  Map<String, dynamic>? _adminInfo;
  bool _isLoading = true;
  static const String _selectedIndexKey = 'admin_selected_tab';

  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard_rounded,
      label: 'Overview',
      description: 'Dashboard & Statistics',
    ),
    NavigationItem(
      icon: Icons.analytics_rounded,
      label: 'Analytics',
      description: 'Reports & Trends',
    ),
    NavigationItem(
      icon: Icons.notifications_active_rounded,
      label: 'Notifications',
      description: 'System notifications',
    ),
    NavigationItem(
      icon: Icons.report_rounded,
      label: 'All Reports',
      description: 'View all submitted reports',
    ),

    NavigationItem(
      icon: Icons.check_circle_rounded,
      label: 'Resolved',
      description: 'Completed cases',
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
    ).animate(
      CurvedAnimation(
        parent: _slideAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _loadAdminInfo();
    _loadSelectedIndex(); // Load saved tab

    // Initialize Firestore collections with sample data if needed
    FirestoreInitService.initializeAdminCollections();

    // Initialize activities collection if empty
    AdminActivityService.initializeActivities();

    // Start listening to report changes
    ReportListenerService.startListening();
  }

  Future<void> _loadSelectedIndex() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt(_selectedIndexKey);
      if (savedIndex != null && savedIndex < _navigationItems.length) {
        setState(() {
          _selectedIndex = savedIndex;
        });
      }
    } catch (e) {
      // If fails, just stay on default tab
    }
  }

  Future<void> _saveSelectedIndex(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_selectedIndexKey, index);
    } catch (e) {
      // Ignore save errors
    }
  }

  @override
  void dispose() {
    _slideAnimationController.dispose();
    // Stop listening when dashboard is disposed
    ReportListenerService.stopListening();
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
            child:
                _isLoading
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
                            const SizedBox(height: 50), // Bottom spacing
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
        color: Color(0xFF101924), // Dark blue background
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Image.asset(
                    'assets/pngs/Logo.png',
                    width: 80,
                    height: 80,
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
                    color:
                        isSelected
                            ? const Color(0xFF1E3A8A)
                            : Colors.transparent,
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
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    subtitle:
                        item.description != null
                            ? Text(
                              item.description!,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? Colors.white60
                                        : Colors.white54,
                                fontSize: 11,
                              ),
                            )
                            : null,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _saveSelectedIndex(index); // Persist tab selection
                    },
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
      decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.teal,
            radius: 20,
            child: Text(
              (_adminInfo?['email'] as String?)
                      ?.substring(0, 1)
                      .toUpperCase() ??
                  'A',
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
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            itemBuilder:
                (context) => [
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
                      title: Text(
                        'Sign Out',
                        style: TextStyle(color: Colors.red),
                      ),
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _adminInfo?['name'] ?? 'Admin User',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const Text(
              'System Administrator',
              style: TextStyle(color: Colors.black, fontSize: 12),
            ),
          ],
        ),

        const SizedBox(width: 10),

        // Profile (simplified for header)
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white),
        ),

        Divider(color: Colors.grey),
      ],
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
      case 1: // Analytics
        return const UsageAnalyticsWidget();
      case 2: // Notifications
        return const NotificationsWidget();
      case 3: // All Reports
        return const ReportListWidget();
      case 4: // Resolved
        return const ReportListWidget(status: 'resolved');
      case 5: // Settings
        return const SettingsWidget();
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
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle:
                        item.description != null
                            ? Text(
                              item.description!,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            )
                            : null,
                    selected: isSelected,
                    selectedTileColor: const Color(0xFF1E3A8A),
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _saveSelectedIndex(index); // Persist tab selection
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
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
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

  NavigationItem({required this.icon, required this.label, this.description});
}
