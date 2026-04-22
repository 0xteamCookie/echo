import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_hook.dart';
import '../packet/get-location.dart';
import '../map/offline_map_manager.dart';

/// Mesh map screen. Shows the user's location plus every message pin received
/// via BLE mesh.
///
/// P2-2: online = `google_maps_flutter` with native Google tiles; offline =
/// original `flutter_map` + cached OSM tiles so the screen still works when
/// there is no connectivity.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<_MessagePin> _pins = [];
  String _tilePath = '';
  bool _isDownloading = false;
  bool _isLoadingLocation = true;
  bool _isOnline = false;
  LatLng _center = const LatLng(0, 0);

  final MapController _mapController = MapController();
  gmaps.GoogleMapController? _googleController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _googleController?.dispose();
    super.dispose();
  }

  Future<void> _initMap() async {
    final dir = await getApplicationDocumentsDirectory();
    _tilePath = '${dir.path}/offline_tiles/{z}/{x}/{y}.png';

    String locStr = await getCurrentLocationString();
    if (locStr.contains(',')) {
      final parts = locStr.split(',');
      _center = LatLng(double.parse(parts[0]), double.parse(parts[1]));
    }

    await _updateConnectivity();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted && online != _isOnline) {
        setState(() => _isOnline = online);
      }
    });

    await _loadMessages();

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
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

  Future<void> _loadMessages() async {
    final messages = await getMessages();
    final List<_MessagePin> pins = [];

    for (var msg in messages) {
      final loc = msg['location'] as String?;
      if (loc != null && loc.contains(',')) {
        final parts = loc.split(',');
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          pins.add(_MessagePin(LatLng(lat, lng)));
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _pins
          ..clear()
          ..addAll(pins);
      });
    }
  }

  Future<void> _downloadMap() async {
    setState(() => _isDownloading = true);
    await OfflineMapManager.downloadMapArea(
        _center.latitude, _center.longitude);
    setState(() => _isDownloading = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map downloaded successfully!')),
      );
    }
  }

  void _recenter() {
    if (_isOnline && _googleController != null) {
      _googleController!.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(_center.latitude, _center.longitude),
          14.0,
        ),
      );
    } else {
      _mapController.move(_center, 14.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mesh Map"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _recenter,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _updateConnectivity();
              await _loadMessages();
            },
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadMap,
          ),
        ],
      ),
      body: _isLoadingLocation
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Acquiring GPS location..."),
                ],
              ),
            )
          : (_isOnline ? _buildOnlineMap() : _buildOfflineMap()),
    );
  }

  // ── Online: Google Maps ─────────────────────────────────────────────────
  Widget _buildOnlineMap() {
    final markers = <gmaps.Marker>{
      gmaps.Marker(
        markerId: const gmaps.MarkerId('self'),
        position: gmaps.LatLng(_center.latitude, _center.longitude),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueAzure),
        infoWindow: const gmaps.InfoWindow(title: 'You'),
      ),
      for (int i = 0; i < _pins.length; i++)
        gmaps.Marker(
          markerId: gmaps.MarkerId('pin-$i'),
          position:
              gmaps.LatLng(_pins[i].point.latitude, _pins[i].point.longitude),
          icon: gmaps.BitmapDescriptor.defaultMarker,
        ),
    };

    return gmaps.GoogleMap(
      initialCameraPosition: gmaps.CameraPosition(
        target: gmaps.LatLng(_center.latitude, _center.longitude),
        zoom: 14.0,
      ),
      minMaxZoomPreference: const gmaps.MinMaxZoomPreference(13, 18),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      markers: markers,
      onMapCreated: (c) => _googleController = c,
    );
  }

  // ── Offline: flutter_map ────────────────────────────────────────────────
  Widget _buildOfflineMap() {
    final markers = <Marker>[
      Marker(
        point: _center,
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin, color: Colors.blue, size: 40),
      ),
      for (final pin in _pins)
        Marker(
          point: pin.point,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 30),
        ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 14.0,
        maxZoom: 17.0,
        minZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          tileProvider: FileTileProvider(_tilePath),
          errorImage: const NetworkImage(
              'https://tile.openstreetmap.org/13/4093/2723.png'),
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }
}

class _MessagePin {
  final LatLng point;
  const _MessagePin(this.point);
}

class FileTileProvider extends TileProvider {
  final String basePath;
  FileTileProvider(this.basePath);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final file = File(basePath
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString()));

    if (file.existsSync()) {
      return FileImage(file);
    }
    return NetworkImage(options.urlTemplate!
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString()));
  }
}
