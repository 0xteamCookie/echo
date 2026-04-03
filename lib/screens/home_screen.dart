import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Announcement Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text("Announcements", style: TextStyle(fontSize: 18)),
              ),
            ),
            const Spacer(),
            const Text("Home Feed Content Goes Here"),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}