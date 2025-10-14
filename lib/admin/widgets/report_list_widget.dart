import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_report_service.dart';
import 'package:safe_voice/admin/screens/report_detail_screen.dart';
import 'package:safe_voice/constant/colors.dart';

class ReportListWidget extends StatefulWidget {
  final String? status;
  const ReportListWidget({super.key, this.status});
  
  @override
  State<ReportListWidget> createState() => _ReportListWidgetState();
}

class _ReportListWidgetState extends State<ReportListWidget> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'all';
  String _selectedStatusFilter = 'all';
  String _selectedPriorityFilter = 'all';
  String _sortBy = 'date';
  bool _sortAscending = false;
  bool _isGridView = false;
  
  late AnimationController _refreshAnimationController;
  late Animation<double> _refreshAnimation;

  @override
  void initState() {
    super.initState();
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshAnimationController, curve: Curves.easeInOut),
    );
    
    // Set initial status filter if provided
    if (widget.status != null) {
      _selectedStatusFilter = widget.status!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnhancedHeader(),
          const SizedBox(height: 20),
          _buildAdvancedFiltersAndSearch(),
          const SizedBox(height: 20),
          _buildStatsOverview(),
          const SizedBox(height: 20),
          SizedBox(
            height: screenWidth < 768 
                ? screenHeight * 0.7  // Mobile/tablet
                : screenHeight * 0.6, // Desktop
            child: _buildReportsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedHeader() {
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
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getStatusIcon(),
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              // Refresh button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: RotationTransition(
                  turns: _refreshAnimation,
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      _refreshAnimationController.forward().then((_) {
                        _refreshAnimationController.reset();
                      });
                      setState(() {});
                    },
                    tooltip: 'Refresh Reports',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // View toggle
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    _isGridView ? Icons.list : Icons.grid_view,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                ),
              ),
              const SizedBox(width: 12),
              
              // Export button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _showExportDialog,
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Export Reports',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedFiltersAndSearch() {
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
            children: [
              Icon(Icons.filter_list_rounded, color: Colors.grey[700]),
              const SizedBox(width: 8),
              const Text(
                'Advanced Search & Filters',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters())
                TextButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear All'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by Case ID, content, location, or keywords...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          ),
          
          const SizedBox(height: 20),
          
          // Filter row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type filter
                SizedBox(
                  width: 200,
                  child: _buildFilterDropdown(
                    'Report Type',
                    _selectedTypeFilter,
                    [
                      {'value': 'all', 'label': 'All Types'},
                      {'value': 'text', 'label': 'Text Reports'},
                      {'value': 'voice', 'label': 'Voice Reports'},
                      {'value': 'mixed', 'label': 'Mixed Reports'},
                    ],
                    (value) => setState(() => _selectedTypeFilter = value!),
                    Icons.description,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Status filter (if not specific to one status)
                if (widget.status == null) ...[
                  SizedBox(
                    width: 200,
                    child: _buildFilterDropdown(
                      'Status',
                      _selectedStatusFilter,
                      [
                        {'value': 'all', 'label': 'All Statuses'},
                        {'value': 'submitted', 'label': 'Submitted'},
                        {'value': 'under_review', 'label': 'Under Review'},
                        {'value': 'investigating', 'label': 'Investigating'},
                        {'value': 'requires_follow_up', 'label': 'Follow-up Required'},
                        {'value': 'resolved', 'label': 'Resolved'},
                        {'value': 'closed', 'label': 'Closed'},
                      ],
                      (value) => setState(() => _selectedStatusFilter = value!),
                      Icons.flag,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                
                // Priority filter
                SizedBox(
                  width: 200,
                  child: _buildFilterDropdown(
                    'Priority',
                    _selectedPriorityFilter,
                    [
                      {'value': 'all', 'label': 'All Priorities'},
                      {'value': 'high', 'label': 'High Priority'},
                      {'value': 'medium', 'label': 'Medium Priority'},
                      {'value': 'low', 'label': 'Low Priority'},
                    ],
                    (value) => setState(() => _selectedPriorityFilter = value!),
                    Icons.priority_high,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Sort options
                SizedBox(
                  width: 200,
                  child: _buildFilterDropdown(
                    'Sort By',
                    _sortBy,
                    [
                      {'value': 'date', 'label': 'Date Submitted'},
                      {'value': 'status', 'label': 'Status'},
                      {'value': 'type', 'label': 'Report Type'},
                      {'value': 'priority', 'label': 'Priority'},
                      {'value': 'location', 'label': 'Location'},
                    ],
                    (value) => setState(() => _sortBy = value!),
                    Icons.sort,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Sort direction
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      color: AppColors.primary,
                    ),
                    onPressed: () => setState(() => _sortAscending = !_sortAscending),
                    tooltip: _sortAscending ? 'Ascending' : 'Descending',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<Map<String, String>> items,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[50],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: items.map((item) => DropdownMenuItem(
          value: item['value'],
          child: Text(item['label']!),
        )).toList(),
        onChanged: onChanged,
        isExpanded: true,
      ),
    );
  }

  Widget _buildStatsOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminReportService.getReportsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final textReports = docs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'text').length;
        final voiceReports = docs.where((d) => (d.data() as Map<String, dynamic>)['type'] == 'voice').length;
        final pending = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'submitted').length;
        final resolved = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'resolved').length;
        final today = docs.where((d) => _isToday(_getTimestamp(d.data() as Map<String, dynamic>))).length;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
                  Icon(Icons.analytics, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Reports Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Total Reports', '$total', Icons.report, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Text Reports', '$textReports', Icons.text_fields, Colors.indigo),
                    const SizedBox(width: 16),
                    _buildStatCard('Voice Reports', '$voiceReports', Icons.mic, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Pending', '$pending', Icons.pending, Colors.orange),
                    const SizedBox(width: 16),
                    _buildStatCard('Resolved', '$resolved', Icons.check_circle, Colors.green),
                    const SizedBox(width: 16),
                    _buildStatCard('Today', '$today', Icons.today, Colors.purple),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminReportService.getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading reports...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          print('ReportListWidget: Error in StreamBuilder: ${snapshot.error}');
          return _buildErrorWidget();
        }

        if (!snapshot.hasData) {
          print('ReportListWidget: No data received from stream');
          return _buildEmptyWidget();
        }

        var docs = snapshot.data!.docs;
        print('ReportListWidget: Received ${docs.length} documents from stream');
        
        if (docs.isEmpty) {
          print('ReportListWidget: Document list is empty');
          return _buildEmptyWidget();
        }
        
        // Apply filters
        docs = _applyFilters(docs);
        print('ReportListWidget: After applying filters: ${docs.length} documents');
        
        if (docs.isEmpty) {
          return _buildNoResultsWidget();
        }
        
        if (docs.isEmpty) {
          return _buildNoResultsWidget();
        }

        return Container(
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
              // Header with count
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${docs.length} Report${docs.length != 1 ? 's' : ''} Found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Last updated: ${DateTime.now().toString().split('.')[0]}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // List content
              Expanded(
                child: _isGridView ? _buildGridView(docs) : _buildTableView(docs),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableView(List<QueryDocumentSnapshot> docs) {
    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[200]),
      itemBuilder: (context, index) => _buildEnhancedTableRow(docs[index]),
    );
  }

  Widget _buildEnhancedTableRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final caseId = doc.id;
    final type = data['type'] ?? 'text';
    final status = data['status'] ?? 'submitted';
    final content = data['content'] ?? data['description'] ?? '';
    final location = data['location'] ?? 'Not specified';
    final timestamp = _getTimestamp(data);
    final priority = _getReportPriority(data);
    final hasAudio = data['audio_url'] != null || type == 'voice';

    return InkWell(
      onTap: () => _openReportDetail(caseId, data),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            left: BorderSide(
              color: _getPriorityColor(priority),
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // Case ID & Type
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        caseId.length > 12 ? '${caseId.substring(0, 12)}...' : caseId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (hasAudio) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.audiotrack, size: 16, color: Colors.green[600]),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTypeChip(type),
                ],
              ),
            ),
            
            // Status & Priority
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(status),
                  const SizedBox(height: 4),
                  _buildPriorityChip(priority),
                ],
              ),
            ),
            
            // Date & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDate(timestamp),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            
            // Location
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location.length > 30 ? '${location.substring(0, 30)}...' : location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content Preview
            Expanded(
              flex: 2,
              child: Text(
                content.length > 40 ? '${content.substring(0, 40)}...' : content,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            
            // Actions
            Container(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, size: 18),
                    onPressed: () => _openReportDetail(caseId, data),
                    tooltip: 'View Details',
                    color: AppColors.primary,
                  ),
                  if (hasAudio) ...[
                    IconButton(
                      icon: const Icon(Icons.play_arrow, size: 18),
                      onPressed: () => _playAudio(data),
                      tooltip: 'Play Audio',
                      color: Colors.green,
                    ),
                  ],
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 18),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: ListTile(leading: Icon(Icons.visibility), title: Text('View Details'), contentPadding: EdgeInsets.zero)),
                      const PopupMenuItem(value: 'update', child: ListTile(leading: Icon(Icons.edit), title: Text('Update Status'), contentPadding: EdgeInsets.zero)),
                      if (hasAudio) const PopupMenuItem(value: 'audio', child: ListTile(leading: Icon(Icons.audiotrack), title: Text('Play Audio'), contentPadding: EdgeInsets.zero)),
                      const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.download), title: Text('Export'), contentPadding: EdgeInsets.zero)),
                    ],
                    onSelected: (value) => _handleAction(value, caseId, data),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<QueryDocumentSnapshot> docs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: docs.length,
        itemBuilder: (context, index) => _buildReportCard(docs[index]),
      ),
    );
  }

  Widget _buildReportCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final caseId = doc.id;
    final type = data['type'] ?? 'text';
    final status = data['status'] ?? 'submitted';
    final content = data['content'] ?? data['description'] ?? '';
    final location = data['location'] ?? 'Not specified';
    final timestamp = _getTimestamp(data);
    final priority = _getReportPriority(data);
    final hasAudio = data['audio_url'] != null || type == 'voice';

    return InkWell(
      onTap: () => _openReportDetail(caseId, data),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getPriorityColor(priority).withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getPriorityColor(priority).withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    caseId.length > 10 ? '${caseId.substring(0, 10)}...' : caseId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (hasAudio) Icon(Icons.audiotrack, size: 16, color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            
            // Type and Status
            Row(
              children: [
                _buildTypeChip(type),
                const SizedBox(width: 8),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            
            // Priority
            _buildPriorityChip(priority),
            const SizedBox(height: 12),
            
            // Content preview
            Expanded(
              child: Text(
                content.length > 60 ? '${content.substring(0, 60)}...' : content,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // Footer
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location.length > 15 ? '${location.substring(0, 15)}...' : location,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 10,
                    ),
                  ),
                ),
                Text(
                  _formatDate(timestamp),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    final colors = {
      'text': Colors.blue,
      'voice': Colors.green,
      'mixed': Colors.purple,
    };
    
    final color = colors[type] ?? Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final color = _getPriorityColor(priority);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No reports found',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Reports will appear here when submitted by users',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _testDatabaseConnection,
                icon: const Icon(Icons.bug_report),
                label: const Text('Test DB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No matching reports',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Try adjusting your search criteria or filters',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _clearAllFilters,
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          const SizedBox(height: 24),
          const Text(
            'Error Loading Reports',
            style: TextStyle(
              fontSize: 24,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Please check your connection and try again',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchText = '${doc.id} ${data['content'] ?? ''} ${data['description'] ?? ''} ${data['location'] ?? ''}'.toLowerCase();
        if (!searchText.contains(_searchQuery)) return false;
      }
      
      // Type filter
      if (_selectedTypeFilter != 'all') {
        if ((data['type'] ?? 'text') != _selectedTypeFilter) return false;
      }
      
      // Status filter
      if (_selectedStatusFilter != 'all') {
        if ((data['status'] ?? 'submitted') != _selectedStatusFilter) return false;
      }
      
      // Priority filter
      if (_selectedPriorityFilter != 'all') {
        final priority = _getReportPriority(data);
        if (priority != _selectedPriorityFilter) return false;
      }
      
      return true;
    }).toList()
    ..sort((a, b) => _sortDocuments(a, b));
  }

  int _sortDocuments(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
    final dataA = a.data() as Map<String, dynamic>;
    final dataB = b.data() as Map<String, dynamic>;
    
    int comparison = 0;
    
    switch (_sortBy) {
      case 'date':
        final dateA = _getTimestamp(dataA);
        final dateB = _getTimestamp(dataB);
        if (dateA != null && dateB != null) {
          comparison = dateA.compareTo(dateB);
        }
        break;
      case 'status':
        comparison = (dataA['status'] ?? '').compareTo(dataB['status'] ?? '');
        break;
      case 'type':
        comparison = (dataA['type'] ?? '').compareTo(dataB['type'] ?? '');
        break;
      case 'priority':
        final priorityA = _getReportPriority(dataA);
        final priorityB = _getReportPriority(dataB);
        final priorityOrder = {'high': 3, 'medium': 2, 'low': 1};
        comparison = (priorityOrder[priorityB] ?? 0).compareTo(priorityOrder[priorityA] ?? 0);
        break;
      case 'location':
        comparison = (dataA['location'] ?? '').compareTo(dataB['location'] ?? '');
        break;
    }
    
    return _sortAscending ? comparison : -comparison;
  }

  String _getReportPriority(Map<String, dynamic> data) {
    final content = (data['content'] ?? data['description'] ?? '').toLowerCase();
    final keywords = data['keywords'] as List<dynamic>? ?? [];
    
    final highPriorityKeywords = ['emergency', 'urgent', 'danger', 'help', 'attack', 'violence', 'assault', 'weapon'];
    final mediumPriorityKeywords = ['threat', 'harassment', 'unsafe', 'concern', 'suspicious', 'bullying'];
    
    if (keywords.any((k) => highPriorityKeywords.contains(k.toString().toLowerCase())) ||
        highPriorityKeywords.any((k) => content.contains(k))) {
      return 'high';
    }
    
    if (keywords.any((k) => mediumPriorityKeywords.contains(k.toString().toLowerCase())) ||
        mediumPriorityKeywords.any((k) => content.contains(k))) {
      return 'medium';
    }
    
    return 'low';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return Colors.orange;
      case 'under_review': return Colors.blue;
      case 'investigating': return Colors.indigo;
      case 'requires_follow_up': return Colors.amber;
      case 'resolved': return Colors.green;
      case 'closed': return Colors.grey;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    if (widget.status == null) return Icons.report_rounded;
    switch (widget.status!.toLowerCase()) {
      case 'submitted': return Icons.pending_actions_rounded;
      case 'under_review': return Icons.visibility_rounded;
      case 'investigating': return Icons.search_rounded;
      case 'requires_follow_up': return Icons.follow_the_signs_rounded;
      case 'resolved': return Icons.check_circle_rounded;
      case 'closed': return Icons.archive_rounded;
      default: return Icons.report_rounded;
    }
  }

  String _getTitle() {
    if (widget.status == null) return 'All Reports';
    switch (widget.status!.toLowerCase()) {
      case 'submitted': return 'Pending Reports';
      case 'under_review': return 'Under Review';
      case 'investigating': return 'Investigating';
      case 'requires_follow_up': return 'Follow-up Required';
      case 'resolved': return 'Resolved Reports';
      case 'closed': return 'Closed Reports';
      default: return 'Reports';
    }
  }

  String _getSubtitle() {
    if (widget.status == null) return 'Comprehensive view of all submitted reports with advanced filtering and search';
    switch (widget.status!.toLowerCase()) {
      case 'submitted': return 'Reports awaiting initial review and assignment';
      case 'under_review': return 'Reports currently being evaluated by administrators';
      case 'investigating': return 'Reports under active investigation';
      case 'requires_follow_up': return 'Reports requiring additional action or information';
      case 'resolved': return 'Successfully completed and resolved cases';
      case 'closed': return 'Archived reports that have been finalized';
      default: return 'Manage reports efficiently with smart filtering';
    }
  }

  Timestamp? _getTimestamp(Map<String, dynamic> data) {
    // Handle different possible field names
    return data['submittedAt'] as Timestamp? ?? 
           data['submitted_at'] as Timestamp? ?? 
           data['createdAt'] as Timestamp? ?? 
           data['created_at'] as Timestamp?;
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isToday(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final now = DateTime.now();
    final date = timestamp.toDate();
    return now.year == date.year && now.month == date.month && now.day == date.day;
  }

  bool _hasActiveFilters() {
    return _searchQuery.isNotEmpty ||
           _selectedTypeFilter != 'all' ||
           _selectedStatusFilter != 'all' ||
           _selectedPriorityFilter != 'all';
  }

  void _clearAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedTypeFilter = 'all';
      if (widget.status == null) _selectedStatusFilter = 'all';
      _selectedPriorityFilter = 'all';
      _sortBy = 'date';
      _sortAscending = false;
    });
  }

  void _openReportDetail(String caseId, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportDetailScreen(
          caseId: caseId,
          reportData: data,
        ),
      ),
    );
  }

  void _playAudio(Map<String, dynamic> data) async {
    final audioUrl = data['audio_url'];
    if (audioUrl != null) {
      // TODO: Implement audio playback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio playback functionality will be implemented')),
      );
    }
  }

  void _handleAction(String action, String caseId, Map<String, dynamic> data) {
    switch (action) {
      case 'view':
        _openReportDetail(caseId, data);
        break;
      case 'update':
        _showUpdateStatusDialog(caseId, data['status'] ?? 'submitted');
        break;
      case 'audio':
        _playAudio(data);
        break;
      case 'export':
        _exportSingleReport(caseId, data);
        break;
    }
  }

  void _showUpdateStatusDialog(String caseId, String currentStatus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Report Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Case ID: $caseId'),
            const SizedBox(height: 16),
            Text('Current Status: ${currentStatus.toUpperCase()}'),
            // TODO: Add full status update form
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openReportDetail(caseId, {});
            },
            child: const Text('Open Details'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Reports'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose export format:'),
            SizedBox(height: 16),
            // TODO: Add export options
            Text('Export functionality will be implemented'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export functionality coming soon')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _exportSingleReport(String caseId, Map<String, dynamic> data) {
    // TODO: Implement single report export
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exporting report $caseId...')),
    );
  }

  Future<void> _testDatabaseConnection() async {
    print('Testing database connection...');
    try {
      // Test direct Firestore access
      final snapshot = await FirebaseFirestore.instance.collection('reports').limit(5).get();
      print('Direct Firestore test: Found ${snapshot.docs.length} documents');
      
      for (var doc in snapshot.docs) {
        var data = doc.data();
        print('Doc ${doc.id}: status=${data['status']}, type=${data['type']}, hasContent=${data['content'] != null}');
      }
      
      // Test through AdminReportService
      final stats = await AdminReportService.getReportsStatistics();
      print('AdminReportService stats: $stats');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.docs.length} reports in database. Check console for details.'),
            backgroundColor: snapshot.docs.isNotEmpty ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Database test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Database error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
