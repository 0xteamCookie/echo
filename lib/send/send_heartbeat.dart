import 'send_message.dart';

Future<bool> sendSosHeartbeat({
  required String department,
  String additionalMessage = '',
}) async {
  try {
    print("🚨 [sendSosHeartbeat] Broadcasting SOS for department: $department");

    // Format the payload
    final text =
        "[${department.toUpperCase()}] ${additionalMessage.isNotEmpty ? additionalMessage : 'Needs immediate assistance.'}";

    // Send as SOS-flagged message
    await sendNewMessage(text, isSos: true);

    print("🚨 [sendSosHeartbeat] SOS broadcast sent successfully!");
    return true;
  } catch (e) {
    print("🚨 [sendSosHeartbeat] Error broadcasting SOS: $e");
    return false;
  }
}
