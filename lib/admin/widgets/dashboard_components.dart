import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Search bar
        // Expanded(
        //   flex: 2,
        //   child: Container(
        //     height: 45,
        //     decoration: BoxDecoration(
        //       color: Colors.white,
        //       borderRadius: BorderRadius.circular(12),
        //       boxShadow: [
        //         BoxShadow(
        //           color: Colors.black.withOpacity(0.05),
        //           blurRadius: 10,
        //           offset: const Offset(0, 2),
        //         ),
        //       ],
        //     ),
        //     child: TextField(
        //       decoration: InputDecoration(
        //         hintText: 'Search reports, users, alerts...',
        //         prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
        //         border: InputBorder.none,
        //         contentPadding: const EdgeInsets.symmetric(vertical: 12),
        //       ),
        //     ),
        //   ),
        // ),
        // const SizedBox(width: 20),
        
        // Notifications
        // Container(
        //   width: 45,
        //   height: 45,
        //   decoration: BoxDecoration(
        //     color: Colors.white,
        //     borderRadius: BorderRadius.circular(12),
        //     boxShadow: [
        //       BoxShadow(
        //         color: Colors.black.withOpacity(0.05),
        //         blurRadius: 10,
        //         offset: const Offset(0, 2),
        //       ),
        //     ],
        //   ),
        //   child: const Icon(Icons.notifications_rounded, color: Colors.grey),
        // ),
      ],
    );
  }
}

class MetricCardsRow extends StatelessWidget {
  const MetricCardsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildMetricCard('Total Users', '1,234', Icons.people, Colors.blue)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('Active Alerts', '23', Icons.warning, Colors.orange)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('Reports Today', '45', Icons.report, Colors.green)),
        const SizedBox(width: 20),
        Expanded(child: _buildMetricCard('Response Time', '2.3m', Icons.timer, Colors.purple)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  final String title;
  final double height;

  const ChartCard({super.key, required this.title, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Text(
                'Chart visualization will be implemented here',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MapCard extends StatelessWidget {
  const MapCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Alert Map',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Interactive map will be implemented here',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
