import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// ─── UUIDs 
final Guid targetServiceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
final Guid targetCharacteristicUuid = Guid(
  "12345678-1234-5678-1234-56789abcdef1",
);

// ─── Callbacks & State 
Function(String message)? onMessageReceived;
Function(List<Map<String, dynamic>> devices)? onDeviceListUpdated;

final Map<String, Map<String, dynamic>> _seenDevices = {};
StreamSubscription? _scanSubscription;
bool _isScanning = false;

// ─── Permissions 
Future<void> requestClientPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

// ─── Scanner (Just builds a list of nearby Mailboxes) 
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

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        _startScan();
      } else {
        stopScanning();
      }
    });
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
    Future.delayed(const Duration(seconds: 2), _startScan);
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
      (u) =>
          u.toString().toLowerCase() ==
          targetServiceUuid.toString().toLowerCase(),
    );

    if (hasTargetService) {
      _seenDevices[id] = {
        'name': name,
        'id': id,
        'rssi': r.rssi,
        'serviceUuids': advertisedUuids.map((u) => u.toString()).toList(),
        'connected': false,
      };
      onDeviceListUpdated?.call(_seenDevices.values.toList());
    }
  }
}

//  Mailman: Connect, Write, Disconnect 

/// This function is called when you want to send a message.
/// It connects to a target device, drops the payload in the writeable characteristic, and disconnects.
Future<void> dispatchPayloadToDevice(
  String deviceId,
  List<int> payloadBytes,
) async {
  BluetoothDevice device = BluetoothDevice.fromId(deviceId);

  try {
    print("🚀 Delivering mail to $deviceId...");

    await FlutterBluePlus.stopScan();
    await Future.delayed(const Duration(milliseconds: 200));

    // 1. Connect temporarily
    await device.connect(autoConnect: false, license: License.free);

    // Force Android to fetch the latest characteristic properties (Clear Cache)
    if (Platform.isAndroid) {
      try {
        await device.clearGattCache();
      } catch (_) {}
    }

    // Give Android BLE stack a moment to stabilize the connection
    await Future.delayed(const Duration(milliseconds: 500));

    // 2. Discover target service/characteristic
    List<BluetoothService> services = await device.discoverServices();
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() ==
          targetServiceUuid.toString().toLowerCase()) {
        for (var char in service.characteristics) {
          if (char.uuid.toString().toLowerCase() ==
              targetCharacteristicUuid.toString().toLowerCase()) {
            
            // 3. Dynamically check what the cached property allows
            bool canWriteNoResponse = char.properties.writeWithoutResponse;
            bool canWrite = char.properties.write;

            if (canWriteNoResponse || canWrite) {
              await char.write(payloadBytes, withoutResponse: canWriteNoResponse);
              print("✅ Mail delivered successfully to $deviceId!");
            } else {
              print("❌ Cached characteristic has NO write properties! Toggle Bluetooth on BOTH phones.");
            }

            // Give the radio time to actually transmit the packet before severing the connection
            await Future.delayed(const Duration(milliseconds: 500));

            // 4. Disconnect to free up the radio
            await device.disconnect();
            return;
          }
        }
      }
    }

    print("❌ Mailbox characteristic not found on $deviceId");
    await device.disconnect();
  } catch (e) {
    print("❌ Failed to deliver mail to $deviceId: $e");
    try {
      await device.disconnect();
    } catch (_) {}
  }
}
/// Helper function to blast a message to ALL discovered mesh nodes
Future<void> blastToEntireMesh(List<int> payloadBytes) async {
  // Pause scanning while transmitting so radio isn't overwhelmed
  await stopScanning();

  for (String deviceId in _seenDevices.keys) {
    await dispatchPayloadToDevice(deviceId, payloadBytes);
  }

  // Resume scanning
  await _startScan();
}
