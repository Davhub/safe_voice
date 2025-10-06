import 'package:flutter/material.dart';
import 'package:safe_voice/views/views.dart';
import 'package:safe_voice/constant/colors.dart';
import 'package:safe_voice/services/services.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  /// Test Firebase connectivity
  // Future<void> _testFirebaseConnection(BuildContext context) async {
  //   // Show loading dialog
  //   showDialog(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext context) {
  //       return const AlertDialog(
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           children: [
  //             CircularProgressIndicator(),
  //             SizedBox(height: 16),
  //             Text('Testing Firebase connection...'),
  //           ],
  //         ),
  //       );
  //     },
  //   );

  //   try {
  //     // Run Firebase tests
  //     Map<String, bool> results = await FirebaseTestService.runAllTests();
      
  //     if (context.mounted) {
  //       Navigator.of(context).pop(); // Close loading dialog
        
  //       // Show results dialog
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           bool allPassed = results.values.every((result) => result);
  //           return AlertDialog(
  //             title: Text(
  //               allPassed ? '✅ Firebase Connected!' : '⚠️ Connection Issues',
  //               style: TextStyle(
  //                 color: allPassed ? Colors.green : Colors.orange,
  //               ),
  //             ),
  //             content: Column(
  //               mainAxisSize: MainAxisSize.min,
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text('Test Results:'),
  //                 SizedBox(height: 8),
  //                 ...results.entries.map((entry) => Text(
  //                   '${entry.value ? '✅' : '❌'} ${entry.key}: ${entry.value ? 'PASSED' : 'FAILED'}',
  //                 )),
  //                 if (!allPassed) ...[
  //                   SizedBox(height: 12),
  //                   Text(
  //                     'Check your internet connection and Firebase setup.',
  //                     style: TextStyle(fontSize: 12, color: Colors.grey[600]),
  //                   ),
  //                 ],
  //               ],
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: const Text('OK'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     }
  //   } catch (e) {
  //     if (context.mounted) {
  //       Navigator.of(context).pop(); // Close loading dialog
        
  //       // Show error dialog
  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           return AlertDialog(
  //             title: const Text('❌ Connection Failed'),
  //             content: Text('Error: $e'),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: const Text('OK'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     }
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        toolbarHeight: 100,
        title: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Hello, there!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Firebase test button (development only)
              // IconButton(
              //   onPressed: () => _testFirebaseConnection(context),
              //   icon: const Icon(
              //     Icons.wifi_protected_setup,
              //     color: AppColors.primary,
              //     size: 28,
              //   ),
              //   tooltip: 'Test Firebase Connection',
              // ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Create a Report Card
            GestureDetector(
              onTap: () {
                // Navigate to the report case screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ReportCaseScreen()),
                );
              },
              child: Card(
                color: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note,
                        size: 40,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Create a Report',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Submit an anonymous report',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),
            // Learn Section
            GestureDetector(
              onTap: () {
                // Navigate to the report case screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LearnScreen()),
                );
              },
              child: Card(
                color: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.school,
                        size: 40,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Learn about FGM',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Information and Resources',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),
            
            // Check Report Status Section
            GestureDetector(
              onTap: () {
                // Navigate to the check status screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CheckStatusScreen()),
                );
              },
              child: Card(
                color: AppColors.secondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 40,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Check Report Status',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Track your anonymous report',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            //Emergency SOS Section
            GestureDetector(
              onTap: () {
                // Navigate to the emergency SOS screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmergencySOSScreen()),
                );
              },
              child: Card(
                color: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.support,
                        size: 40,
                        color: AppColors.textOnPrimary,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Book a session',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textOnPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Counselling and Psychosocial support',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            
          ],
        ),
      ),
      // bottomNavigationBar removed; handled by shell
    );
  }

  Widget buildEducationCard(int index) {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                // Placeholder for an image
                child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Topic $index',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Short description of the topic.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

