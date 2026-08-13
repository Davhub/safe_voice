import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:safe_voice/admin/services/admin_report_service.dart';
import 'package:safe_voice/admin/services/admin_auth_service.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:html' as html;

class ReportDetailScreen extends StatefulWidget {
  final String caseId;
  final Map<String, dynamic> reportData;
  final bool isDialog; // NEW: Flag to indicate if shown in dialog

  const ReportDetailScreen({
    super.key,
    required this.caseId,
    required this.reportData,
    this.isDialog = false,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen>
    with TickerProviderStateMixin {
  final _statusMessage = TextEditingController();
  final _adminNote = TextEditingController();
  final _scrollController = ScrollController();

  String _selectedStatus = 'submitted';
  bool _updating = false;
  bool _playingAudio = false;
  Map<String, dynamic>? _adminInfo;
  String? _audioUrl;
  List<Map<String, dynamic>> _timeline = [];
  List<Map<String, dynamic>> _adminNotes = [];
  html.AudioElement? _audioPlayer;

  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.reportData['status'] ?? 'submitted';
    _tabController = TabController(length: 4, vsync: this);

    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _loadInitialData();
  }

  @override
  void dispose() {
    _statusMessage.dispose();
    _adminNote.dispose();
    _scrollController.dispose();
    _fadeAnimationController.dispose();
    _tabController.dispose();
    _audioPlayer?.pause();
    _audioPlayer = null;
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadAdmin(),
      _loadAudio(),
      _loadTimeline(),
      _loadAdminNotes(),
    ]);
    _fadeAnimationController.forward();
  }

  Future<void> _loadAdmin() async {
    _adminInfo = await AdminAuthService.getCurrentAdminInfo();
    setState(() {});
  }

  Future<void> _loadAudio() async {
    // Check both audioUrl (camelCase from user app) and audio_url (snake_case legacy)
    if (widget.reportData['audioUrl'] != null ||
        widget.reportData['audio_url'] != null) {
      _audioUrl = await AdminReportService.getAudioDownloadUrl(widget.caseId);
    }
    setState(() {});
  }

  Future<void> _loadTimeline() async {
    try {
      final timelineData = await AdminReportService.getReportTimeline(
        widget.caseId,
      );
      setState(() => _timeline = timelineData);
    } catch (e) {
      debugPrint('Error loading timeline: $e');
    }
  }

