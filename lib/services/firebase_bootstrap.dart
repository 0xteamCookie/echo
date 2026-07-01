library;

import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';

/// Backend base URL (same source as sync.dart / rescuer_sync.dart).
const String _apiBaseUrl = String.fromEnvironment(
  'BEACON_API_BASE_URL',
  defaultValue: 'https://echo-back.getmyroom.in',
);

/// reCAPTCHA/Play Integrity is auto-selected; this debug toggle lets local
/// builds use the App Check debug provider. Pass --dart-define=APP_CHECK_DEBUG=true.
const bool _appCheckDebug = bool.fromEnvironment(
  'APP_CHECK_DEBUG',
  defaultValue: false,
);

/// Top-level background handler — required by firebase_messaging to be a
/// top-level/static function. We don't need to render anything here for data
/// messages; the OS shows notification-type messages automatically.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal: ensure Firebase is up in the background isolate.
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM] background message: ${message.messageId}');
}

/// Initializes Firebase and the FCM + App Check integrations.
///
/// Safe to call unconditionally at startup: if no Firebase config is present
/// (no google-services.json wired into the build), [Firebase.initializeApp]
/// throws and we swallow it, leaving the app to run exactly as before.
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  /// Call once early in main(). Returns true if Firebase came up.
  static Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      debugPrint('[FirebaseBootstrap] Firebase not configured, skipping: $e');
      return false;
    }

    await _initAppCheck();
    await _initMessaging();
    return true;
  }

  /// App Check: produces the attestation token that sync.dart attaches to
  /// ingest as `X-Firebase-AppCheck`.
  static Future<void> _initAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: _appCheckDebug
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
      );
      debugPrint('[AppCheck] activated (debug=$_appCheckDebug)');
    } catch (e) {
      debugPrint('[AppCheck] activation failed: $e');
    }
  }

  /// Returns a fresh App Check token, or null if unavailable. Used by the
  /// ingest HTTP client. Never throws.
  static Future<String?> getAppCheckToken() async {
    if (!_initialized) return null;
    try {
      return await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      debugPrint('[AppCheck] getToken failed: $e');
      return null;
    }
  }

  static Future<void> _initMessaging() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // Foreground messages — surface to logs (UI rendering can hook here later).
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[FCM] foreground: ${message.notification?.title} / ${message.data}',
        );
      });

      // Register the current token, and re-register whenever it rotates.
      final token = await messaging.getToken();
      if (token != null) {
        await registerFcmToken(token);
      }
      messaging.onTokenRefresh.listen((t) {
        unawaited(registerFcmToken(t));
      });
    } catch (e) {
      debugPrint('[FCM] init failed: $e');
    }
  }

  /// POST the FCM token to the backend so this rescuer receives agency alerts.
  /// Requires a logged-in rescuer (RS256 provisioning JWT). No-op otherwise.
  static Future<void> registerFcmToken(String fcmToken) async {
    try {
      final jwt = await AuthService.getRawToken();
      if (jwt == null || jwt.isEmpty) {
        debugPrint('[FCM] no rescuer token yet; deferring registration');
        return;
      }
      final res = await http
          .post(
            Uri.parse('$_apiBaseUrl/api/push/register'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode({'fcmToken': fcmToken}),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 204 || res.statusCode == 200) {
        debugPrint('[FCM] token registered');
      } else {
        debugPrint('[FCM] register non-2xx: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[FCM] register failed: $e');
    }
  }

  /// Re-register after a rescuer logs in (token may have been fetched before
  /// the JWT existed). Call this from the auth/login success path.
  static Future<void> registerCurrentToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await registerFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] registerCurrentToken failed: $e');
    }
  }
}

void unawaited(Future<void> future) {
  future.catchError((Object e) => debugPrint('unawaited error: $e'));
}
