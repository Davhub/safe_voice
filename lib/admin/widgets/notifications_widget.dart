import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:safe_voice/admin/services/admin_notification_service.dart';
import 'package:safe_voice/admin/services/cached_data_service.dart';
import 'package:safe_voice/admin/screens/report_detail_screen.dart';
import 'package:safe_voice/constant/colors.dart';

class NotificationsWidget extends StatefulWidget {
  const NotificationsWidget({super.key});

  @override
  State<NotificationsWidget> createState() => _NotificationsWidgetState();
}

class _NotificationsWidgetState extends State<NotificationsWidget> {
  String _selectedFilter = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildFilters(),
        const SizedBox(height: 24),
        _buildNotificationsList(),
      ],
    );
  }

  Widget _buildHeader() {
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
              Icons.notifications_active_rounded,
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
                  'Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                StreamBuilder<int>(
                  stream:
                      AdminNotificationService.getUnreadNotificationCountStream(),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;
                    return Text(
                      unreadCount > 0
                          ? 'You have $unreadCount unread notification${unreadCount > 1 ? 's' : ''}'
                          : 'All caught up!',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    );
                  },
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

  Widget _buildFilters() {
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
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
                ),
              ),
              onChanged:
                  (value) => setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          const SizedBox(width: 16),
          ...['all', 'unread', 'urgent'].map(
            (filter) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(filter.toUpperCase()),
                selected: _selectedFilter == filter,
                onSelected: (selected) {
                  setState(() => _selectedFilter = selected ? filter : 'all');
                },
                selectedColor: AppColors.primary.withOpacity(0.2),
                checkmarkColor: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton.icon(
            onPressed: () => AdminNotificationService.markAllAsRead(),
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all as read'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _confirmClearRead(),
            icon: const Icon(Icons.clear_all),
            label: const Text('Clear read'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: CachedDataService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          print('❌ Notifications stream error: ${snapshot.error}');
          return _buildErrorWidget(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyWidget();
        }

        var notifications = snapshot.data!;

        // Apply filters
        notifications =
            notifications.where((data) {
              // Search filter
              if (_searchQuery.isNotEmpty) {
                final searchText =
                    '${data['title'] ?? ''} ${data['message'] ?? ''}'
                        .toLowerCase();
                if (!searchText.contains(_searchQuery)) return false;
              }

              // Status filter
              if (_selectedFilter == 'unread' && (data['isRead'] == true))
                return false;
              if (_selectedFilter == 'urgent' && data['priority'] != 'urgent')
                return false;

              return true;
            }).toList();

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
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 24),
            itemBuilder:
                (context, index) =>
                    _buildNotificationCard(notifications[index]),
          ),
        );
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> data) {
    final id = data['id'] as String;
    final isRead = data['isRead'] ?? false;
    final type = data['type'] ?? 'info';
    final priority = data['priority'] ?? 'normal';
    final title = data['title'] ?? 'Notification';
    final message = data['message'] ?? '';
    final timestamp = data['createdAt'] as Timestamp?;
    final reportId = data['reportId'];

    return InkWell(
      onTap: () {
        if (!isRead) {
          AdminNotificationService.markAsRead(id);
        }
        if (reportId != null) {
          _openReportDetail(reportId, data);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isRead
                  ? Colors.transparent
                  : _getPriorityColor(priority).withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isRead
                    ? Colors.transparent
                    : _getPriorityColor(priority).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getPriorityColor(priority).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getPriorityColor(priority),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: _getPriorityColor(priority),
                            shape: BoxShape.circle,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (priority == 'urgent')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.priority_high,
                                color: Colors.red,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'URGENT',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(color: Colors.grey[700], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AdminNotificationService.formatTimestamp(timestamp),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      if (reportId != null) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'View Report',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey[600]),
              onSelected: (value) {
                if (value == 'delete') {
                  AdminNotificationService.deleteNotification(id);
                } else if (value == 'toggle_read') {
                  if (isRead) {
                    // Mark as unread (would need to implement this)
                  } else {
                    AdminNotificationService.markAsRead(id);
                  }
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'toggle_read',
                      child: Row(
                        children: [
                          Icon(
                            isRead
                                ? Icons.mark_email_unread
                                : Icons.mark_email_read,
                          ),
                          const SizedBox(width: 8),
                          Text(isRead ? 'Mark as unread' : 'Mark as read'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget([String? errorMessage]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Error Loading Notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'report_submitted':
        return Icons.add_circle_outline;
      case 'status_change':
        return Icons.update;
      case 'high_priority':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications;
    }
  }

  void _openReportDetail(
    String reportId,
    Map<String, dynamic> notificationData,
  ) async {
    try {
      // Fetch the actual report data
      final reportDoc =
          await FirebaseFirestore.instance
              .collection('reports')
              .doc(reportId)
              .get();

      if (reportDoc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ReportDetailScreen(
                  caseId: reportId,
                  reportData: reportDoc.data()!,
                ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmClearRead() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Read Notifications'),
            content: const Text(
              'Are you sure you want to delete all read notifications?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  AdminNotificationService.clearReadNotifications();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }
}
