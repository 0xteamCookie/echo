import './decode.dart';
import '../database//db_hook.dart';
import '../send/send-message.dart';
import '../packet/get-deviceID.dart';

class MeshController {

  // 1. Phone B receives a message from Phone A (e.g. via a GATT Write)
  Future<List<int>> handleIncomingMessage(String rawData) async {

    final decoded = await decodeMessage(rawData);
    if (rawData.length < 5 || decoded == null) return [0x01]; // Malformed packet fallback

    final String messageId = decoded['messageId'];
    final String message = decoded['message'];
    final String deviceId = decoded['deviceId'];
    final String expiresAtStr = decoded['expiresAt'];
    final String location = decoded['location'];

    final DateTime expiresAt = DateTime.parse(expiresAtStr).toUtc();
    final DateTime deviceTime = DateTime.now().toUtc();
    final String currentDeviceId = await DeviceIdManager.getDeviceId();


    // 2. Validate expiresAt
    if (expiresAt.isBefore(deviceTime)) {
      print("Message expired. Dropping.");
      return [0x02]; // Message expired
    }

    // 3. Check duplicate (using DB helper)
    final exists = await messageExists(messageId);

    if (exists) {
      print("Duplicate message $messageId received.");
      return [0x03];
    }

    // 4. Store message using db-hook
    await insertMessage(decoded!);

    // 5. Store deviceID of original sender to avoid re-sending
    await insertMessageDevice(
      messageId: messageId,
      deviceId: deviceId,
    );

    // 6. Broadcast
    await relayMessage( messageId, message, currentDeviceId, expiresAtStr, location );

    // 7. ACK
    return [0x00];
  }
  }
