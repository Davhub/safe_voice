import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/services.dart';
import 'package:safe_voice/services/enhanced_report_service.dart';
import 'package:safe_voice/services/audio_service.dart';
import 'package:safe_voice/services/native_location_service.dart';
import 'package:safe_voice/models/report.dart';
import 'package:safe_voice/routing/app_router.dart'; // Import for CaseTypeNotifier

class ReportCaseScreen extends StatefulWidget {
  final bool showBack;
  final CaseType? initialCaseType;
  const ReportCaseScreen({Key? key, this.showBack = true, this.initialCaseType})
    : super(key: key);

  @override
  State<ReportCaseScreen> createState() => _ReportCaseScreenState();
}

class _ReportCaseScreenState extends State<ReportCaseScreen> {
  final TextEditingController _reportController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  bool _isSubmitting = false;
  bool _isSubmittingVoice = false; // Separate state for voice submission
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  late Stream<Duration> _durationStream;

  // New state variables for better UX
  String? _currentLocation;
  String? _locationAccuracy; // Store accuracy information
  bool _isRefreshingLocation = false;
  String _networkStatus = 'Checking...';
  int _pendingReportsCount = 0;
  CaseType _selectedCaseType = CaseType.FGM; // NEW: Selected case type

  @override
  void initState() {
    super.initState();
    if (widget.initialCaseType != null) {
      _selectedCaseType = widget.initialCaseType!;
    }

    // Listen to case type changes from the global notifier
    CaseTypeNotifier.instance.addListener(_onCaseTypeChanged);

    _getCurrentLocation();
    _setupTextListener();
    _checkNetworkStatus();
    _loadPendingReportsCount();
  }

  /// Callback when case type changes in the global notifier
  void _onCaseTypeChanged() {
    final newCaseType = CaseTypeNotifier.instance.value;
    if (newCaseType != null && newCaseType != _selectedCaseType) {
      setState(() {
        _selectedCaseType = newCaseType;
      });
      print(
        '📋 Case type updated to: ${newCaseType.displayName} (${newCaseType.value})',
      );
    }
  }

  @override
  void didUpdateWidget(ReportCaseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update case type when widget is updated with new initialCaseType
    if (widget.initialCaseType != null &&
        widget.initialCaseType != oldWidget.initialCaseType) {
      setState(() {
        _selectedCaseType = widget.initialCaseType!;
      });
      print(
        '📋 Case type updated via didUpdateWidget to: ${widget.initialCaseType!.displayName}',
      );
    }
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    CaseTypeNotifier.instance.removeListener(_onCaseTypeChanged);
    _reportController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Set up text listener for real-time validation
  void _setupTextListener() {
    _reportController.addListener(() {
      setState(() {
        // Update state for real-time validation if needed
      });
    });
  }

  /// Check network status
  Future<void> _checkNetworkStatus() async {
    try {
      String status = await EnhancedReportService.getConnectivityStatus();
      setState(() {
        _networkStatus = status;
      });
    } catch (e) {
      setState(() {
        _networkStatus = 'Unknown';
      });
    }
  }

  /// Load pending reports count
  Future<void> _loadPendingReportsCount() async {
    try {
      int count = await EnhancedReportService.getPendingReportsCount();
      setState(() {
        _pendingReportsCount = count;
      });
    } catch (e) {
      setState(() {
        _pendingReportsCount = 0;
      });
    }
  }

  /// Get current location in background
  Future<void> _getCurrentLocation() async {
    if (_isRefreshingLocation) return; // Prevent multiple simultaneous requests

    try {
      setState(() {
        _currentLocation = "Getting precise location...";
        _locationAccuracy = null;
        _isRefreshingLocation = true;
      });

      // Request location permission first
      bool hasPermission =
          await NativeLocationService.requestLocationPermission();

      if (!hasPermission) {
        setState(() {
          _currentLocation = "Location permission denied";
          _isRefreshingLocation = false;
        });
        return;
      }

      // Check if location services are enabled
      bool isEnabled = await NativeLocationService.isLocationServiceEnabled();

      if (!isEnabled) {
        setState(() {
          _currentLocation = "Location services disabled";
          _isRefreshingLocation = false;
        });
        return;
      }

      // Get current location with human-readable address
      String locationAddress =
          await NativeLocationService.getCurrentLocationAddress();

      // Parse accuracy information if present
      String? accuracy;
      String displayLocation = locationAddress;

      if (locationAddress.contains('[Accuracy:')) {
        final accuracyMatch = RegExp(
          r'\[Accuracy: ([^\]]+)\]',
        ).firstMatch(locationAddress);
        if (accuracyMatch != null) {
          accuracy = accuracyMatch.group(1);
          displayLocation = locationAddress.replaceAll(
            RegExp(r'\s*\[Accuracy:[^\]]+\]'),
            '',
          );
        }
      }

      setState(() {
        _currentLocation = displayLocation;
        _locationAccuracy = accuracy;
        _isRefreshingLocation = false;
      });

      print(
        '✅ Location detected: $_currentLocation (Accuracy: ${_locationAccuracy ?? "unknown"})',
      );
    } catch (e) {
      setState(() {
        _currentLocation = "Location unavailable: ${e.toString()}";
        _locationAccuracy = null;
        _isRefreshingLocation = false;
      });
      print('❌ Location error: $e');
    }
  }

  /// Start voice recording
  Future<void> _startRecording() async {
    try {
      final success = await AudioService.startRecording();
      if (success) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        // Start duration timer
        _durationStream = Stream.periodic(const Duration(seconds: 1), (count) {
          return Duration(seconds: count + 1);
        });

        _durationStream.listen((duration) {
          if (_isRecording) {
            setState(() {
              _recordingDuration = duration;
            });
          }
        });

        _showInfoDialog('Recording started. ');
      } else {
        _showErrorDialog(
          'Failed to start recording. Please check microphone permissions.',
        );
      }
    } catch (e) {
      _showErrorDialog('Error starting recording: $e');
    }
  }

