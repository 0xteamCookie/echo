import 'dart:convert';
import '../crypto/ed25519.dart';
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
      final ack = decodeAck(rawMessage);
      if (ack != null) {
        final ackMessageId = ack['messageId']!;
        final relayerId = ack['relayerId']!;
        final status = ack['status'] ?? 'ack';
        await insertMessageDevice(messageId: ackMessageId, deviceId: relayerId);
        // Status flows from the rescuer report screen: ack / enroute / resolved.
        // Only persist explicit statuses; plain "ack" doesn't overwrite a
        // stronger status already recorded locally by the receiving rescuer.
        if (status != 'ack') {
          await updateAckStatus(ackMessageId, status);
        }
        print(
          "✅ Acknowledgment saved for Msg: $ackMessageId from $relayerId (status=$status)",
        );
      }
      return null;
    }

    final packetMap = decodePacket(rawMessage);
    if (packetMap == null) {
      print("❓ [decodeAndSaveMessage] Unparseable frame: $rawMessage");
      return null;
    }

    // P2-11: verify signatures on v3 packets. v1/v2 are accepted during
    // soft-migration but flagged `insecure=true` so the UI / sync layer can
    // surface that downstream. A v3 packet with a bad signature is DROPPED.
    final protocolVersion = packetMap['protocolVersion'] as int? ?? 1;
    if (protocolVersion >= 3) {
      final pubKey = (packetMap['deviceSenderPublicKey'] ?? '').toString();
      final sig = (packetMap['signature'] ?? '').toString();
      if (pubKey.isEmpty || sig.isEmpty) {
        print(
          "🔒 [decodeAndSaveMessage] Dropping v3 packet ${packetMap['messageId']} — missing key/signature.",
        );
        return null;
      }
      final canonical = canonicalSignedString(packetMap);
      final ok = await verifyPacket(canonical, pubKey, sig);
      if (!ok) {
        print(
          "🔒 [decodeAndSaveMessage] Dropping v3 packet ${packetMap['messageId']} — bad signature.",
        );
        return null;
      }
      packetMap['insecure'] = false;
    } else {
      // Legacy/unsigned packet — accept for now so we don't break the mesh
      // while older peers upgrade, but mark it so downstream code can treat
      // it as lower trust.
      packetMap['insecure'] = true;
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

