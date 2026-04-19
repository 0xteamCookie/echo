Future<Map<String, dynamic>?> decodeMessage(String rawMessage) async {
  try {
    final parts = rawMessage.split('||');
    
    if (parts.length == 7) {
      final packetMap = {
        'messageId': parts[0],
        'message': parts[1],
        'deviceId': parts[2],
        'senderName': parts[3],
        'expiresAt': parts[4],
        'location': parts[5],
        'isSos': int.tryParse(parts[6]) ?? 0,
      };
      
      return packetMap;
    }
    
    print("Received unformatted generic message: $rawMessage");
    return null;
    
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}