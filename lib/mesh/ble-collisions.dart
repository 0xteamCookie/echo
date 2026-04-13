class BleCollisionManager {
  static final Map<String, DateTime> _backoffList = {};

  static void recordFailure(String deviceId) {
    _backoffList[deviceId] = DateTime.now();
  }

  static bool shouldSkip(String deviceId) {
    if (!_backoffList.containsKey(deviceId)) return false;
    
    final lastFailure = _backoffList[deviceId]!;
    if (DateTime.now().difference(lastFailure).inSeconds < 45) {
      return true;
    }
    
    _backoffList.remove(deviceId);
    return false;
  }
}