import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../models/rescuer_session.dart';

class AuthService {
  static const storage = FlutterSecureStorage();

  static const String publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsIfNeaCu+MvQqkh6RU7t
XWu7z2kFhTaqOLekeHP/NPf1wB7nKUTPxbkDDzoXPRAgjSNMy4W4cJSRql67dYXy
gdGhV3pHIWHO8+Tag84KLSNW4JhKGAiXrx5KTf9km2Y83AwkAOFwY/mxfFZBDj7i
S4LQBRhUSczBHpm9iAXksfDWT5kS1tOBllVNQFeiZQJoymWxhJaQsIVGrMDjnVe0
7lWjuAK58fojAJs8iWwemJLubnV87nM50l/jhCy9bGYY+f4womBmgJnaOBMHjVZV
PzagBRKe4BAjgLeqC2xW4zrRkz8s3wkQh5GHvM7FPv6ewguj1AgSFskj/ioASFg0
SQIDAQAB
-----END PUBLIC KEY-----
''';

  /// Verifies the token using ES256 algorithms and saves the session if valid.
  static Future<bool> verifyAndSaveToken(String token) async {
    try {
      // Use ECPublicKey for ES256
      final jwt = JWT.verify(token, RSAPublicKey(publicKeyPem));

      print("✅ VALID USER");
      print("Payload: ${jwt.payload}");

      // Persist the raw JWT so subsequent authenticated backend calls
      // (e.g. POST /api/rescuer/heartbeat, /api/push/register) can send it
      // as a Bearer token without re-scanning the QR.
      await storage.write(key: "rescuer_token", value: token);

      await _saveSession(jwt.payload);
      return true;
    } on JWTExpiredException {
      print("❌ TOKEN EXPIRED");
      return false;
    } catch (e) {
      print("❌ INVALID QR / TOKEN: $e");
      return false;
    }
  }

  /// Returns the raw rescuer JWT (if previously scanned + still in secure
  /// storage) so callers can send `Authorization: Bearer <token>` to the
  /// backend. Does not validate expiry — backend will reject expired tokens.
  static Future<String?> getRawToken() async {
    return storage.read(key: "rescuer_token");
  }

  /// Saves the parsed payload to secure storage and populates AppState.
  static Future<void> _saveSession(dynamic payload) async {
    if (payload is Map) {
      // Store user_id
      if (payload['sub'] != null) {
        await storage.write(key: "user_id", value: payload['sub'].toString());
      }

      // Build the full rescuer session from the JWT payload
      final session = RescuerSession.fromJwtPayload(
        Map<dynamic, dynamic>.from(payload),
      );

      // Persist every field to secure storage
      final storageMap = session.toStorageMap();
      for (final entry in storageMap.entries) {
        await storage.write(key: entry.key, value: entry.value);
      }

      // Populate global state
      AppState().rescuerSession.value = session;

      // Any non-"user" role is treated as a rescuer for the nav layout
      AppState().role.value = UserRole.rescuer;

      print("💾 Session saved: $session");
    }
  }

  /// Checks if a valid session exists on app start and restores it.
  static Future<bool> isLoggedIn() async {
    final id = await storage.read(key: "user_id");

    if (id != null) {
      // Restore the full session from individual secure-storage keys
      final allValues = await storage.readAll();
      final session = RescuerSession.fromStorageMap(
        Map<String, String>.from(allValues),
      );

      AppState().rescuerSession.value = session;
      AppState().role.value = UserRole.rescuer;
    }

    return id != null;
  }

  /// Logs out the user by clearing storage and session state.
  static Future<void> logout() async {
    await storage.deleteAll();
    AppState().rescuerSession.value = null;
    AppState().role.value = UserRole.user;
    print("🗑️ Session cleared");
  }
}
