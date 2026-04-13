import 'package:flutter/material.dart';
import '../main.dart';
import '../central/intialize.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nearby Nodes"), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: restartScan)
      ]),
      body: ValueListenableBuilder<List<Map<String, dynamic>>>(
        valueListenable: AppState().devices,
        builder: (context, devs, _) {
          if (devs.isEmpty) return const Center(child: Text("No devices found", style: TextStyle(color: Colors.black38)));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: devs.length,
            itemBuilder: (context, i) {
              final d = devs[i];
              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.bluetooth, color: Color(0xFFE27D60)),
                  title: Text(d['name'] ?? 'Unknown Node'),
                  subtitle: Text("${d['id']}\nRSSI: ${d['rssi']} dBm"),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}