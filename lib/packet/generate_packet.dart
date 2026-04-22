import 'get_device_id.dart';
import 'get_location.dart';
import 'get_message_id.dart';
import 'get_user_name.dart';

const Duration messageLifespan = Duration(days: 1);

Future<Map<String, dynamic>> generatePacketVariables(String message, {bool isSos = false}) async {
  String deviceId = await DeviceIdManager.getDeviceId();
  String location = await getCurrentLocationString();
  String messageId = generateMessageId();
  // P1-6: always UTC so getNonExpiredMessages() comparison is tz-consistent.
  final nowUtc = DateTime.now().toUtc();
  String time = nowUtc.toIso8601String();
  String expiresAt = nowUtc.add(messageLifespan).toIso8601String();
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
    'time': time,
    'hopCount': 0,
    'isSos': isSos ? 1 : 0,
  };
}