import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_report_service.dart';
import 'package:safe_voice/admin/screens/report_detail_screen.dart';
import 'package:safe_voice/constant/colors.dart';

class AlertManagementWidget extends StatefulWidget {
  const AlertManagementWidget({super.key});

  @override
  State<AlertManagementWidget> createState() => _AlertManagementWidgetState();
}

class _AlertManagementWidgetState extends State<AlertManagementWidget> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedPriority = 'all';
  String _selectedStatus = 'all';
  String _selectedType = 'all';
  
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
  }

  @override
  void dispose() {
    _refreshAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAlertHeader(),
        const SizedBox(height: 24),
        _buildFilterSection(),
        const SizedBox(height: 24),
        _buildQuickStats(),
        const SizedBox(height: 24),
        _buildAlertsList(),
      ],
    );
  }

  Widget _buildAlertHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
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
            child: const Icon(
              Icons.warning_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Active Alert Monitoring',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time monitoring of safety reports and incidents',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
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
              const Icon(Icons.filter_list_rounded, color: Colors.grey),
              const SizedBox(width: 8),
              const Text(
                'Filters & Search',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              RotationTransition(
                turns: _refreshAnimation,
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    _refreshAnimationController.forward().then((_) {
                      _refreshAnimationController.reset();
                    });
                    setState(() {});
                  },
                  tooltip: 'Refresh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Search
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by case ID, location, or content...',
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
                      borderSide: BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                ),
              ),
              const SizedBox(width: 16),
              
              // Priority Filter
              _buildFilterDropdown(
                'Priority',
                _selectedPriority,
                ['all', 'high', 'medium', 'low'],
                (value) => setState(() => _selectedPriority = value!),
              ),
              const SizedBox(width: 12),
              
              // Status Filter
              _buildFilterDropdown(
                'Status',
                _selectedStatus,
                ['all', 'submitted', 'under_review', 'resolved', 'closed'],
                (value) => setState(() => _selectedStatus = value!),
              ),
              const SizedBox(width: 12),
              
              // Type Filter
              _buildFilterDropdown(
                'Type',
                _selectedType,
                ['all', 'text', 'voice', 'mixed'],
                (value) => setState(() => _selectedType = value!),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(label),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item == 'all' ? 'All ${label}s' : item.toUpperCase()),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminReportService.getReportsStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final docs = snapshot.data!.docs;
        final total = docs.length;
        final highPriority = docs.where((d) => _getReportPriority(d.data() as Map<String, dynamic>) == 'high').length;
        final pending = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'submitted').length;
        final today = docs.where((d) => _isToday((d.data() as Map<String, dynamic>)['submittedAt'] as Timestamp?)).length;

        return Row(
          children: [
            Expanded(child: _buildStatCard('Total Alerts', '$total', Icons.report_rounded, Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('High Priority', '$highPriority', Icons.priority_high_rounded, Colors.red)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Pending Review', '$pending', Icons.pending_actions_rounded, Colors.orange)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard('Today', '$today', Icons.today_rounded, Colors.green)),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminReportService.getReportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorWidget();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyWidget();
        }

        var docs = snapshot.data!.docs;
        docs = _applyFilters(docs);

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
              // Header
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
                    const Text(
                      'Active Reports',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${docs.length} report${docs.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              // List
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildAlertCard(docs[index]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final caseId = doc.id;
    final type = data['type'] ?? 'unknown';
    final status = data['status'] ?? 'submitted';
    final content = data['content'] ?? '';
    final location = data['location'] ?? 'Not specified';
    final submittedAt = data['submittedAt'] as Timestamp?;
    final priority = _getReportPriority(data);
    final urgency = _getUrgencyLevel(data);

    return InkWell(
      onTap: () => _openReportDetail(caseId, data),
      borderRadius: BorderRadius.circular(12),
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
            // Header row
            Row(
              children: [
                // Priority indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: _getPriorityColor(priority),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Type chip
                _buildTypeChip(type),
                const SizedBox(width: 8),
                
                // Urgency indicator
                if (urgency == 'urgent') ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flash_on, color: Colors.red, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          'URGENT',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                
                const Spacer(),
                
                // Time ago
                Text(
                  _getTimeAgo(submittedAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Case ID and Status
            Row(
              children: [
                Text(
                  'Case: $caseId',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 8),
            
            // Content preview
            if (content.isNotEmpty) ...[
              Text(
                content.length > 150 ? '${content.substring(0, 150)}...' : content,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
            ],
            
            // Location and actions
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey[500], size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Quick actions
                Row(
                  children: [
                    _buildQuickActionButton(
                      Icons.visibility,
                      'View',
                      () => _openReportDetail(caseId, data),
                    ),
                    const SizedBox(width: 8),
                    _buildQuickActionButton(
                      Icons.edit,
                      'Update',
                      () => _showUpdateStatusDialog(caseId, status),
                    ),
                    if (type == 'voice') ...[
                      const SizedBox(width: 8),
                      _buildQuickActionButton(
                        Icons.play_arrow,
                        'Play',
                        () => _playAudio(data['audioUrl']),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 16, color: Colors.grey[700]),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Active Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All reports have been addressed',
            style: TextStyle(color: Colors.grey[600]),
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
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Alerts',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            child: const Text('Retry'),
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
        final searchText = '${doc.id} ${data['content'] ?? ''} ${data['location'] ?? ''}'.toLowerCase();
        if (!searchText.contains(_searchQuery)) return false;
      }
      
      // Priority filter
      if (_selectedPriority != 'all') {
        if (_getReportPriority(data) != _selectedPriority) return false;
      }
      
      // Status filter
      if (_selectedStatus != 'all') {
        if ((data['status'] ?? 'submitted') != _selectedStatus) return false;
      }
      
      // Type filter
      if (_selectedType != 'all') {
        if ((data['type'] ?? 'text') != _selectedType) return false;
      }
      
      return true;
    }).toList();
  }

  String _getReportPriority(Map<String, dynamic> data) {
    // Determine priority based on content keywords or other criteria
    final content = (data['content'] ?? '').toLowerCase();
    final keywords = data['keywords'] as List<dynamic>? ?? [];
    
    final highPriorityKeywords = ['emergency', 'urgent', 'danger', 'help', 'attack', 'violence', 'assault'];
    final mediumPriorityKeywords = ['threat', 'harassment', 'unsafe', 'concern', 'suspicious'];
    
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

  String _getUrgencyLevel(Map<String, dynamic> data) {
    final submittedAt = data['submittedAt'] as Timestamp?;
    final priority = _getReportPriority(data);
    
    if (priority == 'high' && submittedAt != null) {
      final hoursSinceSubmission = DateTime.now().difference(submittedAt.toDate()).inHours;
      if (hoursSinceSubmission < 2) {
        return 'urgent';
      }
    }
    
    return 'normal';
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
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

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool _isToday(Timestamp? timestamp) {
    if (timestamp == null) return false;
    final now = DateTime.now();
    final date = timestamp.toDate();
    return now.year == date.year && now.month == date.month && now.day == date.day;
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
            // TODO: Add status update form
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement status update
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _playAudio(String? audioUrl) {
    if (audioUrl != null) {
      // TODO: Implement audio playback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audio playback functionality will be implemented')),
      );
    }
  }
}
