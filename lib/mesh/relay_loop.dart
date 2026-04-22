import 'dart:async';
import '../database/db_hook.dart';
import '../central/intialize.dart';
import '../mesh/ble-collisions.dart';
import 'decision_relay_logic.dart';
import 'packet_codec.dart';

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

    print("⏱️ [RelayLoop] Tick Executing! Non-Expired Msgs: ${messages.length} // Nearby Active Nodes: ${nearbyDevices.length}");

    for (final msg in messages) {
      final messageId = (msg['messageId'] ?? '').toString();
      final hopCount = (msg['hopCount'] is int)
          ? msg['hopCount'] as int
          : int.tryParse((msg['hopCount'] ?? '0').toString()) ?? 0;

      // P1-2: stop relaying once TTL is exhausted.
      if (hopCount >= maxHops) continue;

      final devicesThatNeedMessage = await evaluateRelayDecision(
        messageId: messageId,
        nearbyDevices: nearbyDevices,
        shouldSkipDevice: BleCollisionManager.shouldSkip,
        hasAcknowledged: _hasAcknowledged,
      );

      if (devicesThatNeedMessage.isNotEmpty) {
        await relayMessage(msg, devicesThatNeedMessage);
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

