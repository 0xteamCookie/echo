import 'dart:io';
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../mesh/ble-collisions.dart';

final Guid targetServiceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
final Guid targetCharacteristicUuid = Guid("12345678-1234-5678-1234-56789abcdefF");
final String _targetServiceUuidLower = targetServiceUuid.toString().toLowerCase();
final String _targetCharUuidLower = targetCharacteristicUuid.toString().toLowerCase();

final Map<String, Map<String, dynamic>> _seenDevices = {};

StreamSubscription? _scanSubscription;
bool _isScanning = false;
bool _scanLoopScheduled = false;
bool _adapterListenerAttached = false;
Timer? _scanResultThrottleTimer;
bool _scanResultDirty = false;

Function(List<Map<String, dynamic>> devices)? onDeviceListUpdated;

Future<void> requestClientPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

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
  _isScanning = true;
  await _scanSubscription?.cancel();

  _scanSubscription = FlutterBluePlus.onScanResults.listen(_onScanResult);

  await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

  FlutterBluePlus.isScanning.where((s) => s == false).first.then((_) {
    _isScanning = false;
    if (!_scanLoopScheduled) {
      _scanLoopScheduled = true;
      Future.delayed(const Duration(seconds: 2), () {
        _scanLoopScheduled = false;
        _startScan();
      });
    }
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
      };
    }
  }

  _scanResultDirty = true;
  _scanResultThrottleTimer ??= Timer(const Duration(milliseconds: 500), _flushScanResults);
}

void _flushScanResults() {
  _scanResultThrottleTimer = null;
  if (!_scanResultDirty) return;
  _scanResultDirty = false;
  final devicesList = _seenDevices.values.toList();
  onDeviceListUpdated?.call(devicesList);
}

// Get list of devices within range
List<Map<String, dynamic>> getCurrentScanResults() {
  return _seenDevices.values.toList();
}

Future<bool> dispatchPayloadToDevice(
  String deviceId,
  List<int> payloadBytes,
) async {
  BluetoothDevice device = BluetoothDevice.fromId(deviceId);

  try {
    print("🚀 Sending to $deviceId...");

    await device.connect(
      autoConnect: false,
      timeout: const Duration(seconds: 4),
      license: License.free
    );

    List<BluetoothService> services = await device.discoverServices();

    for (var service in services) {
      if (service.uuid.toString().toLowerCase() == _targetServiceUuidLower) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() == _targetCharUuidLower) {
            
            bool canWriteNoResponse = char.properties.writeWithoutResponse;
            bool canWrite = char.properties.write;

            if (canWriteNoResponse || canWrite) {
              await char.write(payloadBytes, withoutResponse: canWriteNoResponse);
              print("✅ Sent successfully to $deviceId!");
            } else {
              print("❌ NO write permission on $deviceId");
            }

            await Future.delayed(const Duration(milliseconds: 50));

            await device.disconnect();
            return true;
          }
        }
      }
    }

    print("❌ Characteristic not found on $deviceId");
    await device.disconnect();
    return false;
  } catch (e) {
    print("❌ Failed to send to $deviceId: $e");
    BleCollisionManager.recordFailure(deviceId);
    try {
      await device.disconnect();
    } catch (_) {}
    return false;
  }
}

