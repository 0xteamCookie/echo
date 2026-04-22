import 'dart:convert';
import '../central/intialize.dart';
import '../database/db_hook.dart';
import '../mesh/packet_codec.dart';
import '../packet/generate-packet.dart';

Future<void> sendNewMessage(String textMessage, {bool isSos = false}) async {
  try {
    print("📨 [sendNewMessage] Generating new message: $textMessage");
    final packetMap = await generatePacketVariables(textMessage, isSos: isSos);

    await insertMessage(packetMap);
    print("💾 [sendNewMessage] Message saved. Will be picked up by relay loop.");

    // P1-3: SOS fast-path. Don't wait up to 15 s for the next relay tick —
    // blast the packet to every currently-discovered mesh node in parallel
    // with the SQLite insert.
    if (isSos) {
      final frame = encodePacketV2(packetMap);
      final bytes = utf8.encode(frame);
      print(
        '🚨 [sendNewMessage] SOS fast-path: blasting to entire mesh (${bytes.length} bytes).',
      );
      // Don't await — let the blast run in the background.
      unawaited(blastToEntireMesh(bytes));
    }
  } catch (e) {
    print("Failed to save message: $e");
  }
}

/// Tiny helper so we can fire-and-forget without a lint.
void unawaited(Future<void> future) {
  future.catchError((e, _) {
    print('unawaited future error: $e');
  });
}
