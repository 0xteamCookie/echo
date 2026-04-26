import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../send/send_message.dart';
import '../packet/get_user_name.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _myName = 'Anon';

  late AnimationController _sendAnim;

  @override
  void initState() {
    super.initState();
    _loadName();
    _sendAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _sendAnim.dispose();
    super.dispose();
  }

  Future<void> _loadName() async {
    final name = await UserSettings.getName();
    if (name.isNotEmpty && mounted) {
      setState(() => _myName = name);
    }
  }

  void _editName() {
    HapticFeedback.lightImpact();
    final nameCtrl = TextEditingController(text: _myName);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: BeaconColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: BeaconColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: BeaconColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Your Name',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BeaconColors.textDark,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'This name is broadcast with every message you send.',
                style: TextStyle(
                  color: BeaconColors.textMid,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  color: BeaconColors.textDark,
                  fontFamily: 'Inter',
                ),
                decoration: const InputDecoration(hintText: 'Enter your name…'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BeaconColors.textMid,
                        side: const BorderSide(color: BeaconColors.cardBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontFamily: 'Inter'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BeaconColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final newName = nameCtrl.text.trim().isEmpty
                            ? 'Anon'
                            : nameCtrl.text.trim();
                        await UserSettings.setName(newName);
                        if (mounted) setState(() => _myName = newName);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _send() async {
    if (_controller.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();

    final textToSend = _controller.text.trim();
    _controller.clear();

    // Button micro-animation
    _sendAnim.forward().then((_) => _sendAnim.reverse());

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
        // ── Name chip ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: GestureDetector(
            onTap: _editName,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: BeaconColors.surfaceWarm,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BeaconColors.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: BeaconColors.textMid,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _myName,
                    style: const TextStyle(
                      color: BeaconColors.textDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: BeaconColors.textLight,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Messages list ─────────────────────────────────────────────────
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AppState().chatMessages,
            builder: (context, messages, _) {
              if (messages.isEmpty) {
                return _EmptyChat();
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final msg = messages[i];
                  final isMe = msg['deviceId'] == 'Me';
                  return _MessageBubble(msg: msg, isMe: isMe);
                },
              );
            },
          ),
        ),

        // ── Composer ──────────────────────────────────────────────────────
        _Composer(
          controller: _controller,
          focusNode: _focusNode,
          sendAnim: _sendAnim,
          onSend: _send,
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: BeaconColors.surfaceWarm,
              shape: BoxShape.circle,
              border: Border.all(color: BeaconColors.cardBorder),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 36,
              color: BeaconColors.textLight,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BeaconColors.textMid,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to broadcast!',
            style: TextStyle(
              fontSize: 13,
              color: BeaconColors.textLight,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────
class _MessageBubble extends StatefulWidget {
  final Map<String, dynamic> msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isMe = widget.isMe;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                _Avatar(name: msg['senderName'] ?? msg['deviceId'] ?? '?'),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 3),
                        child: Text(
                          msg['senderName'] ?? msg['deviceId'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: BeaconColors.textMid,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isMe
                            ? BeaconColors.primary
                            : BeaconColors.surface,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(isMe ? 18 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 18),
                        ),
                        border: isMe
                            ? null
                            : Border.all(color: BeaconColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: (isMe ? BeaconColors.primary : Colors.black)
                                .withOpacity(isMe ? 0.2 : 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        msg['message'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isMe ? Colors.white : BeaconColors.textDark,
                          fontFamily: 'Inter',
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg['time'] ?? 'Just now',
                          style: const TextStyle(
                            fontSize: 10,
                            color: BeaconColors.textLight,
                            fontFamily: 'Inter',
                          ),
                        ),
                        if (msg['relayerMac'] != null) ...[
                          const Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 10,
                              color: BeaconColors.textLight,
                            ),
                          ),
                          const Icon(
                            Icons.shuffle_rounded,
                            size: 10,
                            color: BeaconColors.textLight,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'relayed',
                            style: const TextStyle(
                              fontSize: 10,
                              color: BeaconColors.textLight,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                        if (msg['messageId'] != null) ...[
                          const Text(
                            '  ·  ',
                            style: TextStyle(
                              fontSize: 10,
                              color: BeaconColors.textLight,
                            ),
                          ),
                          Text(
                            '#${(msg['messageId'] as String).length > 6 ? (msg['messageId'] as String).substring(0, 6) : msg['messageId']}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: BeaconColors.textLight,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isMe) const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Avatar ───────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    const colors = [
      Color(0xFFD96B45),
      Color(0xFF6BBFA0),
      Color(0xFFE8A87C),
      Color(0xFF9B7FD4),
      Color(0xFF5B9BD5),
    ];
    final color = colors[name.hashCode.abs() % colors.length];

    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }
}

// ─── Composer ─────────────────────────────────────────────────────────────────
class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final AnimationController sendAnim;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.sendAnim,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: BeaconColors.navBg,
        border: Border(top: BorderSide(color: BeaconColors.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                color: BeaconColors.textDark,
                fontFamily: 'Inter',
                fontSize: 15,
              ),
              decoration: const InputDecoration(
                hintText: 'Broadcast a message…',
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) {
              final hasText = val.text.trim().isNotEmpty;
              return ScaleTransition(
                scale: Tween<double>(begin: 1.0, end: 0.88).animate(
                  CurvedAnimation(parent: sendAnim, curve: Curves.easeInOut),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: hasText
                        ? BeaconColors.primary
                        : BeaconColors.cardBorder,
                    shape: BoxShape.circle,
                    boxShadow: hasText
                        ? [
                            BoxShadow(
                              color: BeaconColors.primary.withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, size: 18),
                    color: hasText ? Colors.white : BeaconColors.textLight,
                    onPressed: hasText ? onSend : null,
                    padding: EdgeInsets.zero,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
