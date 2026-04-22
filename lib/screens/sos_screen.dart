import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../main.dart';
import '../send/send-heartbeat.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  String _selectedDept = 'Rescue';
  final TextEditingController _msgController = TextEditingController();
  bool _isSending = false;
  bool _sosSent = false;

  late AnimationController _ripple1;
  late AnimationController _ripple2;
  late AnimationController _ripple3;
  late AnimationController _colorFill;

  final List<Map<String, dynamic>> _departments = [
    {'name': 'Rescue',  'icon': Icons.support_rounded,               'color': Color(0xFFD96B45)},
    {'name': 'Medical', 'icon': Icons.medical_services_rounded,      'color': Color(0xFFE8A87C)},
    {'name': 'Fire',    'icon': Icons.local_fire_department_rounded,  'color': Color(0xFFE65C5C)},
    {'name': 'Police',  'icon': Icons.local_police_rounded,           'color': Color(0xFF5C8AE6)},
  ];

  @override
  void initState() {
    super.initState();
    _ripple1   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _ripple2   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _ripple3   = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _colorFill = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  void _startRipples() {
    _ripple1.repeat();
    Future.delayed(const Duration(milliseconds: 800),  () { if (mounted) _ripple2.repeat(); });
    Future.delayed(const Duration(milliseconds: 1600), () { if (mounted) _ripple3.repeat(); });
  }

  Future<void> _sendSos() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final additionalMsg = _msgController.text.trim();
      final success = await sendSosHeartbeat(
        department: _selectedDept,
        additionalMessage: additionalMsg,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          if (success) {
            _sosSent = true;
            _colorFill.forward();
            _startRipples();
          }
          _msgController.clear();
        });
        FocusScope.of(context).unfocus();

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SOS Broadcasted to Mesh Network!'),
              backgroundColor: Color(0xFFD96B45),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending SOS: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ripple1.dispose();
    _ripple2.dispose();
    _ripple3.dispose();
    _colorFill.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          // ── Full-screen light map background ──────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation:
                  Listenable.merge([_colorFill, _ripple1, _ripple2, _ripple3]),
              builder: (_, __) => CustomPaint(
                painter: _MapPainter(
                  sosSent:      _sosSent,
                  fillProgress: _colorFill.value,
                  ripple1:      _ripple1.value,
                  ripple2:      _ripple2.value,
                  ripple3:      _ripple3.value,
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BroadcastPanel(
              departments:   _departments,
              selectedDept:  _selectedDept,
              msgController: _msgController,
              isSending:     _isSending,
              sosSent:       _sosSent,
              onDeptChanged: (d) => setState(() => _selectedDept = d),
              onSend:        _sendSos,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom broadcast panel  (light themed)
// ─────────────────────────────────────────────────────────────────────────────

class _BroadcastPanel extends StatelessWidget {
  final List<Map<String, dynamic>> departments;
  final String selectedDept;
  final TextEditingController msgController;
  final bool isSending;
  final bool sosSent;
  final ValueChanged<String> onDeptChanged;
  final VoidCallback onSend;

  const _BroadcastPanel({
    required this.departments,
    required this.selectedDept,
    required this.msgController,
    required this.isSending,
    required this.sosSent,
    required this.onDeptChanged,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BeaconColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(
          top: BorderSide(color: BeaconColors.cardBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: BeaconColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.broadcast_on_personal_rounded,
                        color: BeaconColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency Broadcast',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: BeaconColors.textDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: BeaconColors.primary.withOpacity(0.25),
                        ),
                      ),
                      child: const Text(
                        'Offline',
                        style: TextStyle(
                          color: BeaconColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Department pills — horizontal scroll
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: departments.map((dept) {
                      final isSelected = selectedDept == dept['name'];
                      final baseColor  = dept['color'] as Color;
                      return GestureDetector(
                        onTap: () => onDeptChanged(dept['name'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? baseColor
                                : baseColor.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? baseColor
                                  : baseColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                dept['icon'] as IconData,
                                color: isSelected ? Colors.white : baseColor,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                dept['name'] as String,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : BeaconColors.textMid,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 12),

                // Message field with P2-14 voice-to-text mic button.
                _VoiceEnabledField(controller: msgController),

                const SizedBox(height: 12),

                // Send button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 52,
                  decoration: BoxDecoration(
                    color: sosSent
                        ? const Color(0xFFF5EBE6)
                        : const Color(0xFFD96B45),
                    borderRadius: BorderRadius.circular(16),
                    border: sosSent
                        ? Border.all(
                            color: const Color(0xFFD96B45).withOpacity(0.35))
                        : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSend,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: isSending
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: sosSent
                                      ? BeaconColors.primary
                                      : Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    sosSent
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.broadcast_on_personal_rounded,
                                    color: sosSent
                                        ? BeaconColors.primary
                                        : Colors.white,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    sosSent
                                        ? 'SOS Broadcasted'
                                        : 'SEND SOS BROADCAST',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: sosSent
                                          ? BeaconColors.primary
                                          : Colors.white,
                                      fontFamily: 'Inter',
                                      letterSpacing: sosSent ? 0 : 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light map painter
// ─────────────────────────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  final bool sosSent;
  final double fillProgress;
  final double ripple1;
  final double ripple2;
  final double ripple3;

  const _MapPainter({
    required this.sosSent,
    required this.fillProgress,
    required this.ripple1,
    required this.ripple2,
    required this.ripple3,
  });

  // How tall the bottom panel is (approximate) — pin sits above it
  static const double _sheetHeight = 262;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = (size.height - _sheetHeight) / 2;

    // ── Background ──────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF5F0EB),
    );

    _drawGrid(canvas, size);

    // ── Colored region after SOS ────────────────────────────────────────
    if (sosSent && fillProgress > 0) {
      _drawColoredRegion(canvas, size, cx, cy);
    }

    // ── Subtle ripples ──────────────────────────────────────────────────
    if (sosSent) {
      _drawRipple(canvas, cx, cy, ripple1);
      _drawRipple(canvas, cx, cy, ripple2);
      _drawRipple(canvas, cx, cy, ripple3);
    }

    // ── Location pin ────────────────────────────────────────────────────
    _drawLocationPin(canvas, cx, cy);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final color = sosSent
        ? Color.lerp(
            const Color(0xFFD9C4B5),
            const Color(0xFFE8A07A),
            fillProgress * 0.4,
          )!
        : const Color(0xFFDDD4C8);
    final p = Paint()..color = color..strokeWidth = 0.8;
    for (double y = 0; y < size.height; y += 26) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    for (double x = 0; x < size.width; x += 26) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
  }

  void _drawColoredRegion(Canvas canvas, Size size, double cx, double cy) {
    final maxRadius = size.width * 0.85;
    final radius    = maxRadius * fillProgress;

    // Warm amber/orange wash — subtle on the light background
    final shader = RadialGradient(
      colors: [
        const Color(0xFFD96B45).withOpacity(0.18),
        const Color(0xFFE8A07A).withOpacity(0.10),
        Colors.transparent,
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(
        Rect.fromCircle(center: Offset(cx, cy), radius: maxRadius));

    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()..shader = shader,
    );
  }

  void _drawRipple(Canvas canvas, double cx, double cy, double progress) {
    if (progress == 0) return;
    final maxR   = 120.0;
    final r      = maxR * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35; // very subtle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()
        ..color       = const Color(0xFFD96B45).withOpacity(opacity)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawLocationPin(Canvas canvas, double cx, double cy) {
    // Idle: dull orange-brown.  Active: vivid orange
    final pinColor =
        sosSent ? const Color(0xFFD96B45) : const Color(0xFFB07A55);
    final dotColor =
        sosSent ? Colors.white : const Color(0xFFF5EDE6);

    // Subtle glow when active
    if (sosSent) {
      canvas.drawCircle(
        Offset(cx, cy - 10),
        18,
        Paint()
          ..color      = const Color(0xFFD96B45).withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Pin body
    final path = Path();
    path.moveTo(cx, cy + 12);
    path.cubicTo(cx - 2, cy + 5, cx - 14, cy, cx - 14, cy - 10);
    path.arcToPoint(
      Offset(cx + 14, cy - 10),
      radius: const Radius.circular(14),
      clockwise: false,
    );
    path.cubicTo(cx + 14, cy, cx + 2, cy + 5, cx, cy + 12);
    path.close();
    canvas.drawPath(path, Paint()..color = pinColor);

    // Inner dot
    canvas.drawCircle(Offset(cx, cy - 10), 4.5, Paint()..color = dotColor);
  }

  @override
  bool shouldRepaint(_MapPainter o) =>
      o.fillProgress != fillProgress ||
      o.ripple1      != ripple1 ||
      o.ripple2      != ripple2 ||
      o.ripple3      != ripple3 ||
      o.sosSent      != sosSent;
}
// ─── Voice-enabled message field (P2-14) ────────────────────────────────────
class _VoiceEnabledField extends StatefulWidget {
  final TextEditingController controller;
  const _VoiceEnabledField({required this.controller});

  @override
  State<_VoiceEnabledField> createState() => _VoiceEnabledFieldState();
}

class _VoiceEnabledFieldState extends State<_VoiceEnabledField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttReady = false;
  bool _sttUnavailable = false;
  bool _listening = false;
  String _preListenBuffer = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ok = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening' || status == 'done') {
            if (mounted) setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
      if (!mounted) return;
      setState(() {
        _sttReady = ok;
        _sttUnavailable = !ok;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sttUnavailable = true);
    }
  }

  Future<void> _startListening() async {
    if (!_sttReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice input unavailable')),
      );
      return;
    }
    _preListenBuffer = widget.controller.text;
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        final combined = _preListenBuffer.isEmpty
            ? words
            : '$_preListenBuffer $words';
        widget.controller.text = combined;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    if (mounted) setState(() => _listening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeaconColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 14,
                color: BeaconColors.textDark,
                fontFamily: 'Inter',
              ),
              decoration: const InputDecoration(
                hintText: 'Additional details (optional)...',
                hintStyle: TextStyle(color: BeaconColors.textLight),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          // Tap-and-hold mic. Silently disabled if STT init failed — the
          // text field still works, which is the required graceful fallback.
          Padding(
            padding: const EdgeInsets.only(right: 6, top: 6),
            child: GestureDetector(
              onLongPressStart: _sttUnavailable
                  ? null
                  : (_) => _startListening(),
              onLongPressEnd: _sttUnavailable ? null : (_) => _stopListening(),
              onTap: _sttUnavailable
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voice input unavailable')),
                      );
                    }
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _listening
                      ? BeaconColors.primary
                      : _sttUnavailable
                          ? BeaconColors.cardBorder
                          : BeaconColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none_rounded,
                  size: 20,
                  color: _listening
                      ? Colors.white
                      : _sttUnavailable
                          ? BeaconColors.textLight
                          : BeaconColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
