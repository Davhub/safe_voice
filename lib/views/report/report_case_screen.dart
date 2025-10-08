import 'dart:io';
import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/services.dart';
import 'package:safe_voice/services/enhanced_report_service.dart';
import 'package:safe_voice/services/audio_service.dart';
import 'package:safe_voice/services/native_location_service.dart';

class ReportCaseScreen extends StatefulWidget {
  final bool showBack;
  const ReportCaseScreen({Key? key, this.showBack = true}) : super(key: key);

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
  String _networkStatus = 'Checking...';
  int _pendingReportsCount = 0;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _setupTextListener();
    _checkNetworkStatus();
    _loadPendingReportsCount();
  }

  @override
  void dispose() {
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
  }  /// Get current location in background
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _currentLocation = "Getting location...";
      });

      // Request location permission first
      bool hasPermission = await NativeLocationService.requestLocationPermission();
      
      if (!hasPermission) {
        setState(() {
          _currentLocation = "Location permission denied";
        });
        return;
      }

      // Check if location services are enabled
      bool isEnabled = await NativeLocationService.isLocationServiceEnabled();
      
      if (!isEnabled) {
        setState(() {
          _currentLocation = "Location services disabled";
        });
        return;
      }

      // Get current location with human-readable address
      String locationAddress = await NativeLocationService.getCurrentLocationAddress();
      
      setState(() {
        _currentLocation = locationAddress;
      });
      
      print('✅ Location detected: $_currentLocation');
    } catch (e) {
      setState(() {
        _currentLocation = "Location unavailable: ${e.toString()}";
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
        
        _showInfoDialog('🎤 Recording started. ${AudioService.getPlatformStatusMessage()}');
      } else {
        _showErrorDialog('Failed to start recording. Please check microphone permissions.');
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
        _showInfoDialog('✅ Audio recording saved! ($fileSize)\n${AudioService.getPlatformStatusMessage()}\nYou can now submit your voice report.');
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
      _showInfoDialog('🗑️ Recording cancelled.');
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

      // Submit voice report using enhanced service with offline support
      String caseId = await EnhancedReportService.submitVoiceReport(
        audioFile: file,
        location: locationToSubmit, // Include current location
        incidentDate: DateTime.now(),
      );

      print('✅ Voice report submitted successfully with Case ID: $caseId');

      // Reset state immediately (no dialog to close since it's commented out)
      if (mounted) {
        setState(() {
          _isSubmittingVoice = false;
          _recordingPath = null;
        });
        
        // Clear location field
        _locationController.clear();
        
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

      // Submit report using enhanced service with offline support
      String caseId = await EnhancedReportService.submitTextReport(
        reportText: _reportController.text.trim(),
        location: locationToSubmit, // Include current location
        incidentDate: DateTime.now(),
      );

      // Show success dialog with case ID
      if (mounted) {
        showCaseIDDialog(context, caseId);
        // Clear the form
        _reportController.clear();
        _locationController.clear();
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
              'Report Case',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            // Network status indicator
            Row(
              children: [
                Icon(
                  _networkStatus == 'Offline' ? Icons.cloud_off : Icons.cloud_done,
                  size: 16,
                  color: _networkStatus == 'Offline' ? AppColors.error : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  _networkStatus,
                  style: TextStyle(
                    color: _networkStatus == 'Offline' ? AppColors.error : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_pendingReportsCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.sync, size: 14, color: AppColors.warning),
                  Text(
                    ' $_pendingReportsCount pending',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: widget.showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
                onPressed: () {
                  Navigator.pop(context);
                },
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Descriptive text box at the top
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
                'Choose how you would like to submit your report. Your information will remain anonymous.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            // Voice Report Section
            Container(
              padding: const EdgeInsets.all(20),
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
                children: [
                  Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 80,
                    color: _isRecording ? AppColors.error : AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRecording ? 'Recording...' : 'Record Voice Report',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isRecording ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording 
                        ? 'Tap stop when finished (${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')})'
                        : _recordingPath != null 
                            ? '✅ Recording ready to submit'
                            : 'Speak your report privately',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  // Recording Controls
                  if (!_isRecording && _recordingPath == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _startRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Start Recording',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      ),
                    ),
                  if (_isRecording)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _stopRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Stop',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _cancelRecording,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_recordingPath != null && !_isRecording)
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isSubmittingVoice ? null : _submitVoiceReport, // Use voice-specific state
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isSubmittingVoice // Use voice-specific state
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(
                                          color: AppColors.textOnPrimary,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Submit Voice Report',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textOnPrimary,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _recordingPath = null;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: AppColors.textOnPrimary,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Divider
            Row(
              children: const [
                Expanded(child: Divider(color: AppColors.textSecondary)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.textSecondary)),
              ],
            ),
            // const SizedBox(height: 20),
            // Text Field Section
            const Text(
              'Type your report below:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reportController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Start typing your report here...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Current Location Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: _currentLocation != null && 
                           !_currentLocation!.contains('unavailable') && 
                           !_currentLocation!.contains('Getting location') &&
                           !_currentLocation!.contains('disabled') &&
                           !_currentLocation!.contains('denied') &&
                           !_currentLocation!.contains('permission')
                        ? AppColors.success
                        : AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detected Location:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentLocation ?? 'Getting location...',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
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
                      children: [
                        IconButton(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          tooltip: 'Retry location detection',
                        ),
                        if (_currentLocation!.contains('permission') || 
                            _currentLocation!.contains('disabled'))
                          IconButton(
                            onPressed: () async {
                              await NativeLocationService.openLocationSettings();
                              // Retry after settings
                              Future.delayed(Duration(seconds: 1), () {
                                _getCurrentLocation();
                              });
                            },
                            icon: const Icon(
                              Icons.settings,
                              color: AppColors.warning,
                              size: 20,
                            ),
                            tooltip: 'Open location settings',
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Optional location field
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Override location (optional)',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.edit_location_outlined, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            // Firebase Test Button (for debugging)
            // SizedBox(
            //   width: double.infinity,
            //   child: OutlinedButton(
            //     onPressed: _testFirebaseConnectivity,
            //     style: OutlinedButton.styleFrom(
            //       side: const BorderSide(color: AppColors.info, width: 1),
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(12),
            //       ),
            //       padding: const EdgeInsets.symmetric(vertical: 12),
            //     ),
            //     child: const Text(
            //       'Test Firebase Connection',
            //       style: TextStyle(
            //         fontSize: 14,
            //         color: AppColors.info,
            //       ),
            //     ),
            //   ),
            // ),
            const SizedBox(height: 16),
            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.textOnPrimary,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textOnPrimary,
                        ),
                      ),
              ),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _CaseIDDialogContent(caseID: caseID),
      );
    },
  );
}

class _CaseIDDialogContent extends StatelessWidget {
  final String caseID;

  const _CaseIDDialogContent({
    Key? key,
    required this.caseID,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your Case ID',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              caseID,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Save this code to follow up on your report later',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Just close the dialog, stay on report screen
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                "I've Saved My Case ID",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Close dialog first, then navigate to emergency exit
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/emergency-exit');
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Quick Exit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}