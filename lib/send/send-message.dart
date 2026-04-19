import '../database/db_hook.dart';
import '../packet/generate-packet.dart';

Future<void> sendNewMessage(String textMessage, {bool isSos = false}) async {
  try {
    print("📨 [sendNewMessage] Generating new message: $textMessage");
    final packetMap = await generatePacketVariables(textMessage, isSos:isSos);

    await insertMessage(packetMap);

    print("💾 [sendNewMessage] Message saved. Will be picked up by relay loop.");
  } catch (e) {
    print("Failed to save message: $e");
  }
}
