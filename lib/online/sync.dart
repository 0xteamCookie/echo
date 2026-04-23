import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../database/db_hook.dart';

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
    "message": msg["message"],
    "time": timeStr,
    "gps": msg["location"] != null
        ? parseLocation(msg["location"])
        : null,
    "meta": {
      "senderName": msg["senderName"],
      "isSos": msg["isSos"],
    }
  };
}
  
// Needs relevant BASE_API_KEY
Future<void> sendBatch(List<Map<String, dynamic>> messages) async {
  for (var msg in messages) {
    try {
      final url = "$BASE_API_KEY/api/data";
      print("Sending POST request to: $url");
      print("Payload: ${jsonEncode(mapToApiPayload(msg))}");
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(mapToApiPayload(msg)),
      ).timeout(const Duration(seconds: 10));

      print("Response status code: ${response.statusCode}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        await markAsSynced(msg["messageId"]);
        print("✅ Message successfully marked as synced in local DB!");
      } else {
        print("❌ Failed: ${response.statusCode} - ${response.body}");
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