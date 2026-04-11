import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

// ─── Change these to match what your peripheral actually advertises ───────────
final Guid targetServiceUuid =
    Guid("12345678-1234-5678-1234-56789abcdef0");
final Guid targetCharacteristicUuid =
    Guid("12345678-1234-5678-1234-56789abcdef1");
// ─────────────────────────────────────────────────────────────────────────────

/// Called whenever a new heartbeat message arrives.
Function(String message)? onMessageReceived;

/// Called whenever the scanned-device list changes.
/// Each entry: { 'name': String, 'id': String, 'rssi': int }
Function(List<Map<String, dynamic>> devices)? onDeviceListUpdated;

/// Currently connected device (null if none).
BluetoothDevice? connectedDevice;

// Internal state
final Map<String, Map<String, dynamic>> _seenDevices = {};
StreamSubscription? _scanSubscription;
bool _isConnecting = false;

// ─── Permissions ──────────────────────────────────────────────────────────────

Future<void> requestClientPermissions() async {
  await [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();

  final scanStatus = await Permission.bluetoothScan.status;
  final connectStatus = await Permission.bluetoothConnect.status;
  final locationStatus = await Permission.location.status;

  print("📋 Permissions — SCAN: $scanStatus | CONNECT: $connectStatus | LOCATION: $locationStatus");
}

// ─── Main entry point ─────────────────────────────────────────────────────────

/// Stop the current scan.
Future<void> stopScanning() async {
  await _scanSubscription?.cancel();
  await FlutterBluePlus.stopScan();
  print("🛑 Scan stopped");
}

/// Restart the scan manually (useful for a "Search" button).
Future<void> restartScan() async {
  print("🔄 Restarting scan...");
  await stopScanning();
  await Future.delayed(const Duration(milliseconds: 500));
  await _startScan();
}

/// Connect to a specific device by ID.
Future<void> connectToDevice(String deviceId) async {
  if (_isConnecting) {
    print("⚠️  Already connecting, please wait");
    return;
  }
  
  try {
    final device = BluetoothDevice.fromId(deviceId);
    print("🔌 Attempting to connect to $deviceId...");
    await stopScanning();
    _isConnecting = true;
    await _connectWithRetry(device);
  } catch (e) {
    print("❌ Error: $e");
    _isConnecting = false;
  }
}

/// Call this once from initState().  Waits for BT to be ON, requests
/// permissions, then starts an indefinite scan (no service-UUID filter so
/// ALL nearby BLE devices are visible).
Future<void> startAutoScanner() async {
  try {
    await requestClientPermissions();
    if (Platform.isAndroid) {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) {
        print("Bluetooth is off, requesting to turn on...");
        try {
          await FlutterBluePlus.turnOn();
        } catch (e) {
          print("User refused or unable to turn on BT: $e");
        }
      }
    }

    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        print("🔵 Bluetooth turned ON -> Starting Scanner");
        _startScan();
      } else {
        print("🔴 Bluetooth turned OFF -> Stopping Scanner");
        stopScanning();
        connectedDevice = null;
        _isConnecting = false;
      }
    });

  } catch (e) {
    print("❌ startAutoScanner error: $e");
  }
}
// ─── Scanning ─────────────────────────────────────────────────────────────────

Future<void> _startScan() async {
  // Cancel any existing subscription first
  await _scanSubscription?.cancel();
  _seenDevices.clear();

  print("🔍 Starting BLE scan (no UUID filter — shows all devices)...");

  // FIX #1: Subscribe to results BEFORE calling startScan
  _scanSubscription = FlutterBluePlus.onScanResults.listen(
    _onScanResult,
    onError: (e) => print("❌ Scan stream error: $e"),
  );

  // FIX #2: No withServices filter → discovers every advertising BLE device
  await FlutterBluePlus.startScan(
    // withServices: [targetServiceUuid],  // ← removed; add back once UUIDs confirmed
    timeout: const Duration(seconds: 30),
  );

  // When the 30-second window closes, restart automatically
  FlutterBluePlus.isScanning.where((s) => s == false).first.then((_) {
    if (!_isConnecting) {
      print("🔄 Scan window ended — restarting...");
      Future.delayed(const Duration(seconds: 2), _startScan);
    }
  });
}

