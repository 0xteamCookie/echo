import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:ble_peripheral/src/ble_peripheral_interface.dart';
import 'package:permission_handler/permission_handler.dart';

const String myServiceUuid = "12345678-1234-5678-1234-56789abcdef0";
const String myCharacteristicUuid = "12345678-1234-5678-1234-56789abcdef1";

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
    print("BLE INITIALIZED");

    // Listen to OS Bluetooth State changes
    BlePeripheral.setBleStateChangeCallback((bool isOn) async {
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
      if (isOn) {
        await _startAdvertisingSequence();
      } else {
        await BlePeripheral.stopAdvertising();
      }
    });

    BlePeripheral.setAdvertisingStatusUpdateCallback((bool advertising, String? error) {
      print("AdvertisingStatus: $advertising Error: $error");
    });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback(
      (deviceId, characteristicId, isSubscribed) {
        print("Device $deviceId subscription to $characteristicId changed to: $isSubscribed");
    } as CharacteristicSubscriptionChangeCallback);

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
              CharacteristicProperties.read.index,
              CharacteristicProperties.notify.index 
            ],
            value: null,
            permissions: [
              AttributePermissions.readable.index,
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
    print("Advertising requested...");
    // Only start heartbeat if you want it running blindly, otherwise let subscriptions trigger it
    // startHeartbeat(); 
  } catch (e) {
    print("Broadcasting deferred: $e");
  }
}