  /// Stop voice recording
  Future<void> _stopRecording() async {
    try {
      final recordingFile = await AudioService.stopRecording();
      setState(() {
        _isRecording = false;
        _recordingPath = recordingFile?.path;
      });

      if (recordingFile != null) {
        // Get file size for feedback
        String fileSize = await AudioService.getFileSize(recordingFile.path);
        _showInfoDialog(
          'Audio recording saved! ($fileSize)\n${AudioService.getPlatformStatusMessage()}\nYou can now submit your voice report.',
        );
      } else {
        _showErrorDialog('Failed to save recording. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Error stopping recording: $e');
    }
  }

  /// Cancel voice recording
  Future<void> _cancelRecording() async {
    try {
      if (_isRecording) {
        await AudioService.stopRecording(); // Stop the recording first
      }
      setState(() {
        _isRecording = false;
        _recordingPath = null;
        _recordingDuration = Duration.zero;
      });
      _showInfoDialog('Recording cancelled.');
    } catch (e) {
      _showErrorDialog('Error cancelling recording: $e');
    }
  }

  /// Submit voice report
  Future<void> _submitVoiceReport() async {
    if (_recordingPath == null) {
      _showErrorDialog('Please record your voice report first.');
      return;
    }

    setState(() {
      _isSubmittingVoice = true; // Use separate voice submission state
    });

    // Show progress dialog for voice submission
    // if (mounted) {
    //   showDialog(
    //     context: context,
    //     barrierDismissible: false,
    //     builder: (BuildContext context) {
    //       return AlertDialog(
    //         content: Column(
    //           mainAxisSize: MainAxisSize.min,
    //           children: [
    //             const CircularProgressIndicator(color: AppColors.primary),
    //             const SizedBox(height: 16),
    //             const Text(
    //               'Uploading Voice Report...',
    //               style: TextStyle(
    //                 fontSize: 16,
    //                 fontWeight: FontWeight.w600,
    //                 color: AppColors.textPrimary,
    //               ),
    //             ),
    //             const SizedBox(height: 8),
    //             Text(
    //               'This may take a moment',
    //               style: TextStyle(
    //                 fontSize: 14,
    //                 color: AppColors.textSecondary,
    //               ),
    //             ),
    //           ],
    //         ),
    //       );
    //     },
    //   );
    // }

    try {
      // Check if file exists
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $_recordingPath');
      }

      print('📁 Submitting voice report: ${file.path}');
      print('📁 File size: ${await file.length()} bytes');

      // Get location for submission - prioritize detected location, then manual input
      String locationToSubmit = _currentLocation ?? 'Location unavailable';
      if (_locationController.text.trim().isNotEmpty) {
        locationToSubmit = _locationController.text.trim();
      }

      print('📍 Location being submitted: $locationToSubmit');
      print(
        '📋 Case type being submitted: ${_selectedCaseType.displayName} (${_selectedCaseType.value})',
      );

      // Submit voice report using enhanced service with offline support
      String caseId = await EnhancedReportService.submitVoiceReport(
        audioFile: file,
        caseType: _selectedCaseType.value, // Include selected case type
        location: locationToSubmit, // Include current location
        incidentDate: DateTime.now(),
      );

      print('✅ Voice report submitted successfully with Case ID: $caseId');

      // Reset state immediately (no dialog to close since it's commented out)
      if (mounted) {
        setState(() {
          _isSubmittingVoice = false;
          _recordingPath = null;
          _selectedCaseType = CaseType.FGM; // Reset to default
        });

        // Clear location field
        _locationController.clear();

        // Clear the global case type notifier
        CaseTypeNotifier.instance.value = null;

        // Refresh pending reports count
        _loadPendingReportsCount();

        // Show success dialog with case ID directly over the current screen
        showCaseIDDialog(context, caseId);
      }
    } catch (e) {
      // Reset submission state and show error (no dialog to close)
      if (mounted) {
        setState(() {
          _isSubmittingVoice = false;
        });

        // Show detailed error for debugging
        print('❌ Voice report submission error: $e');
        _showErrorDialog('Failed to submit voice report: $e');
      }
    }
  }