void _onScanResult(List<ScanResult> results) async {
  for (final r in results) {
    final id = r.device.remoteId.str;
    final name = r.device.platformName.isNotEmpty
        ? r.device.platformName
        : (r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : "Unknown ($id)");

    // Update running map of seen devices
    _seenDevices[id] = {
      'name': name,
      'id': id,
      'rssi': r.rssi,
      'serviceUuids': r.advertisementData.serviceUuids.map((u) => u.toString()).toList(),
      'connected': false,
    };

    // Notify UI
    onDeviceListUpdated?.call(_seenDevices.values.toList());

    // FIX #3: Check if this device advertises our target service
    final advertisedUuids = r.advertisementData.serviceUuids;
    final hasTargetService = advertisedUuids.any(
      (u) => u.toString().toLowerCase() == targetServiceUuid.toString().toLowerCase(),
    );

    if (hasTargetService && !_isConnecting && connectedDevice == null) {
      print("✅ Found target peripheral: $name");
      _isConnecting = true;
      await FlutterBluePlus.stopScan();
      await _connectWithRetry(r.device);
    }
  }
}

// ─── Connection ───────────────────────────────────────────────────────────────

Future<void> _connectWithRetry(BluetoothDevice device, {int maxRetries = 3}) async {
  for (int attempt = 1; attempt <= maxRetries; attempt++) {
    StreamSubscription? stateSub;
    try {
      print("🔌 Connection attempt $attempt/$maxRetries → ${device.platformName}");

      stateSub = device.connectionState.listen((state) {
        print("   Connection state: $state");
        if (state == BluetoothConnectionState.disconnected && connectedDevice != null) {
          print("⚠️  Device disconnected — rescanning...");
          connectedDevice = null;
          _isConnecting = false;
          _updateDeviceConnected(device.remoteId.str, false);
          Future.delayed(const Duration(seconds: 2), _startScan);
        }
      });

      // FIX #4: No 'license' parameter — standard flutter_blue_plus API
      await device.connect(
        license: License.free,
        autoConnect: false,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception("connect() timed out");
      });

      // Wait for confirmed connected state
      await device.connectionState
          .where((s) => s == BluetoothConnectionState.connected)
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception("connectionState never reached connected");
      });

      print("✅ Connected to ${device.platformName} on attempt $attempt");
      connectedDevice = device;
      _updateDeviceConnected(device.remoteId.str, true);

      await _subscribeToCharacteristic(device);
      return; // success

    } catch (e) {
      stateSub?.cancel();
      print("❌ Attempt $attempt failed: $e");
      try { await device.disconnect(); } catch (_) {}

      if (attempt < maxRetries) {
        final wait = attempt * 2;
        print("⏳ Retrying in ${wait}s...");
        await Future.delayed(Duration(seconds: wait));
      } else {
        print("❌ All retries exhausted — resuming scan");
        _isConnecting = false;
        await _startScan();
      }
    }
  }
}

// ─── GATT subscription ────────────────────────────────────────────────────────

Future<void> _subscribeToCharacteristic(BluetoothDevice device) async {
  try {
    print("🔍 Discovering services...");
    final services = await device.discoverServices();
    print("📡 ${services.length} services found");

    for (final service in services) {
      print("   • Service: ${service.uuid}");

      if (service.uuid.toString().toLowerCase() ==
          targetServiceUuid.toString().toLowerCase()) {
        print("   ✅ Target service matched!");

        for (final char in service.characteristics) {
          print("      – Characteristic: ${char.uuid}");

          if (char.uuid.toString().toLowerCase() ==
              targetCharacteristicUuid.toString().toLowerCase()) {
            print("      ✅ Target characteristic matched!");

            await char.setNotifyValue(true);
            print("📢 Subscribed to notifications");

            final sub = char.lastValueStream.listen((value) {
              if (value.isNotEmpty) {
                try {
                  final msg = utf8.decode(value);
                  print("💓 Heartbeat: $msg");
                  onMessageReceived?.call(msg);
                } catch (e) {
                  // Fallback: show raw bytes
                  final raw = value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
                  print("📦 Raw bytes: $raw");
                  onMessageReceived?.call("[bytes] $raw");
                }
              }
            });

            device.cancelWhenDisconnected(sub);
            _isConnecting = false;
            return;
          }
        }
        print("   ❌ Target characteristic not found in service");
      }
    }

    print("❌ Target service not found — check UUIDs match the peripheral");
    _isConnecting = false;
    await Future.delayed(const Duration(seconds: 2));
    await _startScan();

  } catch (e) {
    print("❌ discoverServices error: $e");
    _isConnecting = false;
    try { await device.disconnect(); } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
    await _startScan();
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

void _updateDeviceConnected(String id, bool connected) {
  if (_seenDevices.containsKey(id)) {
    _seenDevices[id]!['connected'] = connected;
    onDeviceListUpdated?.call(_seenDevices.values.toList());
  }
}