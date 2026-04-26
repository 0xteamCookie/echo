import 'dart:convert';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import 'packet_codec.dart';

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
      print(
        "🛑 [evaluateRelayDecision] Skipping MAC: $targetDeviceId (In Collision Timeout)",
      );
      continue;
    }

    // Check if device already has this message
    final alreadySent = await hasAcknowledged(messageId, targetDeviceId);
    if (!alreadySent) {
      devicesThatNeedMessage.add(targetDeviceId);
      print(
        "🟢 [evaluateRelayDecision] Queuing MAC: $targetDeviceId (Needs this message)",
      );
    } else {
      print(
        "⏭️ [evaluateRelayDecision] Skipping MAC: $targetDeviceId (Already Acknowledged)",
      );
    }
  }

  return devicesThatNeedMessage;
}

/// Relays a stored message to the given target devices. Increments `hopCount`
/// and refuses to transmit if the TTL has been exhausted (P1-2). The outgoing
/// frame is always encoded as v2 (base64 text fields, P1-1).
Future<void> relayMessage(
  Map<String, dynamic> packet,
  List<String> targetDeviceIds,
) async {
  try {
    final messageId = (packet['messageId'] ?? '').toString();
    final currentHops = (packet['hopCount'] is int)
        ? packet['hopCount'] as int
        : int.tryParse((packet['hopCount'] ?? '0').toString()) ?? 0;

    if (currentHops >= maxHops) {
      print(
        '⏹️ [relayMessage] Dropping $messageId — TTL exhausted ($currentHops/$maxHops hops).',
      );
      return;
    }

    // Transmit with an incremented hop count so receivers see the new value.
    final outgoing = Map<String, dynamic>.from(packet);
    outgoing['hopCount'] = currentHops + 1;

    // P2-11: prefer v3 if the packet carried a signature + public key
    // (relays MUST NOT resign — that would break authenticity). Fall back to
    // v2 for legacy packets that pre-date signing so they keep propagating.
    final signature = (outgoing['signature'] ?? '').toString();
    final pubKey = (outgoing['deviceSenderPublicKey'] ?? '').toString();
    final String compactPayload;
    if (signature.isNotEmpty && pubKey.isNotEmpty) {
      compactPayload = encodePacketV3(outgoing, signature);
    } else {
      compactPayload = encodePacketV2(outgoing);
    }
    final bytes = utf8.encode(compactPayload);
    print(
      "📡 [relayMessage] Transmitting messageId: $messageId (hop ${currentHops + 1}/$maxHops).",
    );
    print("📦 [relayMessage] Encoded Packet byte size: ${bytes.length} bytes.");

    if (targetDeviceIds.isEmpty) {
      print("⚠️ [relayMessage] No target devices provided for relay.");
      return;
    }

    print(
      "🚀 [relayMessage] Emitting payload to ${targetDeviceIds.length} device(s)!",
    );

    await stopScanning();

    for (final targetDeviceId in targetDeviceIds) {
      final success = await dispatchPayloadToDevice(targetDeviceId, bytes);
      if (success) {
        await insertMessageDevice(
          messageId: messageId,
          deviceId: targetDeviceId,
        );
      }
    }

    await restartScan();
  } catch (e) {
    print("Failed to broadcast message: $e");
    await restartScan();
  }
}
