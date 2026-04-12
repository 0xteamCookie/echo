import 'dart:convert';
import 'dart:async';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import '../packet/generate-packet.dart';

Future<void> sendNewMessage(String textMessage) async {
  try {
    // 1. Get variables
    final packetMap = await generatePacketVariables(textMessage);

    // 2. Save directly to SQLite
    await insertMessage(packetMap);

    // 3. Format Message: deviceId||messageId||location||expiresAt||message
    String compactPayload =
        "${packetMap['deviceId']}||${packetMap['messageId']}||${packetMap['location']}||${packetMap['expiresAt']}||${packetMap['message']}";

    List<int> bytes = utf8.encode(compactPayload);

    await relayMessage(packetMap['messageId'], packetMap['message'], packetMap['deviceId'], packetMap['expiresAt'], packetMap['location']);

  } catch (e) {
    print("Failed to save and broadcast message: $e");
  }
}

Future<void> relayMessage(String messageId, String message, String deviceId, String expiresAt, String location) async {
  try {
    // 1. Format Message: deviceId||messageId||location||expiresAt||message
    String compactPayload = "$deviceId||$messageId||$location||$expiresAt||$message";

    List<int> bytes = utf8.encode(compactPayload);
    print("Byte size of relayed packet: ${bytes.length} bytes");

    final devices = getCurrentScanResults();
    if (devices.isEmpty) return;

    final devicesThatNeedMessage = <String>[];
    for (var device in devices) {
      final String targetDeviceId = device['id'];
      final alreadySent = await _hasAcknowledged(messageId, targetDeviceId);
      if (!alreadySent) {
        devicesThatNeedMessage.add(targetDeviceId);
      }
    }

    if (devicesThatNeedMessage.isEmpty) return;

    await stopScanning(); 

    for (final targetDeviceId in devicesThatNeedMessage) {
      final success = await dispatchPayloadToDevice(targetDeviceId, bytes);
      if (success) {
        await insertMessageDevice(messageId: messageId, deviceId: targetDeviceId);
      }
    }
    
    await restartScan(); 
  } catch (e) {
    print("Failed to save and broadcast message: $e");
    await restartScan(); 
  }
}

Future<bool> _hasAcknowledged(
  String messageId,
  String deviceId,
) async {
  final devices = await getDevicesForMessage(messageId);
  return devices.any((d) => d['deviceId'] == deviceId);
}
