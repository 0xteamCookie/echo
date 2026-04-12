import 'package:flutter/material.dart';
import '../main.dart';
import '../send/send-message.dart';
import '../packet/get-userName.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  String _myName = 'Anon';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final name = await UserSettings.getName();
    if (name.isNotEmpty) {
      setState(() {
        _myName = name;
      });
    }
  }

  void _editName() {
    final nameCtrl = TextEditingController(text: _myName);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Name Yourself"),
          content: TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(hintText: "Enter your name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameCtrl.text.trim().isEmpty
                    ? 'Anon'
                    : nameCtrl.text.trim();
                await UserSettings.setName(newName);
                setState(() {
                  _myName = newName;
                });
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _send() async {
    if (_controller.text.isEmpty) return;

    final textToSend = _controller.text;
    _controller.clear();

    await sendNewMessage(textToSend);

    final list = List<Map<String, dynamic>>.from(AppState().chatMessages.value);
    list.insert(0, {
      'message': textToSend,
      'deviceId': 'Me',
      'senderName': _myName,
      'time': DateTime.now().toIso8601String().substring(11, 16),
    });
    AppState().chatMessages.value = list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _editName,
            icon: const Icon(Icons.edit, size: 16),
            label: Text("Name: $_myName"),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AppState().chatMessages,
            builder: (context, messages, _) {
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    "No messages yet",
                    style: TextStyle(color: Colors.black38),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['message'] ?? '', style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          "From: ${msg['senderName'] ?? msg['deviceId']} • ${msg['time'] ?? 'Just now'}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                          ),
                        ),
                        Text(
                          "Relayed by: ${msg['relayerMac'] ?? 'Direct'}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black38,
                          ),
                        ),
                        if (msg['messageId'] != null)
                          Text("MsgID: ${msg['messageId']} ", 
                            style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(color: Colors.white),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Broadcast a message...",
                    filled: true,
                    fillColor: const Color(0xFFF9F6F0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFFE27D60),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: _send,
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}