// Hold parsed JWT session data for logged-in rescuer.
class RescuerSession {
  final String name;

  final String role;

  // Assigned zone centre latitude.
  final double lat;

  // Assigned zone centre longitude.
  final double lng;

  // Assigned zone radius in metres.
  final double radiusM;

  const RescuerSession({
    required this.name,
    required this.role,
    required this.lat,
    required this.lng,
    required this.radiusM,
  });

  // Build from the raw JWT payload map.
  factory RescuerSession.fromJwtPayload(Map<dynamic, dynamic> payload) {
    return RescuerSession(
      name: (payload['name'] ?? 'Unknown').toString(),
      role: (payload['role'] ?? 'rescuer').toString(),
      lat: _toDouble(payload['lat']),
      lng: _toDouble(payload['lng']),
      radiusM: _toDouble(payload['radius_m'], fallback: 500),
    );
  }

  factory RescuerSession.fromStorageMap(Map<String, String> map) {
    return RescuerSession(
      name: map['name'] ?? 'Unknown',
      role: map['role'] ?? 'rescuer',
      lat: double.tryParse(map['lat'] ?? '') ?? 0,
      lng: double.tryParse(map['lng'] ?? '') ?? 0,
      radiusM: double.tryParse(map['radius_m'] ?? '') ?? 500,
    );
  }

  Map<String, String> toStorageMap() => {
    'name': name,
    'role': role,
    'lat': lat.toString(),
    'lng': lng.toString(),
    'radius_m': radiusM.toString(),
  };

  static double _toDouble(dynamic v, {double fallback = 0}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  @override
  String toString() =>
      'RescuerSession(name: $name, role: $role, lat: $lat, lng: $lng, radius: ${radiusM}m)';
}
