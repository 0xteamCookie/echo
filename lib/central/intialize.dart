import 'dart:io';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../mesh/ble_collisions.dart';
import '../core/constants.dart';

// ─── UUIDs
final Guid targetServiceUuid = Guid(kServiceUuid);
final Guid targetCharacteristicUuid = Guid(kCharacteristicUuid);
final String _targetServiceUuidLower = targetServiceUuid
    .toString()
    .toLowerCase();
final String _targetCharUuidLower = targetCharacteristicUuid
    .toString()
    .toLowerCase();

// ─── Callbacks & State
final Map<String, Map<String, dynamic>> _seenDevices = {};

// P3-5: prune devices not seen in the last kSeenDeviceTtl so the relay list stays fresh.
const Duration _seenDeviceTtl = kSeenDeviceTtl;
Timer? _seenDeviceSweepTimer;

StreamSubscription? _scanSubscription;
bool _isScanning = false;
bool _scanLoopScheduled = false;
bool _adapterListenerAttached = false;
Timer? _scanResultThrottleTimer;
bool _scanResultDirty = false;

final StreamController<List<Map<String, dynamic>>> _deviceStreamController =
    StreamController.broadcast();
Stream<List<Map<String, dynamic>>> get scanResultsStream =>
    _deviceStreamController.stream;

Function(List<Map<String, dynamic>> devices)? onDeviceListUpdated;

// ─── Permissions
Future<void> requestClientPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

// ─── Scanner
Future<void> startAutoScanner() async {
  try {
    await requestClientPermissions();
    if (Platform.isAndroid) {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        try {
          await FlutterBluePlus.turnOn();
        } catch (_) {}
      }
    }

    if (!_adapterListenerAttached) {
      _adapterListenerAttached = true;
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          _startScan();
        } else {
          stopScanning();
        }
      });
    }

    // P3-5: start a periodic sweep that drops stale entries from _seenDevices.
    _seenDeviceSweepTimer ??= Timer.periodic(
      const Duration(minutes: 1),
      (_) => _pruneSeenDevices(),
    );
  } catch (e) {
    print("❌ startAutoScanner error: $e");
  }
}

Future<void> stopScanning() async {
  await _scanSubscription?.cancel();
  await FlutterBluePlus.stopScan();
  _isScanning = false;
}

Future<void> restartScan() async {
  await stopScanning();
  await Future.delayed(const Duration(milliseconds: 500));
  await _startScan();
}

Future<void> _startScan() async {
  if (_isScanning) return;

  if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
    print("⚠️ [_startScan] Aborting: Bluetooth is not ON.");
    return;
  }

  _isScanning = true;
  await _scanSubscription?.cancel();
  _scanSubscription = FlutterBluePlus.onScanResults.listen(_onScanResult);

  try {
    // iOS (CoreBluetooth) silently drops scan results in the background unless
    // a service UUID filter is provided. Always pass withServices so background
    // scanning works on both Android and iOS.
    await FlutterBluePlus.startScan(
      withServices: [targetServiceUuid],
      timeout: const Duration(seconds: 30),
    );
  } catch (e) {
    print("❌ [_startScan] Failed to start scan: $e");
    _isScanning = false;
    return;
  }

  // Hook to restart scanning after timeout
  FlutterBluePlus.isScanning
      .where((s) => s == false)
      .first
      .then((_) {
        _isScanning = false;
        if (!_scanLoopScheduled) {
          _scanLoopScheduled = true;
          Future.delayed(const Duration(seconds: 2), () {
            _scanLoopScheduled = false;
            if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
              _startScan();
            }
          });
        }
      })
      .catchError((_) {
        _isScanning = false;
      });
}

