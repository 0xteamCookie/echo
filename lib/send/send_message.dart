import 'dart:convert';
import '../ai/on_device_triage.dart';
import '../central/intialize.dart';
import '../crypto/ed25519.dart';
import '../database/db_hook.dart';
import '../mesh/packet_codec.dart';
import '../packet/generate_packet.dart';

Future<void> sendNewMessage(String textMessage, {bool isSos = false}) async {
  try {
    print("📨 [sendNewMessage] Generating new message: $textMessage");
    final packetMap = await generatePacketVariables(textMessage, isSos: isSos);

    if (isSos) {
      final triage = await triageSosMessage(textMessage);
      if (triage != null) {
        packetMap['triage'] = triage.toJsonString();
      }
    }

    final pubKey = await getPublicKeyB64();
    packetMap['deviceSenderPublicKey'] = pubKey;
    final canonical = canonicalSignedString(packetMap);
    final signature = await signPacket(canonical);
    packetMap['signature'] = signature;

    await insertMessage(packetMap);
    print(
      "💾 [sendNewMessage] Message saved. Will be picked up by relay loop.",
    );

    if (isSos) {
      final frame = encodePacketV3(packetMap, signature);
      final bytes = utf8.encode(frame);
      print(
        '🚨 [sendNewMessage] SOS fast-path: blasting to entire mesh (${bytes.length} bytes).',
      );
      unawaited(blastToEntireMesh(bytes));
    }
  } catch (e) {
    print("Failed to save message: $e");
  }
}

void unawaited(Future<void> future) {
  future.catchError((e, _) {
    print('unawaited future error: $e');
  });
}
