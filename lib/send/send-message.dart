import '../database/db_hook.dart';
import '../packet/generate-packet.dart';

Future<void> sendNewMessage(String textMessage) async {
  try {
    print("📨 [sendNewMessage] Generating new message: $textMessage");
    final packetMap = await generatePacketVariables(textMessage);

    await insertMessage(packetMap);

    print("💾 [sendNewMessage] Message saved. Will be picked up by relay loop.");
  } catch (e) {
    print("Failed to save message: $e");
  }
}
