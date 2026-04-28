import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../central/intialize.dart';
import '../core/constants.dart';
import '../database/db_hook.dart';
import '../main.dart';
import '../mesh/packet_codec.dart';
import '../packet/get_device_id.dart';
import '../packet/get_location.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<Map<String, dynamic>> _incidents = [];
  bool _loading = true;
  bool _broadcasting = false;
  Timer? _refreshTimer;

  ({double lat, double lng})? _myLoc;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _resolveMyLocation();
    await _loadIncidents();
    if (mounted) setState(() => _loading = false);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadIncidents(),
    );
  }

  Future<void> _resolveMyLocation() async {
    try {
      final loc = await getCurrentLocationString();
      final parts = loc.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          _myLoc = (lat: lat, lng: lng);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadIncidents() async {
    try {
      final rows = await getReportableIncidents(withinHours: 24);
      final session = AppState().rescuerSession.value;

      final filtered = session == null
          ? List<Map<String, dynamic>>.from(rows)
          : rows.where((r) {
              final loc = _parseLatLng(r['location']?.toString());
              if (loc == null) return true;
              return haversineMeters(
                    loc.$1,
                    loc.$2,
                    session.lat,
                    session.lng,
                  ) <=
                  session.radiusM;
            }).toList();

      if (filtered.isEmpty) {
        filtered.addAll([
          {
            'messageId': 'dummy-1',
            'senderName': 'Jane Doe',
            'message':
                'I have fallen and cannot get up. Need medical assistance.',
            'time': DateTime.now()
                .subtract(const Duration(minutes: 12))
                .toIso8601String(),
            'location': '34.0522,-118.2437',
            'ackStatus': 'ack',
          },
          {
            'messageId': 'dummy-2',
            'senderName': 'John Smith',
            'message':
                'Stranded due to severe flooding, need immediate rescue.',
            'time': DateTime.now()
                .subtract(const Duration(minutes: 2))
                .toIso8601String(),
            'location': '34.0525,-118.2430',
            'ackStatus': null,
          },
        ]);
      }

      if (mounted) setState(() => _incidents = filtered);
    } catch (e) {
      debugPrint('Report load failed: $e');
    }
  }

  Future<void> _setStatus(Map<String, dynamic> row, String status) async {
    if (_broadcasting) return;
    final messageId = row['messageId']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    setState(() => _broadcasting = true);
    try {
      await updateAckStatus(messageId, status);

      final deviceId = await DeviceIdManager.getDeviceId();
      final ackFrame = encodeAck(messageId, deviceId, status: status);
      await blastToEntireMesh(utf8.encode(ackFrame));

      await _loadIncidents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Marked as ${_statusLabel(status)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Broadcast failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _broadcasting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadIncidents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
          ? _EmptyState(onRefresh: _loadIncidents)
          : RefreshIndicator(
              onRefresh: _loadIncidents,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _incidents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _IncidentCard(
                  row: _incidents[i],
                  myLoc: _myLoc,
                  onStatus: _setStatus,
                  busy: _broadcasting,
                ),
              ),
            ),
    );
  }

  static (double, double)? _parseLatLng(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat, lng);
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'enroute':
        return 'En-route';
      case 'resolved':
        return 'Resolved';
      default:
        return 'Acknowledged';
    }
  }
}

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = kEarthRadiusMetres;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLng = (lng2 - lng1) * math.pi / 180.0;
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLng / 2) *
          math.sin(dLng / 2) *
          math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(a)));
}

class _IncidentCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final ({double lat, double lng})? myLoc;
  final Future<void> Function(Map<String, dynamic> row, String status) onStatus;
  final bool busy;

  const _IncidentCard({
    required this.row,
    required this.myLoc,
    required this.onStatus,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final senderName =
        (row['senderName']?.toString().trim().isNotEmpty ?? false)
        ? row['senderName'].toString()
        : 'Unknown';
    final message = row['message']?.toString() ?? '';
    final timeStr = _formatTime(row['time']?.toString());
    final distLabel = _distanceLabel(row['location']?.toString(), myLoc);
    final currentStatus = row['ackStatus']?.toString();

    return Container(
      decoration: BoxDecoration(
        color: BeaconColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: BeaconColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: BeaconColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: BeaconColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: BeaconColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (timeStr.isNotEmpty) timeStr,
                        if (distLabel != null) distLabel,
                      ].join(' · '),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: BeaconColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              if (currentStatus != null) _StatusPill(status: currentStatus),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: BeaconColors.textDark,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Acknowledge',
                  icon: Icons.check_circle_outline,
                  color: BeaconColors.secondary,
                  selected: currentStatus == 'ack',
                  onPressed: busy ? null : () => onStatus(row, 'ack'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'En-route',
                  icon: Icons.directions_run,
                  color: BeaconColors.accent,
                  selected: currentStatus == 'enroute',
                  onPressed: busy ? null : () => onStatus(row, 'enroute'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Resolved',
                  icon: Icons.task_alt,
                  color: BeaconColors.primary,
                  selected: currentStatus == 'resolved',
                  onPressed: busy ? null : () => onStatus(row, 'resolved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    final local = t.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  static String? _distanceLabel(
    String? location,
    ({double lat, double lng})? me,
  ) {
    if (location == null || me == null) return null;
    final parts = location.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    final m = haversineMeters(me.lat, me.lng, lat, lng);
    if (m < 1000) return '${m.toStringAsFixed(0)}m away';
    return '${(m / 1000).toStringAsFixed(1)}km away';
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'enroute' => ('EN-ROUTE', BeaconColors.accent),
      'resolved' => ('RESOLVED', BeaconColors.primary),
      _ => ('ACK', BeaconColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? color : color.withOpacity(0.12);
    final fg = selected ? Colors.white : color;
    return SizedBox(
      height: 40,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: fg),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        style: TextButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        children: const [
          SizedBox(height: 160),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: BeaconColors.textLight,
                ),
                SizedBox(height: 12),
                Text(
                  'No recent incidents in your zone.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: BeaconColors.textMid,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
