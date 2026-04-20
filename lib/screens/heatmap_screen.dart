import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../map/geo_circle.dart';
import '../map/offline_map_manager.dart';
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

  Future<void> _downloadMap() async {
    setState(() => _isDownloading = true);
    await OfflineMapManager.downloadMapArea(_center.latitude, _center.longitude);
    setState(() => _isDownloading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zone map downloaded for offline use!')),
      );
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
            icon: const Icon(Icons.my_location),
            tooltip: 'Centre on zone',
            onPressed: () => _mapController.move(_center, 15.0),
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            tooltip: 'Download zone tiles',
            onPressed: _isDownloading ? null : _downloadMap,
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
          ],
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
