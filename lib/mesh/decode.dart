Future<Map<String, dynamic>?> decodeMessage(String rawMessage) async {
  try {
    // Split the incoming payload by our delimiter
    final parts = rawMessage.split('||');
    
    // Ensure it matches our expected 5-part format
    if (parts.length == 6) {
      final packetMap = {
        'messageId': parts[0],
        'message': parts[1],
        'deviceId': parts[2],
        'senderName': parts[3],
        'expiresAt': parts[4],
        'location': parts[5],
      };
      
      // Return the map so the UI can display it
      return packetMap;
    }
    
    print("Received unformatted generic message: $rawMessage");
    return null;
    
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}