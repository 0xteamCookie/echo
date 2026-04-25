import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_hook.dart';
import '../map/geo_circle.dart';
import '../map/offline_map_manager.dart';
import '../packet/get_location.dart';
import '../main.dart';
import '../models/rescuer_session.dart';
import '../core/constants.dart';

/// Shows the rescuer's assigned zone on a map with a highlighted region circle.
/// Centred on the JWT-assigned lat/lng with radius_m as the zone boundary.
///
/// Uses `flutter_map` + OpenStreetMap (Leaflet-style) tiles for both online
/// and offline. Online, the provider falls through to OSM's tile server;
/// offline, only downloaded tiles render.
class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  String _tilePath = '';
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isRefreshing = false;

  /// flutter_map controller.
  final MapController _mapController = MapController();

  /// Whether connectivity_plus reports an active network. Used only to toggle
  /// the "offline" banner; the tile provider handles both modes transparently.
  bool _isOnline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Aggregated SOS density cells (~50m each).
  List<_SosCluster> _clusters = [];

  /// Refresh the heatmap every 30s so new SOS hits show up without manual reload.
  Timer? _refreshTimer;

  /// ~50 m cell size in degrees latitude (1° lat ≈ 111 km).
  static const double _cellDegLat = kHeatmapCellDegLat;

  Timer? _locationTimer;
  LatLng? _myLoc;

  RescuerSession? get _session => AppState().rescuerSession.value;

  LatLng get _center => _session != null
      ? LatLng(_session!.lat, _session!.lng)
      : const LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _refreshTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _initMap() async {
    final dir = await getApplicationDocumentsDirectory();
    _tilePath = '${dir.path}/offline_tiles/{z}/{x}/{y}.png';

    await _updateConnectivity();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
      }
    });

    await _refreshHeatmap();

    if (mounted) {
      setState(() => _isLoading = false);
    }

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      kHeatmapRefreshInterval,
      (_) => _refreshHeatmap(),
    );

    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateMyLoc(),
    );
    _updateMyLoc();
  }

  Future<void> _updateMyLoc() async {
    try {
      final locStr = await getCurrentLocationString();
      if (locStr.contains(',')) {
        final parts = locStr.split(',');
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        if (mounted) {
          setState(() {
            _myLoc = LatLng(lat, lng);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _updateConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _isOnline = online);
      } else {
        _isOnline = online;
      }
    } catch (_) {
      _isOnline = false;
    }
  }

  /// Pull the last 24h of SOS rows from SQLite, drop anything outside the
  /// assigned zone, and bucket into ~50m cells for a rough density map.
  Future<void> _refreshHeatmap() async {
    final session = _session;
    if (session == null) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final rows = await getRecentSosMessages(withinHours: 24);
      final zoneCenter = LatLng(session.lat, session.lng);
      final radiusM = session.radiusM;

      final Map<String, List<double>> buckets = {};

      for (final row in rows) {
        final loc = _parseLatLng(row['location']?.toString());
        if (loc == null) continue;

        final distM = _haversineMeters(zoneCenter, loc);
        if (distM > radiusM) continue;

        final cosLat = math.cos(loc.latitude * math.pi / 180.0).abs();
        final cellDegLng = cosLat < 1e-6 ? _cellDegLat : _cellDegLat / cosLat;

        final latIdx = (loc.latitude / _cellDegLat).floor();
        final lngIdx = (loc.longitude / cellDegLng).floor();
        final key = '$latIdx:$lngIdx';

        final bucket = buckets[key] ?? [0.0, 0.0, 0.0];
        bucket[0] += loc.latitude;
        bucket[1] += loc.longitude;
        bucket[2] += 1;
        buckets[key] = bucket;
      }

      final clusters = buckets.values.map((b) {
        final count = b[2].toInt();
        return _SosCluster(
          center: LatLng(b[0] / b[2], b[1] / b[2]),
          count: count,
        );
      }).toList();

      if (mounted) {
        setState(() => _clusters = clusters);
      }
    } catch (e) {
      debugPrint('Heatmap refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }

  static LatLng? _parseLatLng(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  /// Haversine distance in metres.
  static double _haversineMeters(LatLng a, LatLng b) {
    const r = kEarthRadiusMetres;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLng = (b.longitude - a.longitude) * math.pi / 180.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLng / 2) *
            math.sin(dLng / 2) *
            math.cos(lat1) *
            math.cos(lat2);
    return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
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
            const SnackBar(
                content: Text('7km low-res map downloaded around you!')),
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
      if (!locStr.contains(',')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to get current location.')),
          );
        }
        return;
      }
      final parts = locStr.split(',');
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
      _moveMapTo(LatLng(lat, lng), 15.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _moveMapTo(LatLng target, double zoom) {
    _mapController.move(target, zoom);
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
            onPressed: () => _moveMapTo(_center, 15.0),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Centre on me',
            onPressed: _centerOnUser,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh heatmap',
            onPressed: () async {
              await _updateConnectivity();
              await _refreshHeatmap();
            },
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

  // ── flutter_map + OSM tiles (used for both online and offline) ──────────
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
              // P3-14: no `errorImage` — flutter_map falls back to an empty
              // tile on failure instead of repeatedly GETing a hard-coded URL.
            ),
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
            if (_clusters.isNotEmpty)
              CircleLayer(
                circles: _clusters.map((c) {
                  final radiusM =
                      25.0 + 12.0 * math.sqrt(c.count.toDouble());
                  final opacity = math.min(0.75, 0.25 + 0.1 * c.count);
                  return CircleMarker(
                    point: c.center,
                    radius: radiusM,
                    useRadiusInMeter: true,
                    color: const Color(0xFFE74C3C).withOpacity(opacity),
                    borderColor: const Color(0xFFE74C3C).withOpacity(0.9),
                    borderStrokeWidth: 1.0,
                  );
                }).toList(),
              ),
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
                if (_myLoc != null)
                  Marker(
                    point: _myLoc!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 255, 12, 12),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (!_isOnline)
          const Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: _OfflineBanner(),
          ),
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

// ─── SOS density cluster (P1-4) ─────────────────────────────────────────────
class _SosCluster {
  final LatLng center;
  final int count;
  const _SosCluster({required this.center, required this.count});
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Offline — using cached tiles',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

