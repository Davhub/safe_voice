import 'package:flutter/material.dart';

class EmergencySOSScreen extends StatelessWidget {
  const EmergencySOSScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FF),
      appBar: AppBar(
        title: const Text(
          'Emergency SOS',
          style: TextStyle(
            color: Color(0xFF2C2C54),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFF0F0FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C2C54)),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The main SOS button
              InkWell(
                onTap: () {
                  // TODO: Implement phone call to an emergency number
                  // For example, using the url_launcher package:
                  // launchUrl(Uri(scheme: 'tel', path: '911'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calling emergency services... (Functionality to be implemented)'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(100),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFE6501),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFE6501).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Tap the button above for immediate help.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C2C54),
                ),
              ),
              const SizedBox(height: 48),
              // Emergency Contacts Section
              const Text(
                'Other Emergency Contacts',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C2C54),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: Color(0xFF2C2C54)),
                      title: const Text('National Helpline'),
                      subtitle: const Text('1-800-HELPLINE'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF757575)),
                      onTap: () {
                        // TODO: Implement phone call
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.security, color: Color(0xFF2C2C54)),
                      title: const Text('Police'),
                      subtitle: const Text('1-800-POLICE'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF757575)),
                      onTap: () {
                        // TODO: Implement phone call
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.local_hospital_outlined, color: Color(0xFF2C2C54)),
                      title: const Text('Medical Services'),
                      subtitle: const Text('1-800-MEDICAL'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF757575)),
                      onTap: () {
                        // TODO: Implement phone call
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}