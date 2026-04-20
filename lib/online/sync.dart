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
  return {
    "macAddress": msg["deviceId"],
    "message": msg["message"],
    "time": msg["time"],
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
      final response = await http.post(
        Uri.parse("https://your-api.com/api/data"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(mapToApiPayload(msg)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await markAsSynced(msg["messageId"]);
      } else {
        print("Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Network error: $e");
      break;
    }
  }
}

Future<void> syncMessages() async {
  if (!await hasInternet()) {
    print("No internet, skipping sync");
    return;
  }

  print("Internet detected, syncing...");

  while (true) {
    final batch = await getUnsyncedMessages();

    if (batch.isEmpty) {
      print("All messages synced ✅");
      break;
    }

    await sendBatch(batch);

    await Future.delayed(Duration(seconds: 2)); // prevent spamming server
  }
}