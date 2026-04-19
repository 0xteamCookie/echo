//this will handle downloading maps in device storage

import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OfflineMapManager {
  static Future<void> downloadMapArea(
    double centerLat,
    double centerLon,
  ) async {
    final dir = await getApplicationDocumentsDirectory();
    final basePath = '${dir.path}/offline_tiles';

    const urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

    double minLat = centerLat - 0.01;
    double maxLat = centerLat + 0.01;
    double minLon = centerLon - 0.01;
    double maxLon = centerLon + 0.01;

    for (int z = 13; z <= 17; z++) {
      int minX = _lon2tilex(minLon, z);
      int maxX = _lon2tilex(maxLon, z);
      int minY = _lat2tiley(maxLat, z);
      int maxY = _lat2tiley(minLat, z);

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          final file = File('$basePath/$z/$x/$y.png');
          if (!await file.exists()) {
            await file.create(recursive: true);
            final url = urlTemplate
                .replaceAll('{z}', z.toString())
                .replaceAll('{x}', x.toString())
                .replaceAll('{y}', y.toString());
            try {
              final response = await http.get(Uri.parse(url));
              await file.writeAsBytes(response.bodyBytes);
            } catch (e) {
              print("Failed to download tile: $z/$x/$y");
            }
          }
        }
      }
    }
  }

  static int _lon2tilex(double lon, int z) =>
      ((lon + 180.0) / 360.0 * pow(2.0, z)).floor();

  static int _lat2tiley(double lat, int z) =>
      ((1.0 - asinh(tan(lat * pi / 180.0)) / pi) / 2.0 * pow(2.0, z)).floor();

  static double asinh(double x) => log(x + sqrt(x * x + 1.0));
}
