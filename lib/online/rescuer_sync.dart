import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../main.dart';

/// Backend base URL compiled in from dart-defines (same value as sync.dart).
const String _apiBaseUrl = String.fromEnvironment(
  'BEACON_API_BASE_URL',
  defaultValue: 'https://echo-back.getmyroom.in',
);

/// How often we push an on-duty heartbeat while the rescuer is logged in.
const Duration _heartbeatInterval = Duration(minutes: 2);

Timer? _heartbeatTimer;

/// Start the rescuer heartbeat loop. Safe to call multiple times — it is a
/// no-op if the timer is already running or no rescuer is logged in.
///
/// Each tick sends the device's current GPS fix to
/// `POST /api/rescuer/heartbeat` so the admin dispatch engine can see this
/// rescuer as on-duty and route AI recommendations to them.
void startRescuerHeartbeat() {
  if (_heartbeatTimer != null) return;
  if (AppState().role.value != UserRole.rescuer) return;

  // Fire one immediately so the rescuer shows up in dispatch without waiting.
  unawaited(_sendHeartbeat());

  _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
    if (AppState().role.value != UserRole.rescuer) {
      stopRescuerHeartbeat();
      return;
    }
    unawaited(_sendHeartbeat());
  });
}

void stopRescuerHeartbeat() {
  _heartbeatTimer?.cancel();
  _heartbeatTimer = null;
}

Future<void> _sendHeartbeat() async {
  try {
    final token = await AuthService.getRawToken();
    if (token == null || token.isEmpty) return;

    // Try to get a real GPS fix; fall back to the JWT-assigned zone centre so
    // the heartbeat is still useful even without live location permission.
    double? lat;
    double? lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        lat = pos.latitude;
        lng = pos.longitude;
      }
    } catch (_) {
      /* fall back to assigned zone */
    }

    if (lat == null || lng == null) {
      final session = AppState().rescuerSession.value;
      if (session == null) return;
      lat = session.lat;
      lng = session.lng;
    }

    final body = <String, dynamic>{
      'currentLocation': {'lat': lat, 'lng': lng},
      'onDuty': true,
    };

    final res = await http
        .post(
          Uri.parse('$_apiBaseUrl/api/rescuer/heartbeat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 204 && res.statusCode != 200) {
      debugPrint('heartbeat non-2xx: ${res.statusCode} ${res.body}');
    }
  } catch (e) {
    debugPrint('heartbeat failed: $e');
  }
}

/// Fire a one-shot "off duty" heartbeat before logout so the rescuer stops
/// showing up in dispatch queries immediately.
Future<void> sendOffDutyHeartbeat() async {
  try {
    final token = await AuthService.getRawToken();
    if (token == null || token.isEmpty) return;
    final session = AppState().rescuerSession.value;
    if (session == null) return;

    await http
        .post(
          Uri.parse('$_apiBaseUrl/api/rescuer/heartbeat'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'currentLocation': {'lat': session.lat, 'lng': session.lng},
            'onDuty': false,
          }),
        )
        .timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('off-duty heartbeat failed: $e');
  }
}
