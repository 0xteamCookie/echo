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
    if (parts.length == 5) {
      final packetMap = {
        'deviceId': parts[0],
        'messageId': parts[1],
        'location': parts[2],
        'expiresAt': parts[3],
        'message': parts[4],
      };
      
      // 3. Save the received packet into SQLite
      await insertMessage(packetMap);
      
      // 4. Return the map so the UI can display it
      return packetMap;
    }
    
    print("Received unformatted generic message: $rawMessage");
    return null;
    
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}