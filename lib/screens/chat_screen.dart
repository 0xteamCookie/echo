import 'package:flutter/material.dart';
import '../main.dart';
import '../send/send-message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  void _send() async {
    if (_controller.text.isEmpty) return;
    
    final textToSend = _controller.text;
    _controller.clear();

    await sendNewMessage(textToSend);

    final list = List<Map<String, dynamic>>.from(AppState().chatMessages.value);
    list.insert(0, {
      'message': textToSend,
      'deviceId': 'Me',
      'time': DateTime.now().toIso8601String().substring(11, 16),
    });
    AppState().chatMessages.value = list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AppState().chatMessages,
            builder: (context, messages, _) {
              if (messages.isEmpty) {
                return const Center(child: Text("No messages yet", style: TextStyle(color: Colors.black38)));
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
                        Text("From: ${msg['deviceId']} • ${msg['time'] ?? 'Just now'}", 
                          style: const TextStyle(fontSize: 10, color: Colors.black38)),
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