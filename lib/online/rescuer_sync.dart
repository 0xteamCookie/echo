import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../main.dart';

// Backend base URL compiled from dart-defines
const String _apiBaseUrl = String.fromEnvironment(
  'BEACON_API_BASE_URL',
  defaultValue: 'https://echo-back.getmyroom.in',
);

const Duration _heartbeatInterval = Duration(minutes: 2);

Timer? _heartbeatTimer;

void startRescuerHeartbeat() {
  if (_heartbeatTimer != null) return;
  if (AppState().role.value != UserRole.rescuer) return;

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
