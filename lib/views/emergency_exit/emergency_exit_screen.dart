import 'package:flutter/material.dart';
import 'package:safe_voice/constant/colors.dart';

class EmergencyExitScreen extends StatelessWidget {
  const EmergencyExitScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.divider, // was Color(0xFFE0E0E0)
      appBar: AppBar(
        title: const Text(
          'Weather',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.card,
        elevation: 1,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'London, UK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Icon(
                Icons.wb_sunny_outlined,
                size: 100,
                color: AppColors.accent,
              ),
              const SizedBox(height: 16),
              const Text(
                '22°C',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text(
                'Sunny',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              // Forecast Section
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Mon', // Placeholder day
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          SizedBox(height: 8),
                          Icon(
                            Icons.cloud_outlined,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 8),
                          Text('20°C', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}