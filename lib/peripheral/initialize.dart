import 'dart:convert';
import 'dart:typed_data';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

const String myServiceUuid = "12345678-1234-5678-1234-56789abcdef0";
const String myCharacteristicUuid = "12345678-1234-5678-1234-56789abcdefF";

// Add a global callback for when a raw string is received via GATT Write
Function(String rawMessage, String senderDeviceId)? onPeripheralMessageReceived;

Future<void> requestBlePermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

Future<void> setupBlePeripheral() async {
  try {
    await requestBlePermissions();
    await BlePeripheral.initialize();
    print("BLE INITIALIZED - OPEN GATT");
    
    // Listen to OS Bluetooth State changes
    BlePeripheral.setBleStateChangeCallback((bool isOn) async {
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
      if (isOn) {
        await _startAdvertisingSequence();
      } else {
        await BlePeripheral.stopAdvertising();
      }
    });

    BlePeripheral.setWriteRequestCallback(
      (String deviceId, String characteristicId, int offset, Uint8List? value) {
        if (characteristicId.toLowerCase() == myCharacteristicUuid.toLowerCase() && value != null) {
          try {
            String receivedMessage = utf8.decode(value);
            print("Received Message from $deviceId: $receivedMessage");
            onPeripheralMessageReceived?.call(receivedMessage, deviceId);
          } catch (e) {
            print("Failed to decode written data: $e");
          }
          return null; // Acknowledge standard write with no error code
        }
        return null;
      },
    );

    await _startAdvertisingSequence();
    
  } catch (e) {
    print("Error Initializing, $e");
  }
}

Future<void> _startAdvertisingSequence() async {
  try {
    await BlePeripheral.clearServices();
    await BlePeripheral.addService(
      BleService(
        uuid: myServiceUuid,
        primary: true,
        characteristics: [
          BleCharacteristic(
            uuid: myCharacteristicUuid,
            properties: [
              CharacteristicProperties.write.index,
              CharacteristicProperties.writeWithoutResponse.index,
            ],
            value: null,
            permissions: [
              AttributePermissions.writeable.index
            ],
          ),
        ],
      ),
    );

    await BlePeripheral.startAdvertising(
      services: [myServiceUuid],
      localName: "MyBeacon",
    );
    print("Advertising open mailbox...");
  } catch (e) {
    print("Broadcasting deferred: $e");
  }
}