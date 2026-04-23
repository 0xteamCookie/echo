import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../map/geo_circle.dart';
import '../map/offline_map_manager.dart';
import '../packet/get-location.dart';
import '../main.dart';
import '../models/rescuer_session.dart';

/// Shows the rescuer's assigned zone on a map with a highlighted region circle.
/// Centred on the JWT-assigned lat/lng with radius_m as the zone boundary.
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  String _tilePath = '';
  bool _isLoading = true;
  bool _isDownloading = false;
  final MapController _mapController = MapController();

  RescuerSession? get _session => AppState().rescuerSession.value;

  LatLng get _center => _session != null
      ? LatLng(_session!.lat, _session!.lng)
      : const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final dir = await getApplicationDocumentsDirectory();
    _tilePath = '${dir.path}/offline_tiles/{z}/{x}/{y}.png';

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadLargeArea() async {
    setState(() => _isDownloading = true);
    try {
      String locStr = await getCurrentLocationString();
      if (locStr.contains(',')) {
        final parts = locStr.split(',');
        double lat = double.parse(parts[0].trim());
        double lng = double.parse(parts[1].trim());
        await OfflineMapManager.downloadLargeAreaLowRes(lat, lng);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('7km low-res map downloaded around you!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get current location.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _clearCache() async {
    await OfflineMapManager.clearOfflineMapCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map cache deleted!')),
      );
    }
  }

  Future<void> _centerOnUser() async {
    try {
      String locStr = await getCurrentLocationString();
      if (locStr.contains(',')) {
        final parts = locStr.split(',');
        double lat = double.parse(parts[0].trim());
        double lng = double.parse(parts[1].trim());
        _mapController.move(LatLng(lat, lng), 15.0);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get current location.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Parse SOS heartbeats that have valid lat,lng locations into map markers.
  List<Marker> _buildSosMarkers() {
    final sosList = AppState().heartbeats.value;
    final markers = <Marker>[];

    for (final sos in sosList) {
      final locStr = (sos['location'] ?? '').toString();
      if (!locStr.contains(',')) continue;

      final parts = locStr.split(',');
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null || (lat == 0 && lng == 0)) continue;

      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showSosDetail(sos),
            child: _SosDot(sos: sos),
          ),
        ),
      );
    }

    return markers;
  }

  /// Show a bottom sheet with full SOS details.
  void _showSosDetail(Map<String, dynamic> sos) {
    final message = (sos['message'] ?? '').toString();
    final senderName = (sos['senderName'] ?? 'Unknown').toString();
    final location = (sos['location'] ?? '').toString();
    final expiresAt = (sos['expiresAt'] ?? '').toString();
    final deviceId = (sos['deviceId'] ?? '').toString();

    // Parse department from message like "[RESCUE] some text"
    String department = 'Unknown';
    String body = message;
    final deptMatch = RegExp(r'^\[([A-Z]+)\]\s*').firstMatch(message);
    if (deptMatch != null) {
      department = deptMatch.group(1)!;
      body = message.substring(deptMatch.end);
    }

    // Parse time
    String timeStr = '';
    if (expiresAt.isNotEmpty) {
      try {
        // expiresAt is creation + 1 day, so subtract 1 day to get sent time
        final expires = DateTime.parse(expiresAt);
        final sent = expires.subtract(const Duration(days: 1));
        final now = DateTime.now();
        final diff = now.difference(sent);
        if (diff.inMinutes < 1) {
          timeStr = 'Just now';
        } else if (diff.inMinutes < 60) {
          timeStr = '${diff.inMinutes}m ago';
        } else if (diff.inHours < 24) {
          timeStr = '${diff.inHours}h ago';
        } else {
          timeStr = '${diff.inDays}d ago';
        }
      } catch (_) {
        timeStr = expiresAt;
      }
    }

    final deptColor = _deptColor(department);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BeaconColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: deptColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _deptIcon(department),
                    color: deptColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: BeaconColors.textDark,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: BeaconColors.textMid,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: deptColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    department,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: deptColor,
                      fontFamily: 'Inter',
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Message body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6F3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: BeaconColors.cardBorder),
              ),
              child: Text(
                body.isNotEmpty ? body : 'No additional message.',
                style: const TextStyle(
                  fontSize: 14,
                  color: BeaconColors.textDark,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Info rows
            _infoRow(Icons.location_on_outlined, 'Location', location),
            const SizedBox(height: 6),
            _infoRow(Icons.perm_device_info_outlined, 'Device', deviceId),

            const SizedBox(height: 16),

            // Close button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: deptColor.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Close',
                  style: TextStyle(
                    color: deptColor,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 15, color: BeaconColors.textLight),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: BeaconColors.textMid,
            fontFamily: 'Inter',
          ),
        ),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
              fontSize: 12,
              color: BeaconColors.textMid,
              fontFamily: 'Inter',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static Color _deptColor(String dept) {
    switch (dept.toUpperCase()) {
      case 'RESCUE':
        return const Color(0xFFD96B45);
      case 'MEDICAL':
        return const Color(0xFFE8A87C);
      case 'FIRE':
        return const Color(0xFFE65C5C);
      case 'POLICE':
        return const Color(0xFF5C8AE6);
      default:
        return const Color(0xFFD96B45);
    }
  }

  static IconData _deptIcon(String dept) {
    switch (dept.toUpperCase()) {
      case 'RESCUE':
        return Icons.support_rounded;
      case 'MEDICAL':
        return Icons.medical_services_rounded;
      case 'FIRE':
        return Icons.local_fire_department_rounded;
      case 'POLICE':
        return Icons.local_police_rounded;
      default:
        return Icons.sos_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No zone assigned.\nScan a QR token to get your assignment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BeaconColors.textMid,
              fontSize: 15,
              fontFamily: 'Inter',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_center_focus),
            tooltip: 'Centre on zone',
            onPressed: () => _mapController.move(_center, 15.0),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Centre on me',
            onPressed: _centerOnUser,
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download 7km area (low res)',
            onPressed: _isDownloading ? null : _downloadLargeArea,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete map cache',
            onPressed: _isDownloading ? null : _clearCache,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMap(),
    );
  }

  Widget _buildMap() {
    final session = _session!;
    final zoneColor = _zoneColor(session.role);

    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: AppState().heartbeats,
      builder: (context, _, __) {
        final sosMarkers = _buildSosMarkers();

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 15.0,
                maxZoom: 17.0,
                minZoom: 12.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  tileProvider: _tilePath.isNotEmpty
                      ? _OfflineFallbackTileProvider(_tilePath)
                      : NetworkTileProvider(),
                  errorImage: const NetworkImage(
                    'https://tile.openstreetmap.org/13/4093/2723.png',
                  ),
                ),

                // ── Assigned zone polygon ────────────────────────────────────
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: buildGeoCircle(_center, session.radiusM),
                      color: zoneColor.withOpacity(0.10),
                      borderColor: zoneColor.withOpacity(0.8),
                      borderStrokeWidth: 2.5,
                      isFilled: true,
                    ),
                  ],
                ),

                // ── Zone-centre flag ─────────────────────────────────────────
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _center,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: zoneColor.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: zoneColor.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                // ── SOS markers ──────────────────────────────────────────────
                if (sosMarkers.isNotEmpty)
                  MarkerLayer(markers: sosMarkers),
              ],
            ),

            // ── SOS count badge ────────────────────────────────────────────
            if (sosMarkers.isNotEmpty)
              Positioned(
                top: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE65C5C),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE65C5C).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sos_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        '${sosMarkers.length} SOS Alert${sosMarkers.length > 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ── Zone info card at bottom ─────────────────────────────────────
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: _ZoneInfoCard(session: session),
            ),
          ],
        );
      },
    );
  }

  static Color _zoneColor(String role) {
    switch (role.toLowerCase()) {
      case 'medic':
        return const Color(0xFFE74C3C);
      case 'search':
        return const Color(0xFF3498DB);
      case 'logistics':
        return const Color(0xFFF39C12);
      case 'comms':
        return const Color(0xFF9B59B6);
      default:
        return const Color(0xFF6BBFA0);
    }
  }
}

