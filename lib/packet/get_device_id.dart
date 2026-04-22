import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';

class DeviceIdManager {
  static const String _deviceIdKey = kPrefDeviceId;
  static String? _cachedDeviceId;

  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    String? deviceId = prefs.getString(_deviceIdKey);
    
    if (deviceId == null) {
      // Generate a v4 (random) UUID
      const Uuid uuid = Uuid();
      deviceId = uuid.v4();
      
      // Save it to local storage
      await prefs.setString(_deviceIdKey, deviceId);
    }
    
    _cachedDeviceId = deviceId;
    return deviceId;
  }
}
