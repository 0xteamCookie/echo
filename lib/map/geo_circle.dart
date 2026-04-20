import 'dart:math';
import 'package:latlong2/latlong.dart';

/// Builds a list of [LatLng] points forming a circle polygon on the globe.
///
/// Uses the haversine "destination point given bearing" formula so the circle
/// is geographically accurate regardless of latitude.
///
/// [center]  – centre of the circle.
/// [radiusM] – radius in **metres**.
/// [points]  – number of polygon vertices (higher = smoother, 72 is fine).
List<LatLng> buildGeoCircle(LatLng center, double radiusM, {int points = 72}) {
  const double earthRadius = 6371000; // metres
  final double lat1 = center.latitude * pi / 180;
  final double lng1 = center.longitude * pi / 180;
  final double angularDist = radiusM / earthRadius;

  final List<LatLng> circle = [];

  for (int i = 0; i <= points; i++) {
    final double bearing = 2 * pi * i / points;

    final double lat2 =
        asin(sin(lat1) * cos(angularDist) + cos(lat1) * sin(angularDist) * cos(bearing));
    final double lng2 = lng1 +
        atan2(
          sin(bearing) * sin(angularDist) * cos(lat1),
          cos(angularDist) - sin(lat1) * sin(lat2),
        );

    circle.add(LatLng(lat2 * 180 / pi, lng2 * 180 / pi));
  }

  return circle;
}
