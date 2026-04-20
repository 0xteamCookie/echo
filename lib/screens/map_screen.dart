import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../database/db_hook.dart';
import '../packet/get-location.dart';
import '../map/offline_map_manager.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Marker> _markers = [];
  String _tilePath = '';
  bool _isDownloading = false;
  bool _isLoadingLocation = true; 
  LatLng _center = const LatLng(0, 0);
  final MapController _mapController = MapController(); 

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final dir = await getApplicationDocumentsDirectory();
    _tilePath = '${dir.path}/offline_tiles/{z}/{x}/{y}.png';
    
    // 1. Get exact center from current location
    String locStr = await getCurrentLocationString();
    if (locStr.contains(',')) {
      final parts = locStr.split(',');
      _center = LatLng(double.parse(parts[0]), double.parse(parts[1]));
    }
    
    // 2. Load markers
    await _loadMessages();
    
    // 3. Mark as loaded so UI can build the map at the correct spot
    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    final messages = await getMessages();
    List<Marker> newMarkers = [];

    newMarkers.add(
      Marker(
        point: _center,
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin, color: Colors.blue, size: 40),
      ),
    );

    for (var msg in messages) {
      final loc = msg['location'] as String?;
      if (loc != null && loc.contains(',')) {
        final parts = loc.split(',');
        try {
          final lat = double.parse(parts[0].trim());
          final lng = double.parse(parts[1].trim());
          newMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 30),
            ),
          );
        } catch (e) {
        }
      }
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  Future<void> _downloadMap() async {
    setState(() => _isDownloading = true);
    await OfflineMapManager.downloadMapArea(_center.latitude, _center.longitude);
    setState(() => _isDownloading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offline map downloaded successfully!')),
      );
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
            onPressed: () {
              _mapController.move(_center, 14.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
          ),
          IconButton(
            icon: _isDownloading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadMap,
          ),
        ],
      ),
      body: _isLoadingLocation 
        ? const Center(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Acquiring GPS location..."),
            ],
          )) 
        : FlutterMap(
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
            errorImage: const NetworkImage('https://tile.openstreetmap.org/13/4093/2723.png'), // Fallback clear image
          ),
          MarkerLayer(markers: _markers),
        ],
      ),
    );
  }
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