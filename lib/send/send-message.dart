import 'dart:convert';
import 'dart:async';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import '../packet/generate-packet.dart';

/// Generates variables, saves to DB, transmits over BLE, and returns a Hex String
Future<void> sendNewMessage(String textMessage) async {
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

    // 5. Connect to all discovered mesh nodes
    await blastToEntireMesh(bytes);

  } catch (e) {
    print("Failed to save and broadcast message: $e");
  }
}

Future<void> relayMessage(String messageId, String message, String deviceId, String expiresAt, String location) async {
  try {
    // 1. Format Message: deviceId||messageId||location||expiresAt||message
    String compactPayload =
        "$deviceId||$messageId||$location||$expiresAt||$message";

    // 2. Convert to Bytes
    List<int> bytes = utf8.encode(compactPayload);

    // 3. Scan the mesh and send message
    final devices = getCurrentScanResults();

    for (var device in devices) {
      final String targetDeviceId = device['id'];

      final alreadySent = await _hasAcknowledged(messageId, targetDeviceId);

      if (alreadySent) continue;

      await dispatchPayloadToDevice(targetDeviceId, bytes);
    }
  } catch (e) {
    print("Failed to save and broadcast message: $e");
  }
}

Future<bool> _hasAcknowledged(
  String messageId,
  String deviceId,
) async {
  final devices = await getDevicesForMessage(messageId);
  return devices.any((d) => d['deviceId'] == deviceId);
}
