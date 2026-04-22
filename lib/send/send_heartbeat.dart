import 'send_message.dart';

/// Sends an SOS (emergency) message to the mesh network with department context
/// 
/// [department] - The selected department (Rescue, Medical, Fire, Police)
/// [additionalMessage] - Optional additional details to include in the SOS
/// 
/// Returns true if broadcast was successful, false otherwise
Future<bool> sendSosHeartbeat({
  required String department,
  String additionalMessage = '',
}) async {
  try {
    print("🚨 [sendSosHeartbeat] Broadcasting SOS for department: $department");
    
    // Format the payload with department context
    final text = "[${ department.toUpperCase()}] ${additionalMessage.isNotEmpty ? additionalMessage : 'Needs immediate assistance.'}";
    
    // Send as SOS-flagged message (isSos=true)
    await sendNewMessage(text, isSos: true);
    
    print("🚨 [sendSosHeartbeat] SOS broadcast sent successfully!");
    return true;
  } catch (e) {
    print("🚨 [sendSosHeartbeat] Error broadcasting SOS: $e");
    return false;
  }
}