import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import '../packet/generate-packet.dart';

Timer? heartbeatTimer;

/// Generates variables, saves to DB, transmits over BLE, and returns a Hex String
Future<String> broadcastMessage(String textMessage) async {
  try {
    // 1. Get variables
    final packetMap = await generatePacketVariables(textMessage);

    // 2. Save directly to SQLite
    await insertMessage(packetMap);

    // 3. Compact encode to save BLE space (Format: deviceId||messageId||location||expiresAt||message)
    String compactPayload =
        "${packetMap['deviceId']}||${packetMap['messageId']}||${packetMap['location']}||${packetMap['expiresAt']}||${packetMap['message']}";

    // 4. Convert to Bytes
    List<int> bytes = utf8.encode(compactPayload);
    Uint8List byteData = Uint8List.fromList(bytes);

    // 5. Connect and Write payload to all discovered mesh nodes (The Mailman approach)
    await blastToEntireMesh(bytes);

    // 6. Return Hex representation so the UI can display it
    return byteData
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join('')
        .toUpperCase();
  } catch (e) {
    print("Failed to save and broadcast message: $e");
    return "";
  }
}

void startHeartbeat([String customPrefix = "Heartbeat"]) {
  heartbeatTimer?.cancel();

  if (customPrefix.trim().isEmpty) {
    customPrefix = "Heartbeat";
  }

  heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    String timeStr = DateTime.now().toIso8601String().substring(11, 19);
    broadcastMessage("$customPrefix: $timeStr");
  });
  print("Heartbeat started with prefix: $customPrefix.");
}

void stopHeartbeat() {
  heartbeatTimer?.cancel();
  print("Heartbeat stopped.");
}
