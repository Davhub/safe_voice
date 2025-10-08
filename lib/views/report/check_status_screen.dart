import 'dart:async';
import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/report_status_service.dart';
import 'package:safe_voice/services/test_report_service.dart';
import 'package:safe_voice/models/models.dart';

class CheckStatusScreen extends StatefulWidget {
  const CheckStatusScreen({Key? key}) : super(key: key);

  @override
  State<CheckStatusScreen> createState() => _CheckStatusScreenState();
}

class _CheckStatusScreenState extends State<CheckStatusScreen> {
  final TextEditingController _caseIdController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _reportStatus;
  String? _errorMessage;
  StreamSubscription? _statusSubscription;
  bool _isListeningForUpdates = false;

  @override
  void dispose() {
    _caseIdController.dispose();
    _statusSubscription?.cancel();
    ReportStatusService.stopAllListeners();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    String caseId = _caseIdController.text.trim();
    
    if (caseId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a case ID';
        _reportStatus = null;
      });
      return;
    }

    // Validate case ID format
    if (!ReportStatusService.isValidCaseId(caseId)) {
      setState(() {
        _errorMessage = 'Invalid case ID format. Case IDs should be in format: SV12345678';
        _reportStatus = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportStatus = null;
      _isListeningForUpdates = false;
    });

    // Stop any existing listeners
    _statusSubscription?.cancel();

    try {
      // Get initial status
      final status = await ReportStatusService.getReportStatus(caseId);
      
      setState(() {
        if (status != null) {
          _reportStatus = status;
          _errorMessage = null;
          _setupRealTimeUpdates(caseId);
        } else {
          _reportStatus = null;
          _errorMessage = 'Case ID not found. Please check your case ID and try again.';
        }
      });
    } catch (e) {
      setState(() {
        _reportStatus = null;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Set up real-time status updates
  void _setupRealTimeUpdates(String caseId) {
    setState(() {
      _isListeningForUpdates = true;
    });

    _statusSubscription = ReportStatusService.listenToStatusUpdates(
      caseId,
      (Map<String, dynamic> updatedStatus) {
        if (mounted) {
          setState(() {
            _reportStatus = updatedStatus;
          });
          
          // Show a subtle notification for status updates
          if (_reportStatus != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status updated: ${_getStatusDisplayName(updatedStatus['status'])}'),
                duration: Duration(seconds: 2),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      },
      (String error) {
        if (mounted) {
          setState(() {
            _isListeningForUpdates = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Real-time updates paused: $error'),
              duration: Duration(seconds: 3),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      },
    );
  }

  /// Get display name for status
  String _getStatusDisplayName(String status) {
    return ReportStatus.fromString(status).displayName;
  }

  /// Create a test report for debugging status functionality
  Future<void> _createTestReport() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Creating test report...'),
          backgroundColor: AppColors.primary,
        ),
      );

      String testCaseId = await TestReportService.createTestReport();
      
      // Auto-fill the case ID field
      _caseIdController.text = testCaseId;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test report created: $testCaseId'),
          duration: Duration(seconds: 4),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'Check Status',
            textColor: Colors.white,
            onPressed: _checkStatus,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create test report: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Check Report Status',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instructions
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Text(
                'Enter your case ID to check the status of your anonymous report. Your case ID was provided when you submitted your report.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            
            // Case ID Input
            const Text(
              'Case ID',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _caseIdController,
              decoration: InputDecoration(
                hintText: 'Enter your case ID (e.g., SV12345678)',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.receipt_long, color: AppColors.textSecondary),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            
            // Check Status Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.textOnPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Check Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Error Message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Status Display
            if (_reportStatus != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success),
                        const SizedBox(width: 12),
                        const Text(
                          'Report Found',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_isListeningForUpdates)
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Case ID
                    _buildStatusRow(
                      'Case ID',
                      _reportStatus!['caseId'] ?? 'Unknown',
                      Icons.receipt_long,
                    ),
                    const SizedBox(height: 16),
                    
                    // Status with enhanced display
                    _buildEnhancedStatusRow(
                      'Status',
                      _reportStatus!['status'] ?? 'submitted',
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),
                    
                    // Status Message (if available)
                    if (_reportStatus!['statusMessage'] != null) ...[
                      _buildStatusRow(
                        'Update',
                        _reportStatus!['statusMessage'],
                        Icons.message_outlined,
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Type
                    _buildStatusRow(
                      'Type',
                      _reportStatus!['type'] == 'voice' ? 'Voice Report' : 'Text Report',
                      _reportStatus!['type'] == 'voice' ? Icons.mic : Icons.text_fields,
                    ),
                    const SizedBox(height: 16),
                    
                    // Submitted Date
                    _buildStatusRow(
                      'Submitted',
                      _formatDate(_reportStatus!['submittedAt']),
                      Icons.calendar_today,
                    ),
                    
                    // Last Updated (if different from submitted)
                    if (_reportStatus!['lastUpdated'] != null && 
                        _reportStatus!['lastUpdated'] != _reportStatus!['submittedAt']) ...[
                      const SizedBox(height: 16),
                      _buildStatusRow(
                        'Last Updated',
                        _formatDate(_reportStatus!['lastUpdated']),
                        Icons.update,
                      ),
                    ],
                    
                    // Estimated Resolution (if available)
                    if (_reportStatus!['estimatedResolution'] != null) ...[
                      const SizedBox(height: 16),
                      _buildStatusRow(
                        'Estimated Resolution',
                        _formatDate(_reportStatus!['estimatedResolution']),
                        Icons.schedule,
                      ),
                    ],
                    
                    const SizedBox(height: 20),
                    
                    // Status Description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_reportStatus!['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(_reportStatus!['status']).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        ReportStatusService.getStatusMessage(_reportStatus!['status'] ?? 'submitted'),
                        style: TextStyle(
                          fontSize: 14,
                          color: _getStatusColor(_reportStatus!['status']),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Build enhanced status row with color coding
  Widget _buildEnhancedStatusRow(String label, String status, IconData icon) {
    Color statusColor = _getStatusColor(status);
    String displayName = ReportStatus.fromString(status).displayName;
    
    return Row(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Get status color based on status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'under_review':
      case 'underreview':
      case 'investigating':
        return Colors.blue;
      case 'reviewed':
      case 'resolved':
        return AppColors.success;
      case 'requires_follow_up':
      case 'requiresfollowup':
        return Colors.amber;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }
}
