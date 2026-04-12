import 'package:flutter/material.dart';
import '../main.dart';
import '../send/send-heartbeat.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF85DCB8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                ),
                onPressed: () => startHeartbeat("Emergency Heartbeat"), 
                icon: const Icon(Icons.play_arrow), 
                label: const Text("Start SOS")
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                ),
                onPressed: () => stopHeartbeat(), 
                icon: const Icon(Icons.stop), 
                label: const Text("Stop")
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AppState().heartbeats,
            builder: (context, beats, _) {
              if (beats.isEmpty) return const Center(child: Text("No active heartbeats", style: TextStyle(color: Colors.black38)));
              
              return ListView.builder(
                itemCount: beats.length,
                itemBuilder: (context, i) {
                  final b = beats[i];
                  return ListTile(
                    leading: const Icon(Icons.favorite, color: Color(0xFFE27D60)),
                    title: Text(b['message'] ?? 'Heartbeat'),
                    subtitle: Text(b['deviceId'] ?? 'System'),
                  );
                },
              );
            },
          ),
        )
      ],
    );
  }
}