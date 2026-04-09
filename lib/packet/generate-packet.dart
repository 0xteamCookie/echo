import 'get-deviceID.dart';
import 'get-location.dart';
import 'get-messageid.dart';

const Duration messageLifespan = Duration(days: 1);

Future<Map<String, dynamic>> generatePacketVariables(String message) async {
  String deviceId = await DeviceIdManager.getDeviceId();
  String location = await getCurrentLocationString();
  String messageId = generateMessageId();
  String expiresAt = DateTime.now().add(messageLifespan).toIso8601String();

  return {
    'messageId': messageId,
    'message': message,
    'deviceId': deviceId,
    'expiresAt': expiresAt, 
    'location': location,
  };
}