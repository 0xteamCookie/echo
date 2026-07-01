import 'dart:convert';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/constants.dart';
import '../packet/get_user_name.dart';

const String myServiceUuid = kServiceUuid;
const String myCharacteristicUuid = kCharacteristicUuid;

Function(String rawMessage, String senderDeviceId)? onPeripheralMessageReceived;

Future<void> requestBlePermissions() async {
  await [Permission.bluetooth, Permission.bluetoothAdvertise].request();
}

// Add the GATT service once. Rebuilding it on every BT toggle can trigger the
// OEM pairing popup, so we keep it.
bool _serviceAdded = false;

Future<void> setupBlePeripheral() async {
  try {
    await requestBlePermissions();
    await BlePeripheral.initialize();
    print("BLE INITIALIZED - OPEN GATT");

    // Build the GATT service exactly once.
    await _ensureServiceAdded();

    // Listen to OS Bluetooth State changes
    BlePeripheral.setBleStateChangeCallback((bool isOn) async {
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
      if (isOn) {
        // BT off can drop the server on some OEMs; re-add if needed, then advertise.
        await _ensureServiceAdded();
        await _startAdvertisingSequence();
      } else {
        _serviceAdded = false;
        await BlePeripheral.stopAdvertising();
      }
    });

    BlePeripheral.setWriteRequestCallback((
      String deviceId,
      String characteristicId,
      int offset,
      Uint8List? value,
    ) {
      if (characteristicId.toLowerCase() ==
              myCharacteristicUuid.toLowerCase() &&
          value != null) {
        try {
          String receivedMessage = utf8.decode(value);
          print("Received Message from $deviceId: $receivedMessage");
          onPeripheralMessageReceived?.call(receivedMessage, deviceId);
        } catch (e) {
          print("Failed to decode written data: $e");
        }
        return null;
      }
      return null;
    });

    await _startAdvertisingSequence();
  } catch (e) {
    print("Error Initializing, $e");
  }
}

/// Adds the GATT service once (idempotent). Keep the char PLAIN (unencrypted,
/// write-without-response) — encryption/notify would force pairing.
Future<void> _ensureServiceAdded() async {
  if (_serviceAdded) return;
  try {
    // Clear any stale service, then add ours.
    try {
      await BlePeripheral.clearServices();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 300));
    await BlePeripheral.addService(
      BleService(
        uuid: myServiceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: myCharacteristicUuid,
            properties: [CharacteristicProperties.writeWithoutResponse.index],
            value: null,
            permissions: [AttributePermissions.writeable.index],
          ),
        ],
      ),
    );
    _serviceAdded = true;
  } catch (e) {
    print("Service add deferred: $e");
  }
}

Future<void> _startAdvertisingSequence() async {
  try {
    try {
      await BlePeripheral.stopAdvertising();
    } catch (_) {}

    String userName = await UserSettings.getName();
    userName = userName.trim();
    if (userName.length > 8) {
      userName = userName.substring(0, 8);
    }
    final String localName = userName.isNotEmpty ? userName : "Echo";

    await BlePeripheral.startAdvertising(
      services: [myServiceUuid],
      localName: localName,
    );
    print("Advertising open mailbox as $localName...");
  } catch (e) {
    print("Broadcasting deferred: $e");
  }
}
