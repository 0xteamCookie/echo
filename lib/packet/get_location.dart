import 'package:geolocator/geolocator.dart';

/// (Lat, Long)
Future<String> getCurrentLocationString() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return 'Location services disabled';
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return 'Permission denied';
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return 'Permission permanently denied';
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    
    return '${position.latitude}, ${position.longitude}';
  } catch (e) {
    return 'Failed to get location: $e';
  }
}