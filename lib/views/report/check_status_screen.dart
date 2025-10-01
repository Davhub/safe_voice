import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/services.dart';
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

  @override
  void dispose() {
    _caseIdController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (_caseIdController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a case ID';
        _reportStatus = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _reportStatus = null;
    });

    try {
      final status = await ReportService.getReportStatus(_caseIdController.text.trim());
      
      setState(() {
        if (status != null) {
          _reportStatus = status;
          _errorMessage = null;
        } else {
          _reportStatus = null;
          _errorMessage = 'Case ID not found. Please check your case ID and try again.';
        }
      });
    } catch (e) {
      setState(() {
        _reportStatus = null;
        _errorMessage = 'Failed to check status. Please try again later.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                    
                    // Status
                    _buildStatusRow(
                      'Status',
                      ReportStatus.fromString(_reportStatus!['status'] ?? 'submitted').displayName,
                      Icons.info_outline,
                    ),
                    const SizedBox(height: 16),
                    
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
}
