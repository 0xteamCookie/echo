Future<Map<String, dynamic>?> decodeMessage(String rawMessage) async {
  try {
    // Split the incoming payload by our delimiter
    final parts = rawMessage.split('||');
    
    // Ensure it matches our expected 5-part format
    if (parts.length == 5) {
      final packetMap = {
        'deviceId': parts[0],
        'messageId': parts[1],
        'location': parts[2],
        'expiresAt': parts[3],
        'message': parts[4],
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