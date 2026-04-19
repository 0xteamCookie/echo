import 'package:flutter/material.dart';
import '../main.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Header card ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _SosHeaderCard(),
        ),
        const SizedBox(height: 8),

        // ── Section label ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Active Heartbeats',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: BeaconColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: AppState().heartbeats,
                builder: (_, beats, __) => _CountBadge(count: beats.length),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Heartbeat list ────────────────────────────────────────────────────
        Expanded(
          child: ValueListenableBuilder<List<Map<String, dynamic>>>(
            valueListenable: AppState().heartbeats,
            builder: (context, beats, _) {
              if (beats.isEmpty) {
                return _EmptyHeartbeats();
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: beats.length,
                itemBuilder: (context, i) {
                  return _HeartbeatTile(beat: beats[i], index: i);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── SOS header card (always offline) ────────────────────────────────────────
class _SosHeaderCard extends StatefulWidget {
  @override
  State<_SosHeaderCard> createState() => _SosHeaderCardState();
}

class _SosHeaderCardState extends State<_SosHeaderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: BeaconColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: BeaconColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing heart icon
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFFE8E1),
                    const Color(0xFFFFCFBF),
                    _pulse.value,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: Color.lerp(
                    const Color(0xFFD96B45),
                    const Color(0xFFB84A2A),
                    _pulse.value,
                  ),
                  size: 26,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SOS Monitoring',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: BeaconColors.textDark,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Heartbeat signals from your mesh peers appear here in real-time, no internet required.',
                  style: TextStyle(
                    fontSize: 12,
                    color: BeaconColors.textMid,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Offline badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BeaconColors.primary.withOpacity(0.3)),
            ),
            child: const Text(
              'Offline',
              style: TextStyle(
                color: BeaconColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Count badge ──────────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0
            ? BeaconColors.primary.withOpacity(0.12)
            : BeaconColors.cardBorder,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: count > 0 ? BeaconColors.primary : BeaconColors.textLight,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────
class _EmptyHeartbeats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0EB),
              shape: BoxShape.circle,
              border: Border.all(color: BeaconColors.primary.withOpacity(0.15)),
            ),
            child: const Icon(
              Icons.favorite_border_rounded,
              size: 38,
              color: BeaconColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No heartbeats detected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: BeaconColors.textMid,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'SOS heartbeat signals from nearby peers will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: BeaconColors.textLight,
                fontFamily: 'Inter',
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Heartbeat tile ───────────────────────────────────────────────────────────
class _HeartbeatTile extends StatefulWidget {
  final Map<String, dynamic> beat;
  final int index;

  const _HeartbeatTile({required this.beat, required this.index});

  @override
  State<_HeartbeatTile> createState() => _HeartbeatTileState();
}

class _HeartbeatTileState extends State<_HeartbeatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeIn  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Stagger by index
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.beat;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: BeaconColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: BeaconColors.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.favorite_rounded, color: BeaconColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b['message'] ?? 'Heartbeat',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: BeaconColors.textDark,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.cell_tower_rounded, size: 12, color: BeaconColors.textLight),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            b['deviceId'] ?? 'Unknown node',
                            style: const TextStyle(
                              fontSize: 12,
                              color: BeaconColors.textLight,
                              fontFamily: 'Inter',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (b['time'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        b['time'],
                        style: const TextStyle(
                          fontSize: 11,
                          color: BeaconColors.textLight,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: BeaconColors.secondary,
                    fontFamily: 'Inter',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}