class BleCollisionManager {
  static final Map<String, DateTime> _backoffList = {};

  // If a device fails to connect, put it in a timeout box
  static void recordFailure(String deviceId) {
    _backoffList[deviceId] = DateTime.now();
  }

  // Check if a device is currently in timeout
  static bool shouldSkip(String deviceId) {
    if (!_backoffList.containsKey(deviceId)) return false;
    
    final lastFailure = _backoffList[deviceId]!;
    if (DateTime.now().difference(lastFailure).inSeconds < 10) {
      return true;
    }
    
    _backoffList.remove(deviceId);
    return false;
  }
}