// ─── Pulsing SOS dot widget ─────────────────────────────────────────────────
class _SosDot extends StatefulWidget {
  final Map<String, dynamic> sos;
  const _SosDot({required this.sos});

  @override
  State<_SosDot> createState() => _SosDotState();
}

class _SosDotState extends State<_SosDot> with SingleTickerProviderStateMixin {
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
    final msg = (widget.sos['message'] ?? '').toString();
    final deptMatch = RegExp(r'^\[([A-Z]+)\]').firstMatch(msg);
    final dept = deptMatch?.group(1) ?? 'SOS';
    final color = _HeatmapScreenState._deptColor(dept);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final scale = 1.0 + _pulse.value * 0.5;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse ring
            Container(
              width: 36 * scale,
              height: 36 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15 * (1 - _pulse.value)),
              ),
            ),
            // Inner dot
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Zone Information Card ──────────────────────────────────────────────────
class _ZoneInfoCard extends StatelessWidget {
  final RescuerSession session;
  const _ZoneInfoCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final color = _HeatmapScreenState._zoneColor(session.role);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: BeaconColors.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_roleIcon(session.role), color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Assigned Zone',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: BeaconColors.textDark,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${session.radiusM.toInt()}m radius',
                  style: TextStyle(
                    fontSize: 11,
                    color: BeaconColors.textMid,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              session.role.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter',
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String role) {
    switch (role.toLowerCase()) {
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
}

// ─── Offline-first tile provider with network fallback ──────────────────────
class _OfflineFallbackTileProvider extends TileProvider {
  final String basePath;
  _OfflineFallbackTileProvider(this.basePath);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = File(
      basePath
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString()),
    );

    if (file.existsSync()) {
      return FileImage(file);
    }
    return NetworkImage(
      options.urlTemplate!
          .replaceAll('{z}', coordinates.z.toString())
          .replaceAll('{x}', coordinates.x.toString())
          .replaceAll('{y}', coordinates.y.toString()),
    );
  }
}
