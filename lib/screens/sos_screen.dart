import 'package:flutter/material.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "SOS / Reporting Screen",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
      ),
    );
  }
}