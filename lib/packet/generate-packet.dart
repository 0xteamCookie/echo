import 'get-deviceID.dart';
import 'get-location.dart';
import 'get-messageid.dart';
import 'get-userName.dart';

const Duration messageLifespan = Duration(days: 1);

Future<Map<String, dynamic>> generatePacketVariables(String message) async {
  String deviceId = await DeviceIdManager.getDeviceId();
  String location = await getCurrentLocationString();
  String messageId = generateMessageId();
  String expiresAt = DateTime.now().add(messageLifespan).toIso8601String();
  String senderName = await UserSettings.getName();
  if (senderName.isEmpty) {
    senderName = 'Anon';
  }

  return {
    'messageId': messageId,
    'message': message,
    'deviceId': deviceId,
    'senderName': senderName,
    'expiresAt': expiresAt,
    'location': location,
  };
}