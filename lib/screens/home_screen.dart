import 'package:flutter/material.dart';
import '../main.dart';
import '../models/rescuer_session.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppState().rescuerSession.value;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (session != null) ...[
          const SizedBox(height: 4),
          _RoleAssignmentCard(session: session),
          const SizedBox(height: 20),
        ],

        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Mesh Status',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: BeaconColors.textDark,
                fontFamily: 'Inter',
                height: 1.1,
              ),
            ),
            const Spacer(),
            _OfflineBadge(),
          ],
        ),
        const SizedBox(height: 20),

        _StatusCard(),
        const SizedBox(height: 32),

        const Text(
          'Announcements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: BeaconColors.textDark,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 8),

        _SimpleAnnouncement(
          text: 'Move to top of buildings. Flooding reported in lower sections.',
          time: '2 min ago',
          sender: 'Emergency Coord.',
        ),
        _SimpleAnnouncement(
          text: 'Medical team needed at Block C ground floor. Bring supplies.',
          time: '8 min ago',
          sender: 'Node-7F2A',
        ),
        _SimpleAnnouncement(
          text: 'Assembly point: East courtyard. All unassigned personnel gather for headcount.',
          time: '15 min ago',
          sender: 'Alpha-Team Lead',
        ),
        _SimpleAnnouncement(
          text: 'Power station is operational. The generator is running in the storage bay.',
          time: '22 min ago',
          sender: 'Node-3B9C',
        ),
        _SimpleAnnouncement(
          text: 'Sector 4 is all clear. Safe to transit through northern corridor.',
          time: '41 min ago',
          sender: 'Recon Team',
        ),
      ],
    );
  }
}

class _SimpleAnnouncement extends StatelessWidget {
  final String text;
  final String time;
  final String sender;

  const _SimpleAnnouncement({
    required this.text,
    required this.time,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                sender,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: BeaconColors.textDark,
                  fontFamily: 'Inter',
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 11,
                  color: BeaconColors.textLight,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: BeaconColors.textMid,
              fontFamily: 'Inter',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          const Divider(color: BeaconColors.cardBorder, height: 1),
        ],
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: BeaconColors.secondary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BeaconColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: BeaconColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Offline',
            style: TextStyle(
              color: BeaconColors.secondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatefulWidget {
  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> with SingleTickerProviderStateMixin {
  late AnimationController _ripple;

  @override
  void initState() {
    super.initState();
    _ripple = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ripple.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: AppState().devices,
      builder: (context, devices, _) {
        final count = devices.length;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD96B45), Color(0xFFE8945A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: BeaconColors.primary.withOpacity(0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: AnimatedBuilder(
                  animation: _ripple,
                  builder: (_, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(2, (i) {
                          final delay = i * 0.4;
                          final t = ((_ripple.value + delay) % 1.0);
                          return Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 0.5 + t * 0.5,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.25),
                                ),
                              ),
                            ),
                          );
                        }),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 22),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mesh Network',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Active & Stable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      count == 0
                          ? 'Scanning for peers…'
                          : '$count peer${count == 1 ? '' : 's'} in range',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text('nodes', style: TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'Inter')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoleAssignmentCard extends StatelessWidget {
  final RescuerSession session;
  const _RoleAssignmentCard({required this.session});

  Color get _roleColor {
    switch (session.role.toLowerCase()) {
      case 'medic':
        return const Color(0xFFE74C3C);
      case 'search':
        return const Color(0xFF3498DB);
      case 'logistics':
        return const Color(0xFFF39C12);
      case 'comms':
        return const Color(0xFF9B59B6);
      default:
        return BeaconColors.secondary;
    }
  }

  IconData get _roleIcon {
    switch (session.role.toLowerCase()) {
      case 'medic':
        return Icons.medical_services_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'logistics':
        return Icons.inventory_2_rounded;
      case 'comms':
        return Icons.cell_tower_rounded;
      default:
        return Icons.shield_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_roleColor, _roleColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _roleColor.withOpacity(0.30),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Role icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_roleIcon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          // Name & details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${session.radiusM.toInt()}m zone assigned',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              session.role.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
