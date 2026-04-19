import 'package:flutter/material.dart';
import '../main.dart';
import '../send/send-message.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  String _selectedDept = 'Rescue';
  final TextEditingController _msgController = TextEditingController();
  bool _isSending = false;

  final List<Map<String, dynamic>> _departments = [
    {'name': 'Rescue', 'icon': Icons.support_rounded, 'color': Color(0xFFD96B45)},
    {'name': 'Medical', 'icon': Icons.medical_services_rounded, 'color': Color(0xFFE8A87C)},
    {'name': 'Fire', 'icon': Icons.local_fire_department_rounded, 'color': Color(0xFFE65C5C)},
    {'name': 'Police', 'icon': Icons.local_police_rounded, 'color': Color(0xFF5C8AE6)},
  ];

  Future<void> _sendSos() async {
    if (_isSending) return;
    setState(() => _isSending = true);

    // Format the payload and flag as SOS
    final additionalMsg = _msgController.text.trim();
    final text = "[${_selectedDept.toUpperCase()}] ${additionalMsg.isNotEmpty ? additionalMsg : 'Needs immediate assistance.'}";
    
    await sendNewMessage(text, isSos: true);

    if (mounted) {
      setState(() {
        _isSending = false;
        _msgController.clear();
      });
      FocusScope.of(context).unfocus(); // Close keyboard
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SOS Broadcasted to Mesh Network!'),
          backgroundColor: Color(0xFFD96B45),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _SosHeaderCard(),
                ),
                
                // ─── Send SOS Panel ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Broadcast Emergency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: BeaconColors.textDark,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Department Cards
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: _departments.map((dept) {
                            final isSelected = _selectedDept == dept['name'];
                            final baseColor = dept['color'] as Color;
                            
                            return GestureDetector(
                              onTap: () => setState(() => _selectedDept = dept['name'] as String),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 70,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? baseColor : baseColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? baseColor : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      dept['icon'] as IconData,
                                      color: isSelected ? Colors.white : baseColor,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      dept['name'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                        color: isSelected ? Colors.white : BeaconColors.textMid,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        
                        // Message Text Box
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9F9F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: TextField(
                            controller: _msgController,
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
                              contentPadding: EdgeInsets.all(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Send Button
                        InkWell(
                          onTap: _sendSos,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFD96B45), Color(0xFFB84A2A)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD96B45).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Center(
                              child: _isSending 
                                ? const SizedBox(
                                    height: 20, 
                                    width: 20, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  )
                                : const Text(
                                    'SEND SOS BROADCAST',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      fontFamily: 'Inter',
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Active Heartbeats Header ────────────────────────────────
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
              ],
            ),
          ),
          
          // ─── Active Heartbeats List ────────────────────────────────────────
          SliverFillRemaining(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: AppState().heartbeats,
              builder: (context, beats, _) {
                if (beats.isEmpty) {
                  return _EmptyHeartbeats();
                }
                return ListView.builder(
                  physics: const NeverScrollableScrollPhysics(), // Managed by CustomScrollView
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: beats.length,
                  itemBuilder: (context, i) {
                    return _HeartbeatTile(beat: beats[i], index: i);
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

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