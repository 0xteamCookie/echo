import '../database/db_hook.dart';

/// Decodes the compact string, saves it to SQLite, and returns the mapped data.
Future<Map<String, dynamic>?> decodeAndSaveMessage(String rawMessage, String senderDeviceId) async {
  try {

    if (rawMessage.startsWith('ACK||')) {
      final parts = rawMessage.split('||');
      if (parts.length >= 3) {
        String ackMessageId = parts[1];
        String relayerId = parts[2];
        
        await insertMessageDevice(messageId: ackMessageId, deviceId: relayerId);
        print("✅ Acknowledgment saved for Msg: $ackMessageId from $relayerId");
      }
      return null;
    }
    // 1. Split the incoming payload by our delimiter
    final parts = rawMessage.split('||');
    
    // 2. Ensure it matches our expected 5-part format
    if (parts.length == 6) {
      final Map<String, dynamic> packetMap = {
        'messageId': parts[0],
        'message': parts[1],
        'deviceId': parts[2],
        'senderName': parts[3],
        'expiresAt': parts[4],
        'location': parts[5],
      };
      
      final exists = await messageExists(parts[1]);
      
      if (!exists) {
        // 3. Save the received packet into SQLite only if new
        await insertMessage(packetMap);
        packetMap['isNew'] = true;
        print("🎉 [decodeAndSaveMessage] Vetted and Saved NEW Incoming Message: ${parts[0]}");
      } else {
        packetMap['isNew'] = false;
        print("🧱 [decodeAndSaveMessage] Deduplicating Message: ${parts[1]} (Already exists in DB. Ghosting.)");
      }
      
      // 4. Return the map so the UI can process it
      return packetMap;
    }
    
    print("❓ [decodeAndSaveMessage] Received unformatted generic message: $rawMessage");
    return null;
    
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}