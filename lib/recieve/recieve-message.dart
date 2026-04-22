import 'dart:convert';
import '../database/db_hook.dart';
import '../mesh/packet_codec.dart';

/// Decodes the compact string, saves it to SQLite, and returns the mapped data.
Future<Map<String, dynamic>?> decodeAndSaveMessage(
  String rawMessage,
  String senderDeviceId,
) async {
  try {
    // ACKs are control frames, not data packets.
    if (rawMessage.startsWith('ACK||')) {
      final parts = rawMessage.split('||');
      if (parts.length >= 3) {
        final ackMessageId = parts[1];
        final relayerId = parts[2];
        await insertMessageDevice(messageId: ackMessageId, deviceId: relayerId);
        print("✅ Acknowledgment saved for Msg: $ackMessageId from $relayerId");
      }
      return null;
    }

    final packetMap = decodePacket(rawMessage);
    if (packetMap == null) {
      print("❓ [decodeAndSaveMessage] Unparseable frame: $rawMessage");
      return null;
    }

    // P1-2: drop immediately if the TTL is already exhausted before we even
    // persist the packet. Otherwise we'd keep relaying a dead message.
    final hopCount = (packetMap['hopCount'] is int)
        ? packetMap['hopCount'] as int
        : int.tryParse((packetMap['hopCount'] ?? '0').toString()) ?? 0;
    if (hopCount >= maxHops) {
      print(
        "⏹️ [decodeAndSaveMessage] Dropping ${packetMap['messageId']} — TTL exhausted.",
      );
      return null;
    }

    final messageId = (packetMap['messageId'] ?? '').toString();
    final exists = await messageExists(messageId);

    if (!exists) {
      await insertMessage(packetMap);
      packetMap['isNew'] = true;
      print(
        "🎉 [decodeAndSaveMessage] Vetted and Saved NEW Incoming Message: $messageId",
      );
    } else {
      packetMap['isNew'] = false;
      print(
        "🧱 [decodeAndSaveMessage] Deduplicating Message: $messageId (Already exists in DB. Ghosting.)",
      );
    }

    // Silence "unused parameter" lint — senderDeviceId is used by the caller to
    // record which peer relayed this frame (insertMessageDevice), not here.
    assert(utf8.encode(senderDeviceId).isNotEmpty || senderDeviceId.isEmpty);

    return packetMap;
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}

