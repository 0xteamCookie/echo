import 'dart:convert';
import '../central/intialize.dart';
import '../database/db_hook.dart';

/// Evaluates whether a message should be relayed to specific nearby devices.
/// Returns a list of device IDs that need this message.
Future<List<String>> evaluateRelayDecision({
  required String messageId,
  required List<Map<String, dynamic>> nearbyDevices,
  required Function(String deviceId) shouldSkipDevice,
  required Function(String messageId, String deviceId) hasAcknowledged,
}) async {
  final devicesThatNeedMessage = <String>[];

  for (var device in nearbyDevices) {
    final String targetDeviceId = device['id'];

    // Check collision timeout
    if (shouldSkipDevice(targetDeviceId)) {
      print("🛑 [evaluateRelayDecision] Skipping MAC: $targetDeviceId (In Collision Timeout)");
      continue;
    }

    // Check if device already has this message
    final alreadySent = await hasAcknowledged(messageId, targetDeviceId);
    if (!alreadySent) {
      devicesThatNeedMessage.add(targetDeviceId);
      print("🟢 [evaluateRelayDecision] Queuing MAC: $targetDeviceId (Needs this message)");
    } else {
      print("⏭️ [evaluateRelayDecision] Skipping MAC: $targetDeviceId (Already Acknowledged)");
    }
  }

  return devicesThatNeedMessage;
}
/// This function handles the actual transmission and does NOT evaluate which devices need the message.
Future<void> relayMessage(
  String messageId,
  String message,
  String deviceId,
  String senderName,
  String expiresAt,
  String location,
  List<String> targetDeviceIds,
) async {
  try {
    // messageId||message||deviceId||senderName||expiresAt||location
    String compactPayload = "$messageId||$message||$deviceId||$senderName||$expiresAt||$location";

    List<int> bytes = utf8.encode(compactPayload);
    print("📡 [relayMessage] Transmitting messageId: $messageId for relay.");
    print("📦 [relayMessage] Encoded Packet byte size: ${bytes.length} bytes.");

    if (targetDeviceIds.isEmpty) {
      print("⚠️ [relayMessage] No target devices provided for relay.");
      return;
    }

    print("🚀 [relayMessage] Emitting payload to ${targetDeviceIds.length} device(s)!");

    await stopScanning();

    for (final targetDeviceId in targetDeviceIds) {
      final success = await dispatchPayloadToDevice(targetDeviceId, bytes);
      if (success) {
        await insertMessageDevice(messageId: messageId, deviceId: targetDeviceId);
      }
    }

    await restartScan();
  } catch (e) {
    print("Failed to broadcast message: $e");
    await restartScan();
  }
}
