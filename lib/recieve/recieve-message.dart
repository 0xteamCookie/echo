import '../database/db_hook.dart';

Future<void> handleIncomingMessage(
  String msg,
  String senderHardwareMac, {
  required void Function(Map<String, dynamic>) onNewMessage,
  required void Function(Map<String, dynamic>) onNewHeartbeat,
}) async {
  final decoded = await decodeAndSaveMessage(msg, senderHardwareMac);

  if (decoded == null) return;

  if (decoded['messageId'] != null) {
    await insertMessageDevice(
      messageId: decoded['messageId'],
      deviceId: senderHardwareMac,
    );
  }

  if (decoded['isNew'] == false) return;

  final isHeartbeat =
      (decoded['message'].toString().contains('Heartbeat')) ||
      msg.toString().contains('Heartbeat');

  final payload = decoded;
  payload['relayerMac'] = senderHardwareMac; 

  if (isHeartbeat) {
    onNewHeartbeat(payload);
  } else {
    onNewMessage(payload);
  }
}

/// Decodes, saves it to SQLite, returns mapped data
Future<Map<String, dynamic>?> decodeAndSaveMessage(String rawMessage, String senderDeviceId) async {
  try {
    final parts = rawMessage.split('||');
    
    if (parts.length == 6) {
      final Map<String, dynamic> packetMap = {
        'messageId': parts[0],
        'message': parts[1],
        'deviceId': parts[2],
        'senderName': parts[3],
        'expiresAt': parts[4],
        'location': parts[5],
      };
      
      final exists = await messageExists(parts[0]);
      
      if (!exists) {
        await insertMessage(packetMap);
        packetMap['isNew'] = true;
      } else {
        packetMap['isNew'] = false;
      }
      
      return packetMap;
    }
    
    print("Received unformatted generic message: $rawMessage");
    return null;
    
  } catch (e) {
    print("Error decoding message: $e");
    return null;
  }
}