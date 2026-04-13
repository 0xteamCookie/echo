import 'dart:async';
import '../database/db_hook.dart';
import '../send/send-message.dart';
import '../central/intialize.dart';

const Duration relayInterval = Duration(seconds: 15);

Timer? _relayTimer;
bool _relayRunning = false;

void startRelayLoop() {
  _relayTimer?.cancel();
  _relayTimer = Timer.periodic(relayInterval, (_) => _relayTick());
}

void stopRelayLoop() {
  _relayTimer?.cancel();
  _relayTimer = null;
}

Future<void> _relayTick() async {
  if (_relayRunning) return;
  _relayRunning = true;

  try {
    final messages = await getNonExpiredMessages();
    if (messages.isEmpty) return;

    final nearbyDevices = getCurrentScanResults();
    if (nearbyDevices.isEmpty) return;

    for (final msg in messages) {
      final messageId = msg['messageId'] as String;
      final message = msg['message'] as String;
      final deviceId = msg['deviceId'] as String;
      final senderName = msg['senderName'] as String;
      final expiresAt = msg['expiresAt'] as String;
      final location = msg['location'] as String;
      await relayMessage(messageId, message, deviceId, senderName, expiresAt, location);
    }
  } catch (e) {
    print("Relay tick error: $e");
  } finally {
    _relayRunning = false;
  }
}
