import 'package:flutter/material.dart';
import '../main.dart';
import '../send/send_heartbeat.dart';
import '../services/activity_monitor.dart';

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

  late AnimationController _rippleAnim;

  final List<Map<String, dynamic>> _departments = [
    {
      'name': 'Rescue',
      'icon': Icons.support_rounded,
      'color': const Color(0xFFD96B45),
    },
    {
      'name': 'Medical',
      'icon': Icons.medical_services_rounded,
      'color': const Color(0xFFE8A87C),
    },
    {
      'name': 'Fire',
      'icon': Icons.local_fire_department_rounded,
      'color': const Color(0xFFE65C5C),
    },
    {
      'name': 'Police',
      'icon': Icons.local_police_rounded,
      'color': const Color(0xFF5C8AE6),
    },
  ];

  @override
  void initState() {
    super.initState();
    _rippleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  void _startRipple() {
    _rippleAnim.forward(from: 0.0).then((_) {
      if (mounted) _rippleAnim.repeat();
    });
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
            _startRipple();
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
    _rippleAnim.dispose();
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Emergency',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D2A26),
                        fontFamily: 'Inter',
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EB).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFD96B45).withOpacity(0.25),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: AnimatedBuilder(
                animation: _rippleAnim,
                builder: (_, __) => CustomPaint(
                  painter: _RadarPainter(
                    isBroadcasting: _sosSent,
                    progress: _rippleAnim.value,
                  ),
                  child: Container(),
                ),
              ),
            ),

            // ── Bottom Panel ───────────────────────────
            _BroadcastPanel(
              departments: _departments,
              selectedDept: _selectedDept,
              msgController: _msgController,
              isSending: _isSending,
              sosSent: _sosSent,
              onDeptChanged: (d) => setState(() => _selectedDept = d),
              onSend: _sendSos,
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final bool isBroadcasting;
  final double progress;

  _RadarPainter({required this.isBroadcasting, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final center = Offset(cx, cy);
    final maxRadius = size.width * 0.45;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFD96B45).withOpacity(0.04);

    canvas.drawCircle(center, maxRadius * 0.4, bgPaint);
    canvas.drawCircle(center, maxRadius * 0.8, bgPaint);

    if (isBroadcasting) {
      // Draw 3 staggered expanding ripples
      _drawRipple(canvas, center, progress, maxRadius);
      _drawRipple(canvas, center, (progress + 0.33) % 1.0, maxRadius);
      _drawRipple(canvas, center, (progress + 0.66) % 1.0, maxRadius);
    }

    // ── The Center Beacon Icon ──
    final baseColor = isBroadcasting
        ? const Color(0xFFD96B45)
        : const Color(0xFFB07A55);

    // Outer soft glow
    canvas.drawCircle(
      center,
      36,
      Paint()..color = baseColor.withOpacity(isBroadcasting ? 0.15 : 0.08),
    );
    // Mid ring
    canvas.drawCircle(
      center,
      24,
      Paint()..color = baseColor.withOpacity(isBroadcasting ? 0.3 : 0.2),
    );
    // Core dot
    canvas.drawCircle(center, 12, Paint()..color = baseColor);
    // Inner light
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  void _drawRipple(Canvas canvas, Offset center, double t, double maxRadius) {
    final radius = maxRadius * t;
    final opacity = 1.0 - t; // Fades out as it gets larger

    final ripplePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth =
          2.0 +
          (2.0 * (1 - t)) // Slightly thicker near the center
      ..color = const Color(0xFFD96B45).withOpacity(opacity * 0.6);

    canvas.drawCircle(center, radius, ripplePaint);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.isBroadcasting != isBroadcasting ||
      oldDelegate.progress != progress;
}

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
        border: const Border(top: BorderSide(color: BeaconColors.cardBorder)),
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
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: List.generate(departments.length, (i) {
                    final dept = departments[i];
                    final isSelected = selectedDept == dept['name'];
                    final baseColor = dept['color'] as Color;
                    final isLast = i == departments.length - 1;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onDeptChanged(dept['name'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.only(right: isLast ? 0 : 8),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? baseColor
                                : baseColor.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? baseColor
                                  : baseColor.withOpacity(0.22),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                dept['icon'] as IconData,
                                color: isSelected ? Colors.white : baseColor,
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dept['name'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : baseColor.withOpacity(0.85),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 14),
                _MessageField(controller: msgController),
                const SizedBox(height: 12),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 54,
                  decoration: BoxDecoration(
                    color: sosSent
                        ? const Color(0xFFF5EBE6)
                        : const Color(0xFFD96B45),
                    borderRadius: BorderRadius.circular(16),
                    border: sosSent
                        ? Border.all(
                            color: const Color(0xFFD96B45).withOpacity(0.35),
                            width: 1.5,
                          )
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
                                    sosSent ? 'Broadcasted' : 'SEND SOS',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: sosSent
                                          ? BeaconColors.primary
                                          : Colors.white,
                                      fontFamily: 'Inter',
                                      letterSpacing: sosSent ? 0 : 0.6,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                const _AutoSosTile(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageField extends StatelessWidget {
  final TextEditingController controller;
  const _MessageField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeaconColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        maxLines: 2,
        style: const TextStyle(
          fontSize: 14,
          color: BeaconColors.textDark,
          fontFamily: 'Inter',
        ),
        decoration: const InputDecoration(
          hintText: 'Details...',
          hintStyle: TextStyle(color: BeaconColors.textLight),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(14),
        ),
      ),
    );
  }
}

class _AutoSosTile extends StatefulWidget {
  const _AutoSosTile();

  @override
  State<_AutoSosTile> createState() => _AutoSosTileState();
}

class _AutoSosTileState extends State<_AutoSosTile> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await ActivityMonitor.isEnabled();
    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool v) async {
    setState(() => _enabled = v);
    await ActivityMonitor.setEnabled(v);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          v
              ? 'Auto-SOS enabled — fall detection is active.'
              : 'Auto-SOS disabled.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BeaconColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: BeaconColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.accessibility_new_rounded,
              color: BeaconColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Auto-SOS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BeaconColors.textDark,
                    fontFamily: 'Inter',
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Fall detection · 30s countdown',
                  style: TextStyle(
                    fontSize: 11,
                    color: BeaconColors.textMid,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: enabled,
            activeColor: BeaconColors.primary,
            onChanged: _enabled == null ? null : _toggle,
          ),
        ],
      ),
    );
  }
}
