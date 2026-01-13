import 'package:flutter/material.dart';
import 'package:safe_voice/admin/services/analytics_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'dart:math' as math;

class AnalyticsWidget extends StatefulWidget {
  const AnalyticsWidget({super.key});

  @override
  State<AnalyticsWidget> createState() => _AnalyticsWidgetState();
}

class _AnalyticsWidgetState extends State<AnalyticsWidget> {
  bool _isLoading = true;
  String _selectedPeriod = 'Month'; // 'Today', 'Week', 'Month'
  Map<String, dynamic>? _analyticsData;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      DateTime startDate;
      DateTime endDate = now;

      switch (_selectedPeriod) {
        case 'Today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'Week':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          break;
        case 'Month':
        default:
          startDate = DateTime(now.year, now.month, 1);
          break;
      }

      final data = await AnalyticsService.getDashboardAnalytics(
        startDate: startDate,
        endDate: endDate,
      );

      setState(() {
        _analyticsData = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_analyticsData == null) {
      return _buildErrorState();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          const SizedBox(height: 24),
          _buildMetricsCards(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildCaseTypeDistribution(),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildTopLocations(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatusBreakdown(),
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
            Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              'Period:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 16),
            ...[
              'Today',
              'Week',
              'Month'
            ].map((period) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: _selectedPeriod == period,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedPeriod = period);
                        _loadAnalytics();
                      }
                    },
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedPeriod == period
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight: _selectedPeriod == period
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards() {
    final caseTypeCounts =
        _analyticsData?['caseTypeCounts'] as Map<String, dynamic>? ?? {};
    final statusCounts =
        _analyticsData?['statusCounts'] as Map<String, dynamic>? ?? {};
    final comparison =
        _analyticsData?['comparison'] as Map<String, dynamic>? ?? {};

    final totalReports = caseTypeCounts.values.fold<int>(
        0, (sum, count) => sum + (count as int? ?? 0));
    final resolvedCount = statusCounts['resolved'] as int? ?? 0;
    final pendingCount = (statusCounts['submitted'] as int? ?? 0) +
        (statusCounts['under_review'] as int? ?? 0);

    final percentageChange = comparison['percentageChange'] as double? ?? 0.0;
    final isIncrease = comparison['isIncrease'] as bool? ?? false;

    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.assessment_rounded,
            title: 'Total Reports',
            value: totalReports.toString(),
            color: AppColors.primary,
            trend: percentageChange,
            isIncrease: isIncrease,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.check_circle_rounded,
            title: 'Resolved Cases',
            value: resolvedCount.toString(),
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.pending_actions_rounded,
            title: 'Pending Cases',
            value: pendingCount.toString(),
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    double? trend,
    bool? isIncrease,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (trend != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isIncrease!
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIncrease
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 14,
                          color: isIncrease ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${trend.abs().toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isIncrease ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseTypeDistribution() {
    final caseTypeCounts =
        _analyticsData?['caseTypeCounts'] as Map<String, dynamic>? ?? {};

    final fgmCount = caseTypeCounts['FGM'] as int? ?? 0;
    final sexualAssaultCount =
        caseTypeCounts['SEXUAL_ASSAULT'] as int? ?? 0;
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
                Icon(Icons.pie_chart_rounded,
                    color: AppColors.primary, size: 22),
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
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
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
                Icon(Icons.location_on_rounded,
                    color: AppColors.primary, size: 22),
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
                            horizontal: 12, vertical: 6),
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
                Icon(Icons.timeline_rounded,
                    color: AppColors.primary, size: 22),
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

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.textSecondary,
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
            'Please try again later',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
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

    final fgmPaint = Paint()
      ..color = const Color(0xFFE91E63)
      ..style = PaintingStyle.fill;

    final sexualAssaultPaint = Paint()
      ..color = const Color(0xFF9C27B0)
      ..style = PaintingStyle.fill;

    final gbvPaint = Paint()
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
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
