import 'package:flutter/material.dart';
import '../database/db_hook.dart';

class AckDbScreen extends StatefulWidget {
  const AckDbScreen({super.key});

  @override
  State<AckDbScreen> createState() => _AckDbScreenState();
}

class _AckDbScreenState extends State<AckDbScreen> {
  List<Map<String, dynamic>> _acks = [];

  @override
  void initState() {
    super.initState();
    _loadAcks();
  }

  Future<void> _loadAcks() async {
    final acks = await getAllMessageDevices();
    setState(() {
      _acks = acks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACK DB'),
        backgroundColor: const Color(0xFFF9F6F0),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAcks,
          )
        ],
      ),
      body: _acks.isEmpty
          ? const Center(child: Text("Ack Database is empty.", style: TextStyle(color: Colors.black38)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _acks.length,
              itemBuilder: (context, i) {
                final ack = _acks[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("MsgID: ${ack['messageId']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Device / MAC: ${ack['deviceId']}", style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