void _onScanResult(List<ScanResult> results) {
  for (final r in results) {
    final id = r.device.remoteId.str;
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : "Unknown ($id)");

    // Only add devices that are advertising our Mesh Service UUID
    final advertisedUuids = r.advertisementData.serviceUuids;
    final hasTargetService = advertisedUuids.any(
      (u) => u.toString().toLowerCase() == _targetServiceUuidLower,
    );

    if (hasTargetService) {
      _seenDevices[id] = {
        'name': name,
        'id': id,
        'rssi': r.rssi,
        'serviceUuids': advertisedUuids.map((u) => u.toString()).toList(),
        'connected': false,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  _scanResultDirty = true;
  _scanResultThrottleTimer ??= Timer(
    const Duration(milliseconds: 500),
    _flushScanResults,
  );
}

void _flushScanResults() {
  _scanResultThrottleTimer = null;
  if (!_scanResultDirty) return;
  _scanResultDirty = false;
  final devicesList = _seenDevices.values.toList();
  onDeviceListUpdated?.call(devicesList);
  _deviceStreamController.add(devicesList);
}

// Get list of devices within range
List<Map<String, dynamic>> getCurrentScanResults() {
  return _seenDevices.values.toList();
}

/// P3-5: drop entries not refreshed within [_seenDeviceTtl]. Called on a
/// 1-minute timer so the relay loop never tries to dispatch to a node we
/// haven't heard from in 5+ minutes.
void _pruneSeenDevices() {
  if (_seenDevices.isEmpty) return;
  final cutoff = DateTime.now().subtract(_seenDeviceTtl).millisecondsSinceEpoch;
  final stale = <String>[];
  _seenDevices.forEach((id, dev) {
    final ls = dev['lastSeen'];
    final lastSeenMs = (ls is int)
        ? ls
        : int.tryParse((ls ?? '0').toString()) ?? 0;
    if (lastSeenMs < cutoff) stale.add(id);
  });
  if (stale.isEmpty) return;
  for (final id in stale) {
    _seenDevices.remove(id);
  }
  _scanResultDirty = true;
  _flushScanResults();
}

Future<bool> dispatchPayloadToDevice(
  String deviceId,
  List<int> payloadBytes,
) async {
  BluetoothDevice device = BluetoothDevice.fromId(deviceId);

  try {
    print("🔌 [dispatchPayload] Dialing MAC: $deviceId...");

    // Clear GATT cache only. `removeBond` was removed because it destroys
    // the user's pairings with unrelated Bluetooth devices (headphones,
    // car) every time we relay, which is a data-loss-class bug.
    if (Platform.isAndroid) {
      try {
        await device.clearGattCache();
      } catch (_) {}
    }

    // 1. Connect temporarily with a short timeout
    await device.connect(
      autoConnect: false,
      license: License.free,
      timeout: const Duration(seconds: 4),
    );

    // 2. Discover target service/characteristic
    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == _targetServiceUuidLower) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _targetCharUuidLower) {
            // 3. Dynamically check what the cached property allows
            bool canWriteNoResponse = char.properties.writeWithoutResponse;
            bool canWrite = char.properties.write;

            if (canWriteNoResponse || canWrite) {
              await char.write(payloadBytes, withoutResponse: true);
              print(
                "✅ [dispatchPayload] SUCCESS: Transmitted ${payloadBytes.length} bytes to $deviceId!",
              );
            } else {
              print(
                "❌ [dispatchPayload] FAILED: Characteristic lacks write properties on $deviceId",
              );
            }

            // Delay to let the radio buffer flush down to the hardware
            await Future.delayed(const Duration(milliseconds: 50));

            // 4. Disconnect immediately to free up the radio
            await device.disconnect();
            return true;
          }
        }
      }
    }

    print(
      "❌ [dispatchPayload] FAILED: Target characteristic not found on $deviceId",
    );
    await device.disconnect();
    return false;
  } catch (e) {
    print("🔥 [dispatchPayload] FATAL: Hardware exception on $deviceId: $e");
    BleCollisionManager.recordFailure(deviceId);
    try {
      await device.disconnect();
    } catch (_) {}
    return false;
  }
}

/// Blast a message to ALL discovered mesh nodes
Future<void> blastToEntireMesh(List<int> payloadBytes) async {
  await stopScanning();
  for (String deviceId in _seenDevices.keys) {
    await dispatchPayloadToDevice(deviceId, payloadBytes);
  }
  await _startScan();
}
