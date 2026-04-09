import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdManager {
  static const String _deviceIdKey = 'ble_mesh_device_id';

  static Future<String> getDeviceId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      // Generate a v4 (random) UUID
      const Uuid uuid = Uuid();
      deviceId = uuid.v4();
      
      // Save it to local storage
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    return deviceId;
  }
}