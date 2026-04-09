<<<<<<< HEAD
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';

=======
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async'; 
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:ble_peripheral/src/ble_peripheral_interface.dart';
import 'package:permission_handler/permission_handler.dart';

const String myServiceUuid = "12345678-1234-5678-1234-56789abcdef0";
const String myCharacteristicUuid = "12345678-1234-5678-1234-56789abcdef1";

Timer? heartbeatTimer;
>>>>>>> e402c24d7948dc117fba4becefdb07b2480b3474

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
<<<<<<< HEAD
    print("BLE INTIALIZIED");

    BlePeripheral.setBleStateChangeCallback((bool isOn){
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
    });
  } catch (e) {
    print("Error Intializing , $e");
  }
=======
    print("BLE INITIALIZED");

    // Listen to OS Bluetooth State changes
    BlePeripheral.setBleStateChangeCallback((bool isOn) async {
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
      if (isOn) {
        await _startAdvertisingSequence();
      } else {
        stopHeartbeat();
        await BlePeripheral.stopAdvertising();
      }
    });

    BlePeripheral.setAdvertisingStatusUpdateCallback((bool advertising, String? error) {
      print("AdvertisingStatus: $advertising Error: $error");
    });

    BlePeripheral.setCharacteristicSubscriptionChangeCallback(
      (deviceId, characteristicId, isSubscribed) {
        print("Device $deviceId subscription to $characteristicId changed to: $isSubscribed");
        if (isSubscribed) {
          startHeartbeat();
        } else {
          stopHeartbeat();
        }
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

Future<void> sendMessageToCentral(String message) async {
  try {
    List<int> bytes = utf8.encode(message); 
    Uint8List byteData = Uint8List.fromList(bytes);
    
    await BlePeripheral.updateCharacteristic(
      characteristicId: myCharacteristicUuid,
      value: byteData,
    );
    print("Message sent: $message");
  } catch (e) {
    print("Failed to send message: $e");
  }
}

void startHeartbeat([String customPrefix = "Heartbeat"]) {
  heartbeatTimer?.cancel();
  
  if (customPrefix.trim().isEmpty) {
    customPrefix = "Heartbeat";
  }

  heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    String timeStr = DateTime.now().toIso8601String().substring(11, 19);
    sendMessageToCentral("$customPrefix: $timeStr");
  });
  print("Heartbeat started with prefix: $customPrefix.");
}

void stopHeartbeat() {
  heartbeatTimer?.cancel();
  print("Heartbeat stopped.");
>>>>>>> e402c24d7948dc117fba4becefdb07b2480b3474
}