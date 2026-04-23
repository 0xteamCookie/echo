import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_hook.dart';

/// Backend ingest base URL — injected at build time via
/// `--dart-define-from-file=dart-defines.json` (see .vscode/launch.json).
/// The default points to the live backend so `flutter run` without flags
/// also works during development.
const String _apiBaseUrl = String.fromEnvironment(
  'BEACON_API_BASE_URL',
  defaultValue: 'https://echo-back.getmyroom.in',
);

/// Shared-secret token for the ingest endpoint. Replaced by Firebase App Check
/// + Firebase Auth ID token in P2-3 / P2-4.
const String _ingestToken = String.fromEnvironment(
  'BEACON_INGEST_TOKEN',
  defaultValue: '',
);

Future<bool> hasInternet() async {
  var result = await Connectivity().checkConnectivity();
  return !result.contains(ConnectivityResult.none);
}

Map<String, dynamic> parseLocation(dynamic location) {
  if (location is String) {
    try {
      final parts = location.split(',');
      if (parts.length == 2) {
        return {
          "lat": double.tryParse(parts[0].trim()),
          "lon": double.tryParse(parts[1].trim())
        };
      }
    } catch (_) {}
  }
  return {};
}

Map<String, dynamic> mapToApiPayload(Map<String, dynamic> msg) {
  String? timeStr = msg["time"];
  if (timeStr == null && msg["expiresAt"] != null) {
    try {
      final exp = DateTime.parse(msg["expiresAt"]);
      timeStr = exp.subtract(const Duration(days: 1)).toIso8601String();
    } catch (_) {}
  }
  timeStr ??= DateTime.now().toIso8601String();

  return {
    "macAddress": msg["deviceId"],
    "messageId": msg["messageId"],
    "message": msg["message"],
    "time": timeStr,
    "gps": msg["location"] != null
        ? parseLocation(msg["location"])
        : null,
    "meta": {
      "senderName": msg["senderName"],
      "isSos": msg["isSos"],
      "hopCount": msg["hopCount"] ?? 0,
      "messageId": msg["messageId"],
    }
  };
}

Uri _ingestUri() => Uri.parse('$_apiBaseUrl/api/data');

Map<String, String> _ingestHeaders() {
  final headers = <String, String>{
    'Content-Type': 'application/json',
  };
  if (_ingestToken.isNotEmpty) {
    headers['Authorization'] = 'Bearer $_ingestToken';
  }
  return headers;
}

Future<void> sendBatch(List<Map<String, dynamic>> messages) async {
  for (var msg in messages) {
    try {
      final url = "http://178.104.27.227:6767/api/data";
      print("Sending POST request to: $url");
      print("Payload: ${jsonEncode(mapToApiPayload(msg))}");
      final response = await http.post(
        _ingestUri(),
        headers: _ingestHeaders(),
        body: jsonEncode(mapToApiPayload(msg)),
      ).timeout(const Duration(seconds: 10));

      print("Response status code: ${response.statusCode}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        await markAsSynced(msg["messageId"]);
        print("✅ Message successfully marked as synced in local DB!");
      } else {
        print('Sync failed: ${response.statusCode} ${response.body}');
        // Bail out of the batch on 4xx/5xx so we don't tight-loop.
        break;
      }
    } catch (e) {
      print("❌ Network/Timeout error: $e");
      break;
    }
  }
}

Future<void> syncMessages() async {
  print("🔄 [Sync] syncMessages() called.");
  if (!await hasInternet()) {
    print("🔄 [Sync] No internet, skipping sync.");
    return;
  }

  print("🔄 [Sync] Internet detected, checking for unsynced messages...");

  while (true) {
    final batch = await getUnsyncedMessages();

    if (batch.isEmpty) {
      print("🔄 [Sync] All messages synced ✅");
      break;
    }

    print("🔄 [Sync] Found ${batch.length} unsynced messages, sending via POST...");
    await sendBatch(batch);

    await Future.delayed(Duration(seconds: 2)); 
  }
}