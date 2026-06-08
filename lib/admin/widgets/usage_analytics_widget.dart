import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/admin/services/app_usage_analytics_service.dart';
import 'dart:async';

/// Widget for displaying anonymous, aggregated app usage metrics
/// Tracks: DAU, App Opens, Screen Visits, Device Types, Coarse Location
/// All data is completely anonymized and aggregated - fetched in real-time from Firebase
class UsageAnalyticsWidget extends StatefulWidget {
  const UsageAnalyticsWidget({super.key});

  @override
  State<UsageAnalyticsWidget> createState() => _UsageAnalyticsWidgetState();
}

class _UsageAnalyticsWidgetState extends State<UsageAnalyticsWidget> {
  String _selectedPeriod = 'Month'; // Default to Month as specified
  StreamSubscription<Map<String, dynamic>>? _analyticsSubscription;
  Map<String, dynamic> _usageData = {};
  bool _hasData = false;
  bool _isInitialLoad = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _subscribeToAnalytics();
  }

  @override
  void dispose() {
    _analyticsSubscription?.cancel();
    super.dispose();
  }

  /// Subscribe to real-time analytics stream from Firebase
  void _subscribeToAnalytics() {
    // Cancel any existing subscription
    _analyticsSubscription?.cancel();

    print('🔍 [Analytics] Subscribing for period: $_selectedPeriod');

    try {
      // Get date range for selected period
      final dateRange = AppUsageAnalyticsService.getDateRange(_selectedPeriod);
      final startDate = dateRange['startDate']!;
      final endDate = dateRange['endDate']!;

      print('📅 [Analytics] Date range: $startDate to $endDate');

      // Determine period granularity (day for Today, month for Week/Month)
      final period = _selectedPeriod == 'Today' ? 'day' : 'month';

      print('📊 [Analytics] Period type: $period');

      // Subscribe to real-time analytics stream
      _analyticsSubscription = AppUsageAnalyticsService.getAnalyticsStream(
        startDate: startDate,
        endDate: endDate,
        period: period,
      ).listen(
        (data) {
          if (mounted) {
            print('📦 [Analytics] Received data:');
            print('   - Keys: ${data.keys}');
            print('   - activeUsers: ${data['activeUsers']}');
            print('   - appOpens: ${data['appOpens']}');
            print('   - Data empty? ${data.isEmpty}');

            final hasData = _checkIfDataExists(data);
            print('   - Has data: $hasData');

            setState(() {
              _usageData = data;
              _hasData = hasData;
              _isInitialLoad = false;
              _errorMessage = null;
            });

            print(
              '✅ [Analytics] State updated - showing ${_hasData ? "dashboard" : "empty state"}',
            );
          }
        },
        onError: (error) {
          if (mounted) {
            print('❌ [Analytics] Stream error: $error');
            setState(() {
              _errorMessage = 'Error loading analytics: $error';
              _isInitialLoad = false;
            });
          }
          debugPrint('❌ Analytics stream error: $error');
        },
      );
    } catch (e) {
      print('❌ [Analytics] Subscription error: $e');
      setState(() {
        _errorMessage = 'Failed to connect to analytics: $e';
        _isInitialLoad = false;
      });
      debugPrint('❌ Error subscribing to analytics: $e');
    }
  }

  /// Check if analytics data actually contains meaningful values
  bool _checkIfDataExists(Map<String, dynamic> data) {
    // Check if we have any data structure at all
    // Even if values are 0, if the structure exists, show the dashboard
    if (data.isEmpty) return false;

    // Check if we have the expected data structure
    final hasStructure =
        data.containsKey('dailyActiveUsers') ||
        data.containsKey('appOpens') ||
        data.containsKey('screenVisits') ||
        data.containsKey('deviceTypes') ||
        data.containsKey('coarseLocations');

    return hasStructure;
  }

  /// Handle period change and resubscribe to appropriate stream
  void _onPeriodChanged(String newPeriod) {
    if (_selectedPeriod != newPeriod) {
      setState(() {
        _selectedPeriod = newPeriod;
        _isInitialLoad = true;
      });
      _subscribeToAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator on initial load
    if (_isInitialLoad) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Loading analytics data...',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Show error state
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load analytics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _subscribeToAnalytics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Show empty state when no data exists
    if (!_hasData) {
      return _buildEmptyState();
    }

    // Show analytics dashboard with real-time data
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildPeriodSelector(),
          const SizedBox(height: 32),
          _buildMetricsCards(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildScreenVisitsCard()),
              const SizedBox(width: 24),
              Expanded(child: _buildDeviceTypesCard()),
            ],
          ),
          const SizedBox(height: 24),
          _buildLocationCard(),
          const SizedBox(height: 24),
          _buildPrivacyNotice(),
          const SizedBox(height: 16),
          _buildLastUpdated(),
        ],
      ),
    );
  }

  /// Build empty state when no analytics data exists
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Analytics Data Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Analytics data for $_selectedPeriod is not available yet.\nData will appear once users start using the app.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () async {
                print('🚀 Initialize button clicked');

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text('Initializing analytics structure...'),
                      ],
                    ),
                    duration: Duration(seconds: 5),
                  ),
                );

                try {
                  print('📝 Starting initialization...');
                  // Initialize analytics structure
                  await AppUsageAnalyticsService.initializeAnalyticsStructure();
                  print('✅ Initialization complete');

                  // Wait for Firestore to propagate
                  print('⏳ Waiting 3 seconds for Firestore propagation...');
                  await Future.delayed(Duration(seconds: 3));

                  // Resubscribe to get the new data
                  print('🔄 Resubscribing to analytics stream...');
                  _subscribeToAnalytics();

                  // Wait a bit more to ensure stream receives data
                  await Future.delayed(Duration(milliseconds: 500));

                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 16),
                            const Text(
                              'Analytics structure initialized successfully!',
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  print('❌ Initialization error: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 16),
                            Expanded(child: Text('Error: ${e.toString()}')),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.settings),
              label: const Text('Initialize Analytics Structure'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '(For development/testing only)',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'App Usage Analytics',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Real-time indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.5),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Real-time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Anonymous, aggregated metrics streaming live from Firebase',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.analytics_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Time Period:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            ...['Today', 'Week', 'Month'].map(
              (period) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(period),
                  selected: _selectedPeriod == period,
                  onSelected: (selected) {
                    if (selected) {
                      _onPeriodChanged(period);
                    }
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color:
                        _selectedPeriod == period
                            ? Colors.white
                            : AppColors.textSecondary,
                    fontWeight:
                        _selectedPeriod == period
                            ? FontWeight.w600
                            : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards() {
    final dau = _usageData['dailyActiveUsers'] ?? 0;
    final appOpens = _usageData['appOpens'] ?? 0;
    final androidUsers = (_usageData['deviceTypes'] ?? {})['android'] ?? 0;
    final iosUsers = (_usageData['deviceTypes'] ?? {})['iOS'] ?? 0;
    final totalDevices = androidUsers + iosUsers;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.people_rounded,
            title: 'Active Users',
            value: dau.toString(),
            subtitle: _selectedPeriod == 'Today' ? 'Today' : 'In period',
            color: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.touch_app_rounded,
            title: 'App Opens',
            value: appOpens.toString(),
            subtitle: 'Total sessions',
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.devices_rounded,
            title: 'Total Devices',
            value: totalDevices.toString(),
            subtitle: 'Unique devices',
            color: const Color(0xFF9C27B0),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenVisitsCard() {
    final screenVisits =
        _usageData['screenVisits'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pageview_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Screen Visits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...screenVisits.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: _buildScreenVisitItem(
                  _formatScreenName(entry.key),
                  entry.value as int,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenVisitItem(String screenName, int visits) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                screenName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$visits visits',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            visits.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTypesCard() {
    final deviceTypes =
        _usageData['deviceTypes'] as Map<String, dynamic>? ?? {};
    final android = deviceTypes['android'] ?? 0;
    final ios = deviceTypes['iOS'] ?? 0;
    final total = android + ios;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_android_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Device Types',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDeviceBar(
              'Android',
              android,
              total,
              const Color(0xFF4CAF50),
              Icons.android,
            ),
            const SizedBox(height: 20),
            _buildDeviceBar(
              'iOS',
              ios,
              total,
              const Color(0xFF2196F3),
              Icons.apple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceBar(
    String name,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    final locations =
        _usageData['coarseLocations'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.public_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Text(
                  'Geographic Distribution (Country Level)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Aggregated country-level data only. No precise location tracking.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  locations.entries.map((entry) {
                    return _buildLocationChip(entry.key, entry.value as int);
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip(String country, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            country,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Card(
      elevation: 0,
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(
              Icons.privacy_tip_outlined,
              color: Colors.blue.shade700,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy First Analytics',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'All metrics are completely anonymized and aggregated in real-time. No personally identifiable information is collected or displayed. Location data is limited to country level only. Data updates automatically from Firebase.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastUpdated() {
    final lastUpdated = _usageData['lastUpdated'] as String?;
    if (lastUpdated == null) return const SizedBox.shrink();

    try {
      final updateTime = DateTime.parse(lastUpdated);
      final now = DateTime.now();
      final difference = now.difference(updateTime);

      String timeAgo;
      if (difference.inSeconds < 60) {
        timeAgo = 'just now';
      } else if (difference.inMinutes < 60) {
        timeAgo = '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        timeAgo = '${difference.inHours}h ago';
      } else {
        timeAgo = '${difference.inDays}d ago';
      }

      return Card(
        elevation: 0,
        color: Colors.grey.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.update_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Last updated: $timeAgo',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      return const SizedBox.shrink();
    }
  }

  String _formatScreenName(String key) {
    return key
        .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
        .split(' ')
        .map(
          (word) =>
              word.isEmpty
                  ? ''
                  : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ')
        .trim();
  }
}
