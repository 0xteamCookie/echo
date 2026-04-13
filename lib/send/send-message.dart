import 'dart:convert';
import 'dart:async';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import '../packet/generate-packet.dart';
import '../mesh/ble-collisions.dart';

Future<void> sendNewMessage(String textMessage) async {
  try {
    print("📨 [sendNewMessage] Generating new message: $textMessage");
    // 1. Get variables
    final packetMap = await generatePacketVariables(textMessage);

    // 2. Save directly to SQLite
    await insertMessage(packetMap);

    // 3. Format Message: messageId||message||deviceId||senderName||expiresAt||location
    String compactPayload = "${packetMap['messageId']}||${packetMap['message']}||${packetMap['deviceId']}||${packetMap['senderName']}||${packetMap['expiresAt']}||${packetMap['location']}";

    List<int> bytes = utf8.encode(compactPayload);

    await relayMessage(
      packetMap['messageId'],
      packetMap['message'],
      packetMap['deviceId'],
      packetMap['senderName'],
      packetMap['expiresAt'],
      packetMap['location'],
    );
  } catch (e) {
    print("Failed to save and broadcast message: $e");
  }
}

Future<void> relayMessage( String messageId, String message, String deviceId, String senderName, String expiresAt, String location
) async {
  try {
    // 1. Format Message: messageId||message||deviceId||senderName||expiresAt||location
    String compactPayload = "$messageId||$message||$deviceId||$senderName||$expiresAt||$location";

    List<int> bytes = utf8.encode(compactPayload);
    print("📡 [relayMessage] Evaluating messageId: $messageId for relay.");
    print("📦 [relayMessage] Encoded Packet byte size: ${bytes.length} bytes.");

    final devices = getCurrentScanResults();
    if (devices.isEmpty) {
      print("⚠️ [relayMessage] No devices currently in range to relay to.");
      return;
    }

    final devicesThatNeedMessage = <String>[];
    for (var device in devices) {
      final String targetDeviceId = device['id'];
      
      if (BleCollisionManager.shouldSkip(targetDeviceId)) {
        print("🛑 [relayMessage] Skipping MAC: $targetDeviceId (In Collision Timeout)");
        continue;
      }

      final alreadySent = await _hasAcknowledged(messageId, targetDeviceId);
      if (!alreadySent) {
        devicesThatNeedMessage.add(targetDeviceId);
        print("🟢 [relayMessage] Queuing MAC: $targetDeviceId (Needs this message)");
      } else {
        print("⏭️ [relayMessage] Skipping MAC: $targetDeviceId (Already Acknowledged)");
      }
    }

    if (devicesThatNeedMessage.isEmpty) {
      print("💤 [relayMessage] All nearby active devices already have this message. Sleeping.");
      return;
    }

    print("🚀 [relayMessage] Emitting payload to ${devicesThatNeedMessage.length} queued device(s)!");

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

Future<bool> _hasAcknowledged(String messageId, String deviceId) async {
  final devices = await getDevicesForMessage(messageId);
  return devices.any((d) => d['deviceId'] == deviceId);
}
