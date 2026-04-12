// import 'dart:async';
// import 'send-message.dart';

// Timer? heartbeatTimer;

// void startHeartbeat([String customPrefix = "Heartbeat"]) {
//   heartbeatTimer?.cancel();
  
//   if (customPrefix.trim().isEmpty) {
//     customPrefix = "Heartbeat";
//   }

//   heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//     String timeStr = DateTime.now().toIso8601String().substring(11, 19);
//     broadcastMessage("$customPrefix: $timeStr");
//   });
//   print("Heartbeat started with prefix: $customPrefix.");
// }

// void stopHeartbeat() {
//   heartbeatTimer?.cancel();
//   print("Heartbeat stopped.");
// }