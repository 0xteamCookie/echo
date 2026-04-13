import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        const Text(
          "Announcements", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF4A4A4A)),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFF85DCB8).withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.campaign, color: Color(0xFF85DCB8)),
                  ),
                  const SizedBox(width: 12),
                  const Text("Announcements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Mesh Network is currently stable. Ensure Bluetooth remains on for uninterrupted connectivity.",
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}