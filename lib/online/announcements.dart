import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../packet/get_location.dart';

const String _apiBaseUrl = String.fromEnvironment(
  'BEACON_API_BASE_URL',
  defaultValue: 'https://echo-back.getmyroom.in',
);

/// One announcement item as returned by `GET /api/announcement`.
class Announcement {
  final String id;
  final String? title;
  final String message;
  final String locationName;
  final String? agency;
  final DateTime createdAt;
  final String? createdBy;

  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    required this.locationName,
    required this.agency,
    required this.createdAt,
    required this.createdBy,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(dynamic v) {
      if (v is String) {
        return DateTime.tryParse(v)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }
    return Announcement(
      id: (j['id'] ?? '').toString(),
      title: j['title'] as String?,
      message: (j['message'] ?? '').toString(),
      locationName: (j['locationName'] ?? '').toString(),
      agency: j['agency'] as String?,
      createdAt: parseDate(j['createdAt']),
      createdBy: j['createdBy'] as String?,
    );
  }
}

/// Fetch announcements from the backend. When `lat`/`lng` are available we
/// query the nearby endpoint; otherwise the backend returns the latest global
/// feed.
Future<List<Announcement>> fetchAnnouncements({int limit = 20}) async {
  try {
    double? lat;
    double? lng;
    try {
      final raw = await getCurrentLocationString();
      if (raw.contains(',')) {
        final parts = raw.split(',');
        lat = double.tryParse(parts[0].trim());
        lng = double.tryParse(parts[1].trim());
      }
    } catch (_) {
      /* public endpoint — proceed without gps */
    }

    final qp = <String, String>{'limit': limit.toString()};
    if (lat != null && lng != null) {
      qp['lat'] = lat.toString();
      qp['long'] = lng.toString();
    }

    final uri = Uri.parse('$_apiBaseUrl/api/announcement')
        .replace(queryParameters: qp);

    final res = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      debugPrint('announcements non-200: ${res.statusCode}');
      return const [];
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    final arr = decoded['announcements'];
    if (arr is! List) return const [];
    return arr
        .whereType<Map<String, dynamic>>()
        .map(Announcement.fromJson)
        .toList();
  } catch (e) {
    debugPrint('announcements fetch failed: $e');
    return const [];
  }
}
