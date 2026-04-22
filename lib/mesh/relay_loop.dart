import 'dart:async';
import '../database/db_hook.dart';
import '../central/intialize.dart';
import '../mesh/ble-collisions.dart';
import 'decision_relay_logic.dart';
import '../online/sync.dart';

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

  // Try syncing to the backend on every tick
  print("⏱️ [RelayLoop] Triggering syncMessages() to send POST requests if needed...");
  syncMessages();

  try {
    final messages = await getNonExpiredMessages();
    if (messages.isEmpty) return;

    final nearbyDevices = getCurrentScanResults();
    if (nearbyDevices.isEmpty) return;
    
    print("⏱️ [RelayLoop] Tick Executing! Non-Expired Msgs: ${messages.length} // Nearby Active Nodes: ${nearbyDevices.length}");

    for (final msg in messages) {
      final messageId = msg['messageId'] as String;
      final message = msg['message'] as String;
      final deviceId = msg['deviceId'] as String;
      final senderName = msg['senderName'] as String;
      final expiresAt = msg['expiresAt'] as String;
      final location = msg['location'] as String;
      final isSos = msg['isSos'] as int? ?? 0;

      final devicesThatNeedMessage = await evaluateRelayDecision(
        messageId: messageId,
        nearbyDevices: nearbyDevices,
        shouldSkipDevice: BleCollisionManager.shouldSkip,
        hasAcknowledged: _hasAcknowledged,
      );

      if (devicesThatNeedMessage.isNotEmpty) {
        await relayMessage(
          messageId,
          message,
          deviceId,
          senderName,
          expiresAt,
          location,
          isSos,
          devicesThatNeedMessage,
        );
      }
    }
  } catch (e) {
    print("Relay tick error: $e");
  } finally {
    _relayRunning = false;
  }
}

Future<bool> _hasAcknowledged(String messageId, String deviceId) async {
  final devices = await getDevicesForMessage(messageId);
  return devices.any((d) => d['deviceId'] == deviceId);
}