  /// Submit the report to Firebase
  Future<void> _submitReport() async {
    // Validate input
    if (_reportController.text.trim().isEmpty) {
      _showErrorDialog('Please enter your report before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get location for submission - prioritize detected location, then manual input
      String locationToSubmit = _currentLocation ?? 'Location unavailable';
      if (_locationController.text.trim().isNotEmpty) {
        locationToSubmit = _locationController.text.trim();
      }

      print('📍 Location being submitted: $locationToSubmit');
      print(
        '📋 Case type being submitted: ${_selectedCaseType.displayName} (${_selectedCaseType.value})',
      );

      // Submit report using enhanced service with offline support
      String caseId = await EnhancedReportService.submitTextReport(
        reportText: _reportController.text.trim(),
        caseType: _selectedCaseType.value, // Include selected case type
        location: locationToSubmit, // Include current location
        incidentDate: DateTime.now(),
      );

      // Show success dialog with case ID
      if (mounted) {
        showCaseIDDialog(context, caseId);
        // Clear the form
        _reportController.clear();
        _locationController.clear();
        // Reset case type to default after submission
        setState(() {
          _selectedCaseType = CaseType.FGM;
        });
        // Clear the global case type notifier
        CaseTypeNotifier.instance.value = null;
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        _showErrorDialog('Failed to submit report. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// Test Firebase connectivity

  /// Get color based on location accuracy
  Color _getAccuracyColor() {
    if (_locationAccuracy == null) return AppColors.textSecondary;

    // Extract numeric value from accuracy string (e.g., "±10.5m" -> 10.5)
    final numMatch = RegExp(r'[\d.]+').firstMatch(_locationAccuracy!);
    if (numMatch == null) return AppColors.textSecondary;

    final accuracy = double.tryParse(numMatch.group(0)!);
    if (accuracy == null) return AppColors.textSecondary;

    // Color code based on accuracy:
    // Green: < 10m (excellent for legal purposes)
    // Orange: 10-50m (good)
    // Red: > 50m (poor, needs refinement)
    if (accuracy < 10) {
      return AppColors.success;
    } else if (accuracy < 50) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Show info dialog
  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Info'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit Report',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            // Status chips row
            Row(
              children: [
                // Network status chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _networkStatus == 'Offline'
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _networkStatus == 'Offline'
                              ? AppColors.error.withOpacity(0.3)
                              : AppColors.success.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _networkStatus == 'Offline'
                            ? Icons.cloud_off
                            : Icons.wifi,
                        size: 14,
                        color:
                            _networkStatus == 'Offline'
                                ? AppColors.error
                                : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _networkStatus,
                        style: TextStyle(
                          color:
                              _networkStatus == 'Offline'
                                  ? AppColors.error
                                  : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pending reports badge
                if (_pendingReportsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_pendingReportsCount pending',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading:
            widget.showBack
                ? IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
                : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero info banner with glassmorphism effect
            Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Your Privacy Matters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'All reports are anonymous and secure',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Voice Report Section - Single Large Microphone Design
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        _isRecording
                            ? AppColors.error.withOpacity(0.2)
                            : Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: _isRecording ? 4 : 0,
                  ),
                ],
                border: Border.all(
                  color:
                      _isRecording
                          ? AppColors.error.withOpacity(0.3)
                          : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  // Single Large Microphone Icon
                  if (!_isRecording && _recordingPath == null)
                    Column(
                      children: [
                        GestureDetector(
                          onTap: _startRecording,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.2),
                                  AppColors.primary.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.2),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.mic_none_outlined,
                              size: 100,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Tap to record your report',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Voice reports are secure and anonymous',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  // Recording in Progress
                  if (_isRecording)
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.error.withOpacity(0.3),
                                AppColors.error.withOpacity(0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withOpacity(0.3),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.mic,
                            size: 100,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recording...',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fiber_manual_record,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Stop Recording Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _stopRecording,
                            icon: const Icon(Icons.stop_rounded, size: 24),
                            label: const Text(
                              'Stop Recording',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Cancel Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _cancelRecording,
                            icon: const Icon(Icons.close_rounded, size: 22),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(
                                color: AppColors.error,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  // Recording Complete - Ready to Submit
                  if (_recordingPath != null && !_isRecording)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.success.withOpacity(0.2),
                                AppColors.success.withOpacity(0.1),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withOpacity(0.2),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 100,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recording Complete',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your voice report is ready to submit',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed:
                                _isSubmittingVoice ? null : _submitVoiceReport,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              elevation: 0,
                              disabledBackgroundColor: AppColors.disabled,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child:
                                _isSubmittingVoice
                                    ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: AppColors.textOnPrimary,
                                            strokeWidth: 2.5,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text(
                                          'Submitting...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.send_rounded, size: 22),
                                        SizedBox(width: 12),
                                        Text(
                                          'Submit Voice Report',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _recordingPath = null;
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 20),
                          label: const Text(
                            'Discard Recording',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            // Modern Divider with gradient
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.textSecondary.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Text(
                      'OR',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.textSecondary.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            // Text Report Section with modern design
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Container(
                      //   padding: const EdgeInsets.all(10),
                      //   decoration: BoxDecoration(
                      //     color: AppColors.secondary.withOpacity(0.1),
                      //     borderRadius: BorderRadius.circular(12),
                      //   ),
                      //   child: Icon(
                      //     Icons.edit_note_rounded,
                      //     color: AppColors.secondary,
                      //     size: 24,
                      //   ),
                      // ),
                      // const SizedBox(width: 12),
                      // const Expanded(
                      //   child: Text(
                      //     'Written Report',
                      //     style: TextStyle(
                      //       fontSize: 20,
                      //       fontWeight: FontWeight.bold,
                      //       color: AppColors.textPrimary,
                      //       letterSpacing: -0.5,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Type your report details below',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  // Case Type Selector - NEW
                  // Column(
                  //   crossAxisAlignment: CrossAxisAlignment.start,
                  //   children: [
                  //     Row(
                  //       children: [
                  //         Icon(
                  //           Icons.category_outlined,
                  //           size: 18,
                  //           color: AppColors.primary,
                  //         ),
                  //         const SizedBox(width: 8),
                  //         Text(
                  //           'Case Type *',
                  //           style: TextStyle(
                  //             fontSize: 15,
                  //             fontWeight: FontWeight.w600,
                  //             color: AppColors.textPrimary,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //     const SizedBox(height: 12),
                  //     Container(
                  //       decoration: BoxDecoration(
                  //         color: AppColors.background,
                  //         borderRadius: BorderRadius.circular(14),
                  //         border: Border.all(
                  //           color: AppColors.primary.withOpacity(0.2),
                  //           width: 1.5,
                  //         ),
                  //       ),
                  //       child: DropdownButtonFormField<CaseType>(
                  //         value: _selectedCaseType,
                  //         decoration: InputDecoration(
                  //           border: InputBorder.none,
                  //           contentPadding: const EdgeInsets.symmetric(
                  //             horizontal: 16,
                  //             vertical: 4,
                  //           ),
                  //           prefixIcon: Icon(
                  //             Icons.report_problem_outlined,
                  //             color: AppColors.primary,
                  //             size: 22,
                  //           ),
                  //         ),
                  //         style: TextStyle(
                  //           fontSize: 15,
                  //           color: AppColors.textPrimary,
                  //           fontWeight: FontWeight.w500,
                  //         ),
                  //         dropdownColor: AppColors.card,
                  //         isExpanded: true,
                  //         items: CaseType.all.map((CaseType caseType) {
                  //           return DropdownMenuItem<CaseType>(
                  //             value: caseType,
                  //             child: Column(
                  //               crossAxisAlignment: CrossAxisAlignment.start,
                  //               mainAxisSize: MainAxisSize.min,
                  //               children: [
                  //                 Text(
                  //                   caseType.displayName,
                  //                   style: TextStyle(
                  //                     fontWeight: FontWeight.w600,
                  //                     color: AppColors.textPrimary,
                  //                   ),
                  //                 ),
                  //                 // Text(
                  //                 //   caseType.description,
                  //                 //   style: TextStyle(
                  //                 //     fontSize: 10,
                  //                 //     color: AppColors.textSecondary,
                  //                 //   ),
                  //                 // ),
                  //               ],
                  //             ),
                  //           );
                  //         }).toList(),
                  //         onChanged: (CaseType? newValue) {
                  //           if (newValue != null) {
                  //             setState(() {
                  //               _selectedCaseType = newValue;
                  //             });
                  //           }
                  //         },
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  const SizedBox(height: 10),
                  // Modern text field
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _reportController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Describe the incident in detail...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 15,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Location Section - Enhanced design
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      _currentLocation != null &&
                              !_currentLocation!.contains('unavailable') &&
                              !_currentLocation!.contains('Getting location') &&
                              !_currentLocation!.contains('disabled') &&
                              !_currentLocation!.contains('denied') &&
                              !_currentLocation!.contains('permission')
                          ? AppColors.success.withOpacity(0.3)
                          : AppColors.warning.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              _currentLocation != null &&
                                      !_currentLocation!.contains(
                                        'unavailable',
                                      ) &&
                                      !_currentLocation!.contains(
                                        'Getting location',
                                      ) &&
                                      !_currentLocation!.contains('disabled') &&
                                      !_currentLocation!.contains('denied') &&
                                      !_currentLocation!.contains('permission')
                                  ? AppColors.success.withOpacity(0.1)
                                  : AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color:
                              _currentLocation != null &&
                                      !_currentLocation!.contains(
                                        'unavailable',
                                      ) &&
                                      !_currentLocation!.contains(
                                        'Getting location',
                                      ) &&
                                      !_currentLocation!.contains('disabled') &&
                                      !_currentLocation!.contains('denied') &&
                                      !_currentLocation!.contains('permission')
                                  ? AppColors.success
                                  : AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: const [
                            Text(
                              'Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(width: 6),
                            Tooltip(
                              message:
                                  'Precise GPS coordinates help prosecutors trace the exact incident location. Accuracy < 10m is excellent.',
                              child: Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.info,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_currentLocation != null &&
                          (_currentLocation!.contains('unavailable') ||
                              _currentLocation!.contains('disabled') ||
                              _currentLocation!.contains('denied') ||
                              _currentLocation!.contains('permission')))
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _getCurrentLocation,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              tooltip: 'Retry',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            if (_currentLocation!.contains('permission') ||
                                _currentLocation!.contains('disabled'))
                              IconButton(
                                onPressed: () async {
                                  await NativeLocationService.openLocationSettings();
                                  Future.delayed(
                                    const Duration(seconds: 1),
                                    () {
                                      _getCurrentLocation();
                                    },
                                  );
                                },
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  color: AppColors.warning,
                                  size: 22,
                                ),
                                tooltip: 'Settings',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _currentLocation != null &&
                                      !_currentLocation!.contains(
                                        'unavailable',
                                      ) &&
                                      !_currentLocation!.contains(
                                        'Getting location',
                                      ) &&
                                      !_currentLocation!.contains('disabled') &&
                                      !_currentLocation!.contains('denied') &&
                                      !_currentLocation!.contains('permission')
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              size: 18,
                              color:
                                  _currentLocation != null &&
                                          !_currentLocation!.contains(
                                            'unavailable',
                                          ) &&
                                          !_currentLocation!.contains(
                                            'Getting location',
                                          ) &&
                                          !_currentLocation!.contains(
                                            'disabled',
                                          ) &&
                                          !_currentLocation!.contains(
                                            'denied',
                                          ) &&
                                          !_currentLocation!.contains(
                                            'permission',
                                          )
                                      ? AppColors.success
                                      : AppColors.warning,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _currentLocation ??
                                    'Getting precise location...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Show accuracy badge if available
                        if (_locationAccuracy != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getAccuracyColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getAccuracyColor().withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gps_fixed,
                                  size: 14,
                                  color: _getAccuracyColor(),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Accuracy: $_locationAccuracy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _getAccuracyColor(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Refine Location button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed:
                          _isRefreshingLocation ? null : _getCurrentLocation,
                      icon:
                          _isRefreshingLocation
                              ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                              : Icon(
                                Icons.my_location,
                                size: 18,
                                color: AppColors.primary,
                              ),
                      label: Text(
                        _isRefreshingLocation
                            ? 'Refining Location...'
                            : 'Refine Location for Better Accuracy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              _isRefreshingLocation
                                  ? AppColors.disabled
                                  : AppColors.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                          color:
                              _isRefreshingLocation
                                  ? AppColors.disabled
                                  : AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Optional location override
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _locationController,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Override with custom location (optional)',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontSize: 13,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        prefixIcon: Icon(
                          Icons.edit_location_alt_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Submit Button - Modern gradient design
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppColors.textOnPrimary,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child:
                    _isSubmitting
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: AppColors.textOnPrimary,
                                strokeWidth: 3,
                              ),
                            ),
                            SizedBox(width: 16),
                            Text(
                              'Submitting Report...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.send_rounded, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'Submit Written Report',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

void showCaseIDDialog(BuildContext context, String caseID) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _CaseIDDialogContent(caseID: caseID),
      );
    },
  );
}

class _CaseIDDialogContent extends StatefulWidget {
  final String caseID;

  const _CaseIDDialogContent({Key? key, required this.caseID})
    : super(key: key);

  @override
  State<_CaseIDDialogContent> createState() => _CaseIDDialogContentState();
}

class _CaseIDDialogContentState extends State<_CaseIDDialogContent> {
  bool _isCopied = false;

  void _copyCaseID() async {
    await Clipboard.setData(ClipboardData(text: widget.caseID));
    setState(() {
      _isCopied = true;
    });

    // Show a snackbar confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Case ID copied to clipboard!'),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 2),
      ),
    );

    // Reset the copied state after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isCopied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: AppColors.textSecondary,
                size: 24,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          const SizedBox(height: 8),
          // Success icon with animation
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.success.withOpacity(0.2),
                  AppColors.success.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              Icons.check_circle_rounded,
              size: 64,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Report Submitted!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Case ID',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          // Case ID display with enhanced design
          GestureDetector(
            onTap: _copyCaseID,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      _isCopied
                          ? [
                            AppColors.success.withOpacity(0.15),
                            AppColors.success.withOpacity(0.05),
                          ]
                          : [
                            AppColors.primary.withOpacity(0.15),
                            AppColors.primary.withOpacity(0.05),
                          ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _isCopied
                          ? AppColors.success.withOpacity(0.5)
                          : AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.caseID,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color:
                            _isCopied ? AppColors.success : AppColors.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      _isCopied
                          ? Icons.check_circle
                          : Icons.content_copy_rounded,
                      key: ValueKey<bool>(_isCopied),
                      color: _isCopied ? AppColors.success : AppColors.primary,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Info text with icon
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color:
                  _isCopied
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isCopied ? Icons.check_circle_outline : Icons.info_outline,
                  color: _isCopied ? AppColors.success : AppColors.info,
                  size: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isCopied
                        ? 'Case ID copied! Save it securely to track your report'
                        : 'Tap the Case ID above to copy it',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      color: _isCopied ? AppColors.success : AppColors.info,
                      fontWeight: _isCopied ? FontWeight.w600 : FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Action button with gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "I've Saved My Case ID",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // SizedBox(
          //   width: double.infinity,
          //   child: OutlinedButton(
          //     onPressed: () {
          //       // Close dialog first, then navigate to emergency exit
          //       Navigator.of(context).pop();
          //       Navigator.of(context).pushNamed('/emergency-exit');
          //     },
          //     style: OutlinedButton.styleFrom(
          //       side: const BorderSide(color: AppColors.error, width: 2),
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(16),
          //       ),
          //       padding: const EdgeInsets.symmetric(vertical: 16),
          //     ),
          //     child: const Text(
          //       'Quick Exit',
          //       style: TextStyle(
          //         fontSize: 18,
          //         fontWeight: FontWeight.bold,
          //         color: AppColors.error,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}