  Future<void> _loadAdminNotes() async {
    try {
      final notesData = await AdminReportService.getAdminNotes(widget.caseId);
      setState(() => _adminNotes = notesData);
    } catch (e) {
      debugPrint('Error loading admin notes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeaderSection(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildTimelineTab(),
                  _buildNotesTab(),
                  _buildActionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      leading:
          widget.isDialog
              ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Close',
              )
              : null, // Use default back button for normal navigation
      title: Row(
        children: [
          const Text(
            'Case Details',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.caseId,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.caseId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Case ID copied to clipboard')),
            );
          },
          tooltip: 'Copy Case ID',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadInitialData,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeaderSection() {
    final priority = _getReportPriority();
    final submittedAt = widget.reportData['submittedAt'] as Timestamp?;
    final reportType = widget.reportData['type'] ?? 'text';

    return Container(
      margin: const EdgeInsets.all(16),
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
            children: [
              // Priority indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getPriorityColor(priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPriorityIcon(priority),
                      color: _getPriorityColor(priority),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${priority.toUpperCase()} PRIORITY',
                      style: TextStyle(
                        color: _getPriorityColor(priority),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Report type
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getTypeColor(reportType).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reportType.toUpperCase(),
                  style: TextStyle(
                    color: _getTypeColor(reportType),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Case Type (NEW)
              Builder(
                builder: (context) {
                  final caseType =
                      widget.reportData['caseType'] ??
                      widget.reportData['case_type'] ??
                      'FGM';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getCaseTypeColor(caseType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getCaseTypeColor(caseType).withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.category_rounded,
                          size: 14,
                          color: _getCaseTypeColor(caseType),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getCaseTypeDisplayName(caseType),
                          style: TextStyle(
                            color: _getCaseTypeColor(caseType),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // Status chip
              _buildStatusChip(_selectedStatus, size: 'large'),
            ],
          ),
          const SizedBox(height: 16),

          // Submission details
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.grey[600], size: 16),
              const SizedBox(width: 6),
              Text(
                'Submitted ${_formatDateTime(submittedAt)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(width: 20),

              if (widget.reportData['location'] != null) ...[
                Icon(Icons.location_on, color: Colors.grey[600], size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.reportData['location'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: AppColors.primary,
        tabs: const [
          Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
          Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          Tab(text: 'Notes', icon: Icon(Icons.note_alt_outlined)),
          Tab(text: 'Actions', icon: Icon(Icons.settings)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content section
          _buildContentCard(),
          const SizedBox(height: 16),

          // Audio section (if available)
          if (_audioUrl != null) ...[
            _buildAudioCard(),
            const SizedBox(height: 16),
          ],

          // Location details
          if (widget.reportData['location'] != null) ...[
            _buildLocationCard(),
            const SizedBox(height: 16),
          ],

          // Reporter information (if available)
          _buildReporterCard(),
          const SizedBox(height: 16),

          // Keywords/Tags
          if (widget.reportData['keywords'] != null) ...[
            _buildKeywordsCard(),
            const SizedBox(height: 16),
          ],

          // Technical details
          _buildTechnicalDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildContentCard() {
    final content =
        widget.reportData['content'] ??
        widget.reportData['description'] ??
        'No content available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Report Content',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.audiotrack, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Audio Recording',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mic, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Voice Recording Available',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Audio evidence submitted with report',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _playingAudio ? null : () => _playAudio(_audioUrl!),
                icon: Icon(
                  _playingAudio ? Icons.hourglass_empty : Icons.play_arrow,
                ),
                label: Text(_playingAudio ? 'Loading...' : 'Play Audio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final location = widget.reportData['location'];
    final latitude = widget.reportData['latitude'];
    final longitude = widget.reportData['longitude'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Location Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location ?? 'Location not specified',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (latitude != null && longitude != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Coordinates: $latitude, $longitude',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ),
              if (latitude != null && longitude != null) ...[
                ElevatedButton.icon(
                  onPressed: () => _openMapLocation(latitude, longitude),
                  icon: const Icon(Icons.map),
                  label: const Text('View Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReporterCard() {
    final userId = widget.reportData['userId'];
    final isAnonymous = widget.reportData['isAnonymous'] ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Reporter Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isAnonymous) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.visibility_off, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  const Text(
                    'Anonymous Report',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User ID: ${userId ?? 'Unknown'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Text(
                        'Registered user report',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeywordsCard() {
    final keywords = widget.reportData['keywords'] as List<dynamic>? ?? [];

    if (keywords.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Keywords & Tags',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                keywords
                    .map(
                      (keyword) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          keyword.toString(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalDetailsCard() {
    final submittedAt = widget.reportData['submittedAt'] as Timestamp?;
    final deviceInfo = widget.reportData['deviceInfo'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Technical Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Case ID', widget.caseId),
          _buildDetailRow('Submission Time', _formatDateTime(submittedAt)),
          _buildDetailRow('Report Type', widget.reportData['type'] ?? 'text'),
          if (deviceInfo != null) ...[
            _buildDetailRow('Platform', deviceInfo['platform'] ?? 'Unknown'),
            _buildDetailRow('App Version', deviceInfo['version'] ?? 'Unknown'),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return _timeline.isEmpty
        ? const Center(child: Text('No timeline data available'))
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _timeline.length,
          itemBuilder: (context, index) => _buildTimelineItem(_timeline[index]),
        );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item) {
    final timestamp = item['timestamp'] as Timestamp?;
    final action = item['action'] ?? 'Unknown action';
    final adminId = item['adminId'];
    final details = item['details'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getTimelineIcon(action),
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${_formatDateTime(timestamp)} ${adminId != null ? '• by $adminId' : ''}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return Column(
      children: [
        // Add note section
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Admin Note',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _adminNote,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter your note here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _adminNote.clear(),
                    child: const Text('Clear'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _addNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add Note'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Notes list
        Expanded(
          child:
              _adminNotes.isEmpty
                  ? const Center(child: Text('No admin notes yet'))
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _adminNotes.length,
                    itemBuilder:
                        (context, index) => _buildNoteItem(_adminNotes[index]),
                  ),
        ),
      ],
    );
  }

  Widget _buildNoteItem(Map<String, dynamic> note) {
    final timestamp = note['timestamp'] as Timestamp?;
    final adminId = note['adminId'] ?? 'Unknown Admin';
    final content = note['note'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  adminId.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adminId,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _formatDateTime(timestamp),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildActionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status update section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items:
                      AdminReportService.getStatusOptions().map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Row(
                            children: [
                              _buildStatusChip(status, size: 'small'),
                              const SizedBox(width: 8),
                              Text(
                                AdminReportService.getStatusDisplayName(status),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                  onChanged:
                      (value) => setState(() => _selectedStatus = value!),
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _statusMessage,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Status Message (optional)',
                    hintText: 'Add a note about this status change...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updating ? null : _updateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child:
                        _updating
                            ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                            : const Text('Update Status'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Quick actions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Acknowledge Case',
                        Icons.assignment_turned_in,
                        Colors.indigo,
                        () => _acknowledgeCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Resolve Case',
                        Icons.check_circle,
                        Colors.green,
                        () => _quickResolve(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Flag for Review',
                        Icons.flag,
                        Colors.orange,
                        () => _flagForReview(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionButton(
                        'Export Details',
                        Icons.download,
                        Colors.blue,
                        () => _exportCaseDetails(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    );
  }

  Widget _buildStatusChip(String status, {String size = 'medium'}) {
    final color = _getStatusColor(status);
    final isLarge = size == 'large';
    final isSmall = size == 'small';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 12 : (isSmall ? 6 : 8),
        vertical: isLarge ? 6 : (isSmall ? 2 : 4),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isLarge ? 8 : 6),
      ),
      child: Text(
        AdminReportService.getStatusDisplayName(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: isLarge ? 12 : (isSmall ? 9 : 10),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper methods
  /// Reads the urgency level the classifier assigned at submission time
  /// (report_service.dart's classifyUrgency) — same source of truth as
  /// ReportListWidget, rather than re-deriving it here from a separate,
  /// narrower keyword list.
  String _getReportPriority() {
    return (widget.reportData['urgency'] as String? ?? 'LOW').toLowerCase();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.orange.shade700;
      case 'medium':
        return Colors.amber.shade600;
      case 'low':
        return Colors.teal.shade600;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'critical':
        return Icons.report;
      case 'high':
        return Icons.error;
      case 'medium':
        return Icons.warning;
      case 'low':
        return Icons.info;
      default:
        return Icons.help;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'text':
        return Colors.blue;
      case 'voice':
        return Colors.green;
      case 'mixed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getCaseTypeColor(String caseType) {
    switch (caseType) {
      case 'FGM':
        return const Color(0xFFE91E63);
      case 'SEXUAL_ASSAULT':
        return const Color(0xFF9C27B0);
      case 'GBV':
        return const Color(0xFF673AB7);
      default:
        return Colors.grey;
    }
  }

  String _getCaseTypeDisplayName(String caseType) {
    switch (caseType) {
      case 'FGM':
        return 'FGM';
      case 'SEXUAL_ASSAULT':
        return 'Sexual Assault';
      case 'GBV':
        return 'GBV';
      default:
        return caseType;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getTimelineIcon(String action) {
    if (action.toLowerCase().contains('status')) return Icons.update;
    if (action.toLowerCase().contains('note')) return Icons.note_add;
    if (action.toLowerCase().contains('submit')) return Icons.send;
    return Icons.timeline;
  }

  String _formatDateTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      // Today - show time
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'Today at $hour:$minute';
    } else if (diff.inDays == 1) {
      // Yesterday
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      // This week
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      // Full date
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      return '$day/$month/$year';
    }
  }

  // Action methods
  Future<void> _updateStatus() async {
    setState(() => _updating = true);

    try {
      print('🔄 Attempting to update status to: $_selectedStatus');
      print('Admin ID: ${_adminInfo?['uid']}');
      print('Admin Email: ${_adminInfo?['email']}');
      print('Case ID: ${widget.caseId}');

      final success = await AdminReportService.updateReportStatus(
        caseId: widget.caseId,
        status: _selectedStatus,
        statusMessage:
            _statusMessage.text.isNotEmpty ? _statusMessage.text : null,
        adminId: _adminInfo?['uid'],
      );

      if (success) {
        _statusMessage.clear();
        await _loadTimeline(); // Refresh timeline
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Status updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      if (mounted) {
        String errorMessage = 'Failed to update status: ';
        if (e.code == 'permission-denied') {
          errorMessage +=
              'Permission denied. Make sure you are logged in as an admin.';
        } else if (e.code == 'not-found') {
          errorMessage += 'Report not found.';
        } else {
          errorMessage += '${e.code} - ${e.message}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      print('❌ Error updating status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }

    setState(() => _updating = false);
  }

  Future<void> _addNote() async {
    if (_adminNote.text.trim().isEmpty) return;

    try {
      final success = await AdminReportService.addAdminNote(
        caseId: widget.caseId,
        note: _adminNote.text.trim(),
        adminId: _adminInfo?['uid'] ?? 'unknown',
      );

      if (success) {
        _adminNote.clear();
        await _loadAdminNotes(); // Refresh notes
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added successfully')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to add note')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _playAudio(String url) async {
    try {
      // Show audio player dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => _AudioPlayerDialog(url: url),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openMapLocation(double latitude, double longitude) async {
    final Uri uri = Uri.parse(
      'https://maps.google.com/?q=$latitude,$longitude',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _acknowledgeCase() async {
    final success = await AdminReportService.acknowledgeReport(
      caseId: widget.caseId,
      adminId: _adminInfo?['uid'] ?? 'unknown',
      adminEmail: _adminInfo?['email'],
    );

    if (!mounted) return;

    if (success) {
      await _loadTimeline();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Case acknowledged'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to acknowledge case'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _quickResolve() {
    setState(() => _selectedStatus = 'resolved');
    _updateStatus();
  }

  void _flagForReview() {
    setState(() => _selectedStatus = 'under_review');
    _updateStatus();
  }

  void _exportCaseDetails() {
    // TODO: Implement case export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Export functionality will be implemented')),
    );
  }
}

// Audio Player Dialog Widget
class _AudioPlayerDialog extends StatefulWidget {
  final String url;

  const _AudioPlayerDialog({required this.url});

  @override
  State<_AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<_AudioPlayerDialog> {
  html.AudioElement? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isMockAudio = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
  }

  void _initializeAudio() {
    try {
      _audioPlayer = html.AudioElement(widget.url);
      _audioPlayer!.preload = 'auto';

      // Listen to events
      _audioPlayer!.onLoadedData.listen((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });

      _audioPlayer!.onError.listen((error) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isMockAudio = true;
            _errorMessage = 'This appears to be a test/mock audio file';
          });
        }
      });

      _audioPlayer!.onPlay.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = true);
        }
      });

      _audioPlayer!.onPause.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });

      _audioPlayer!.onEnded.listen((_) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      });

      // Load the audio
      _audioPlayer!.load();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initializing audio player: $e';
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer?.pause();
    _audioPlayer = null;
    super.dispose();
  }

  void _togglePlayPause() {
    if (_audioPlayer == null) return;

    if (_isPlaying) {
      _audioPlayer!.pause();
    } else {
      _audioPlayer!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.audiotrack, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('Audio Recording')),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading audio...'),
                ],
              )
            else if (_errorMessage != null || _isMockAudio)
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 64,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage ?? 'Test Audio File',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'This audio file cannot be played because:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• It\'s a mock/test audio file created for development\n'
                          '• It doesn\'t contain actual audio data\n'
                          '• The M4A format may not be fully supported',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Solutions:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '1. Enable real audio recording on the user app\n'
                          '2. Test with actual voice recordings\n'
                          '3. Check Firebase Storage for file validity',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final Uri uri = Uri.parse(widget.url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Try opening in new tab'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Try playing anyway
                          setState(() {
                            _errorMessage = null;
                            _isMockAudio = false;
                          });
                          _audioPlayer?.play().catchError((e) {
                            if (mounted) {
                              setState(() {
                                _errorMessage = 'Playback failed: $e';
                              });
                            }
                          });
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Try anyway'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.volume_up : Icons.headset,
                      size: 64,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _togglePlayPause,
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        label: Text(_isPlaying ? 'Pause' : 'Play'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          _audioPlayer?.pause();
                          _audioPlayer?.currentTime = 0;
                          setState(() => _isPlaying = false);
                        },
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      final Uri uri = Uri.parse(widget.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download / Open in new tab'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
