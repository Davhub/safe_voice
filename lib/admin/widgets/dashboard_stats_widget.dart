import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_report_service.dart';
import 'package:safe_voice/admin/services/admin_activity_service.dart';
import 'package:safe_voice/admin/services/cached_data_service.dart';
import 'package:safe_voice/admin/services/analytics_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';

class DashboardStatsWidget extends StatefulWidget {
  const DashboardStatsWidget({super.key});

  @override
  State<DashboardStatsWidget> createState() => _DashboardStatsWidgetState();
}

class _DashboardStatsWidgetState extends State<DashboardStatsWidget>
    with TickerProviderStateMixin {
  Map<String, int> _stats = {};
  bool _loading = true;
  bool _analyticsLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Analytics state
  String _selectedPeriod =
      'Month'; // 'Today', 'Week', 'Month', 'All Time', 'Custom'
  Map<String, dynamic>? _analyticsData;
  DateTime? _customStartDate;
  DateTime? _customEndDate;

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
    _loadAnalytics();
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

  Future<void> _loadAnalytics() async {
    setState(() => _analyticsLoading = true);

    try {
      final now = DateTime.now();
      DateTime? startDate;
      DateTime? endDate = now;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'Month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        case 'All Time':
          startDate = null; // No start date = all time
          endDate = null;
          break;
        case 'Custom':
          startDate = _customStartDate;
          endDate = _customEndDate;
          break;
      }

      final data = await AnalyticsService.getDashboardAnalytics(
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _analyticsData = data;
        _analyticsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _analyticsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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

            // Time Range Selector
            _buildTimeRangeSelector(),
            const SizedBox(height: 24),

            // Stats cards with analytics
            _buildEnhancedStatsCards(),
            const SizedBox(height: 32),

            // Analytics visualizations
            if (!_analyticsLoading && _analyticsData != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildCaseTypeDistribution()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildTopLocations()),
                ],
              ),
              const SizedBox(height: 24),
              _buildStatusBreakdown(),
              const SizedBox(height: 32),
            ],

            // Recent activity
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'Analytics Period:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                ...['Today', 'Week', 'Month', 'All Time', 'Custom'].map(
                  (period) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(period),
                      selected: _selectedPeriod == period,
                      onSelected: (selected) async {
                        if (selected) {
                          if (period == 'Custom') {
                            await _showCustomDateRangePicker();
                          } else {
                            setState(() => _selectedPeriod = period);
                            _loadAnalytics();
                          }
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
            if (_selectedPeriod == 'Custom' &&
                _customStartDate != null &&
                _customEndDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Selected: ${DateFormat('MMM d, yyyy').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange:
          _customStartDate != null && _customEndDate != null
              ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
              : DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 30)),
                end: DateTime.now(),
              ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'Custom';
        _customStartDate = picked.start;
        _customEndDate = picked.end;
      });
      _loadAnalytics();
    }
  }

  Widget _buildEnhancedStatsCards() {
    if (_analyticsLoading || _analyticsData == null) {
      return _buildStatsCards(); // Show basic stats while loading
    }

    final caseTypeCounts =
        _analyticsData?['caseTypeCounts'] as Map<String, dynamic>? ?? {};
    final statusCounts =
        _analyticsData?['statusCounts'] as Map<String, dynamic>? ?? {};
    final comparison =
        _analyticsData?['comparison'] as Map<String, dynamic>? ?? {};

    final totalReports = caseTypeCounts.values.fold<int>(
      0,
      (sum, count) => sum + (count as int? ?? 0),
    );
    final resolvedCount = statusCounts['resolved'] as int? ?? 0;
    final pendingCount =
        (statusCounts['submitted'] as int? ?? 0) +
        (statusCounts['under_review'] as int? ?? 0);

    final percentageChange = comparison['percentageChange'] as double? ?? 0.0;
    final isIncrease = comparison['isIncrease'] as bool? ?? false;

    final stats = [
      StatsCardData(
        title: 'Total Reports',
        value: totalReports.toString(),
        icon: Icons.report_rounded,
        color: AppColors.primary,
        isPositive: true,
        trend: percentageChange,
        trendIncrease: isIncrease,
      ),
      StatsCardData(
        title: 'Pending Review',
        value: pendingCount.toString(),
        icon: Icons.pending_actions_rounded,
        color: Colors.orange,
        isPositive: false,
      ),
      StatsCardData(
        title: 'Resolved Cases',
        value: resolvedCount.toString(),
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        isPositive: true,
      ),
      StatsCardData(
        title: 'Under Review',
        value: '${statusCounts['under_review'] ?? 0}',
        icon: Icons.rate_review_rounded,
        color: Colors.blue,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Last updated: ${TimeOfDay.now().format(context)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
                child: Icon(data.icon, color: data.color, size: 24),
              ),
              if (data.trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        data.trendIncrease!
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        data.trendIncrease!
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14,
                        color: data.trendIncrease! ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${data.trend!.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              data.trendIncrease! ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
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

  Widget _buildCaseTypeDistribution() {
    final caseTypeCounts =
        _analyticsData?['caseTypeCounts'] as Map<String, dynamic>? ?? {};

    final fgmCount = caseTypeCounts['FGM'] as int? ?? 0;
    final sexualAssaultCount = caseTypeCounts['SEXUAL_ASSAULT'] as int? ?? 0;
    final gbvCount = caseTypeCounts['GBV'] as int? ?? 0;
    final total = fgmCount + sexualAssaultCount + gbvCount;

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
                  Icons.pie_chart_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Case Type Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (total > 0)
              Row(
                children: [
                  // Pie Chart
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: PieChartPainter(
                        fgmCount: fgmCount,
                        sexualAssaultCount: sexualAssaultCount,
                        gbvCount: gbvCount,
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Legend
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem(
                          color: const Color(0xFFE91E63),
                          label: 'FGM',
                          count: fgmCount,
                          total: total,
                        ),
                        const SizedBox(height: 16),
                        _buildLegendItem(
                          color: const Color(0xFF9C27B0),
                          label: 'Sexual Assault',
                          count: sexualAssaultCount,
                          total: total,
                        ),
                        const SizedBox(height: 16),
                        _buildLegendItem(
                          color: const Color(0xFF673AB7),
                          label: 'Gender-Based Violence',
                          count: gbvCount,
                          total: total,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    'No data available for selected period',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    required int count,
    required int total,
  }) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count reports (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopLocations() {
    final topLocations =
        _analyticsData?['topLocations'] as List<dynamic>? ?? [];

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
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Top Locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (topLocations.isNotEmpty)
              ...topLocations.take(5).map((location) {
                final locationName = location['location'] as String;
                final count = location['count'] as int;
                final index = topLocations.indexOf(location);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _getLocationColor(index),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          locationName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              })
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    'No location data available',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBreakdown() {
    final statusCounts =
        _analyticsData?['statusCounts'] as Map<String, dynamic>? ?? {};

    final submitted = statusCounts['submitted'] as int? ?? 0;
    final underReview = statusCounts['under_review'] as int? ?? 0;
    final resolved = statusCounts['resolved'] as int? ?? 0;
    final total = submitted + underReview + resolved;

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
                  Icons.timeline_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  'Status Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (total > 0)
              Column(
                children: [
                  _buildStatusBar(
                    label: 'Submitted',
                    count: submitted,
                    total: total,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildStatusBar(
                    label: 'Under Review',
                    count: underReview,
                    total: total,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildStatusBar(
                    label: 'Resolved',
                    count: resolved,
                    total: total,
                    color: Colors.green,
                  ),
                ],
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    'No status data available',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar({
    required String label,
    required int count,
    required int total,
    required Color color,
  }) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
            minHeight: 12,
          ),
        ),
      ],
    );
  }

  Color _getLocationColor(int index) {
    final colors = [
      const Color(0xFFE91E63),
      const Color(0xFF9C27B0),
      const Color(0xFF673AB7),
      const Color(0xFF3F51B5),
      const Color(0xFF2196F3),
    ];
    return colors[index % colors.length];
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
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
                        Icon(
                          Icons.error_outline,
                          color: Colors.orange[300],
                          size: 40,
                        ),
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
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Display activities
              return Column(
                children:
                    snapshot.data!.map((data) {
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
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  AdminActivityService.formatTimestamp(timestamp),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
  final double? trend;
  final bool? trendIncrease;

  StatsCardData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isPositive,
    this.trend,
    this.trendIncrease,
  });
}

// Custom Painter for Pie Chart
class PieChartPainter extends CustomPainter {
  final int fgmCount;
  final int sexualAssaultCount;
  final int gbvCount;

  PieChartPainter({
    required this.fgmCount,
    required this.sexualAssaultCount,
    required this.gbvCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final total = fgmCount + sexualAssaultCount + gbvCount;
    if (total == 0) return;

    final fgmPaint =
        Paint()
          ..color = const Color(0xFFE91E63)
          ..style = PaintingStyle.fill;

    final sexualAssaultPaint =
        Paint()
          ..color = const Color(0xFF9C27B0)
          ..style = PaintingStyle.fill;

    final gbvPaint =
        Paint()
          ..color = const Color(0xFF673AB7)
          ..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;

    // Draw FGM slice
    if (fgmCount > 0) {
      final sweepAngle = (fgmCount / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        fgmPaint,
      );
      startAngle += sweepAngle;
    }

    // Draw Sexual Assault slice
    if (sexualAssaultCount > 0) {
      final sweepAngle = (sexualAssaultCount / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        sexualAssaultPaint,
      );
      startAngle += sweepAngle;
    }

    // Draw GBV slice
    if (gbvCount > 0) {
      final sweepAngle = (gbvCount / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        gbvPaint,
      );
    }

    // Draw white center circle for donut effect
    final centerPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
