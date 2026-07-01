import 'dart:async';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_peripheral/ble_peripheral.dart';
import '../database/db_hook.dart';
import '../central/intialize.dart';
import '../mesh/ble_collisions.dart';
import '../peripheral/initialize.dart';
import 'decision_relay_logic.dart';
import 'packet_codec.dart';
import '../core/constants.dart';

const String kMeshServiceUuid = kServiceUuid;

bool _isTimeSlicing = false;
Timer? _sliceTimer;

void startRelayLoop() {
  orchestratorMode = true;
  if (_isTimeSlicing) return;
  _isTimeSlicing = true;
  _executeSliceCycle();
}

void stopRelayLoop() {
  orchestratorMode = false;
  _isTimeSlicing = false;
  _sliceTimer?.cancel();
  _sliceTimer = null;
  FlutterBluePlus.stopScan();
  BlePeripheral.stopAdvertising();
}

Future<void> _executeSliceCycle() async {
  if (!_isTimeSlicing) return;

  try {
    // PHASE 1: SCAN
    print("📡 [Mesh] Entering SCAN Phase...");
    try {
      await BlePeripheral.stopAdvertising();
    } catch (_) {}

    await FlutterBluePlus.startScan(
      withServices: [Guid(kMeshServiceUuid)],
      timeout: const Duration(seconds: 4),
    );
    await Future.delayed(const Duration(seconds: 4));

    if (!_isTimeSlicing) return;

    // Fetch discovered nodes
    final nearbyDevices = _getCleanUniqueDevices();

    if (nearbyDevices.isNotEmpty) {
      print("🎯 [Mesh] Found active nodes! Freezing orchestrator to relay messages...");
      
      // CRITICAL: We await the full completion of the delivery AND the disconnection
      // This completely blocks the timer from progressing or resetting prematurely
      await _processMeshRouting(nearbyDevices); 
      
      print("✅ [Mesh] Relay complete. Resetting the cycle fresh.");
    }

    // Always start advertising after scan/relay phase so other nodes can discover us
    await startAdvertisingSequence();

    // Schedule the next check ONLY after all transmissions are 100% finished
    _sliceTimer = Timer(const Duration(seconds: 6), () {
      _executeSliceCycle();
    });

  } catch (e) {
    print("❌ Error in cycle: $e");
    _sliceTimer = Timer(const Duration(seconds: 5), () => _executeSliceCycle());
  }
}

List<Map<String, dynamic>> _getCleanUniqueDevices() {
  final seenIds = <String>{};
  final cleanDevices = <Map<String, dynamic>>[];
  
  for (final r in FlutterBluePlus.lastScanResults) {
    final id = r.device.remoteId.str;
    if (seenIds.contains(id)) continue;
    seenIds.add(id);
    
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : "Unknown ($id)");
              
    cleanDevices.add({
      'id': id,
      'name': name,
      'rssi': r.rssi,
    });
  }
  return cleanDevices;
}

Future<void> _processMeshRouting(List<Map<String, dynamic>> nearbyDevices) async {
  final messages = await getNonExpiredMessages();
  if (messages.isEmpty) {
    print("⏱️ [Mesh] Process Routing: No non-expired messages.");
    return;
  }

  // Sort by RSSI exactly like your original implementation
  nearbyDevices.sort((a, b) {
    final ra = (a['rssi'] is int)
        ? a['rssi'] as int
        : int.tryParse((a['rssi'] ?? '').toString()) ?? -999;
    final rb = (b['rssi'] is int)
        ? b['rssi'] as int
        : int.tryParse((b['rssi'] ?? '').toString()) ?? -999;
    return rb.compareTo(ra);
  });

  print(
    "⏱️ [Mesh] Process Routing: Msgs: ${messages.length} // Nearby: ${nearbyDevices.length}",
  );

  for (final msg in messages) {
    final messageId = (msg['messageId'] ?? '').toString();
    final hopCount = (msg['hopCount'] is int)
        ? msg['hopCount'] as int
        : int.tryParse((msg['hopCount'] ?? '0').toString()) ?? 0;

    if (hopCount >= maxHops) continue;

    final devicesThatNeedMessage = await evaluateRelayDecision(
      messageId: messageId,
      nearbyDevices: nearbyDevices,
      shouldSkipDevice: BleCollisionManager.shouldSkip,
      hasAcknowledged: _hasAcknowledged,
    );

    if (devicesThatNeedMessage.isNotEmpty) {
      // Write characteristics here to nodes found during the scan window
      await relayMessage(msg, devicesThatNeedMessage);
    }
  }
}

Future<bool> _hasAcknowledged(String messageId, String deviceId) async {
  final devices = await getDevicesForMessage(messageId);
  return devices.any((d) => d['deviceId'] == deviceId);
}
