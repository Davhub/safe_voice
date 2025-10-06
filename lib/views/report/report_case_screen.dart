import 'dart:io';
import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/services.dart';

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
  bool _isRecording = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  late Stream<Duration> _durationStream;

  @override
  void dispose() {
    _reportController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Start voice recording
  Future<void> _startRecording() async {
    try {
      final success = await AudioRecordingService.startRecording();
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
        
        _showInfoDialog('🎤 Recording started. Speak your report clearly.');
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
      final recordingPath = await AudioRecordingService.stopRecording();
      setState(() {
        _isRecording = false;
        _recordingPath = recordingPath;
      });
      
      if (recordingPath != null) {
        _showInfoDialog('✅ Recording saved! You can now submit your voice report.');
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
      await AudioRecordingService.cancelRecording();
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
      _isSubmitting = true;
    });

    try {
      // Check if file exists
      final file = File(_recordingPath!);
      if (!await file.exists()) {
        throw Exception('Recording file not found: $_recordingPath');
      }

      print('📁 Submitting voice report: ${file.path}');
      print('📁 File size: ${await file.length()} bytes');

      // Submit voice report to Firebase
      String caseId = await ReportService.submitVoiceReport(
        audioFile: file,
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        incidentDate: DateTime.now(),
      );

      print('✅ Voice report submitted successfully with Case ID: $caseId');

      // Show success dialog with case ID
      if (mounted) {
        showCaseIDDialog(context, caseId);
        // Clear the form
        _locationController.clear();
        setState(() {
          _recordingPath = null;
        });
      }
    } catch (e) {
      // Show detailed error for debugging
      print('❌ Voice report submission error: $e');
      if (mounted) {
        _showErrorDialog('Failed to submit voice report: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
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
      // Submit report to Firebase
      String caseId = await ReportService.submitTextReport(
        reportText: _reportController.text.trim(),
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
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
  Future<void> _testFirebaseConnectivity() async {
    _showInfoDialog('🧪 Running Firebase connectivity tests...');
    
    try {
      final results = await FirebaseConnectivityTest.runAllTests();
      
      final firestoreOk = results['firestore'] ?? false;
      final storageOk = results['storage'] ?? false;
      
      String message;
      if (firestoreOk && storageOk) {
        message = '✅ All Firebase services are working!\n\n'
                 '• Firestore: Connected ✅\n'
                 '• Storage: Connected ✅\n\n'
                 'Voice recording should work now.';
      } else {
        message = '⚠️ Some Firebase services have issues:\n\n'
                 '• Firestore: ${firestoreOk ? 'Connected ✅' : 'Failed ❌'}\n'
                 '• Storage: ${storageOk ? 'Connected ✅' : 'Failed ❌'}\n\n'
                 'Please check your internet connection and Firebase setup.';
      }
      
      _showInfoDialog(message);
    } catch (e) {
      _showErrorDialog('Firebase test failed: $e');
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
        title: const Text(
          'Report Case',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
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
                                onPressed: _isSubmitting ? null : _submitVoiceReport,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: _isSubmitting
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
            // Optional location field
            TextField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: 'Location (optional)',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
            // Firebase Test Button (for debugging)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _testFirebaseConnectivity,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.info, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Test Firebase Connection',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.info,
                  ),
                ),
              ),
            ),
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
                // TODO: Add logic for "I've Saved My Case ID"
                Navigator.of(context).pop();
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