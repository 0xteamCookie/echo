import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';


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
    print("BLE INTIALIZIED");

    BlePeripheral.setBleStateChangeCallback((bool isOn){
      print("Bluetooth State Changed: ${isOn ? "ON" : "OFF"}");
    });
  } catch (e) {
    print("Error Intializing , $e");
  }
}