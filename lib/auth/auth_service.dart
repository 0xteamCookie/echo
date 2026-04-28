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

  static Future<String?> getRawToken() async {
    return storage.read(key: "rescuer_token");
  }

  static Future<void> _saveSession(dynamic payload) async {
    if (payload is Map) {
      if (payload['sub'] != null) {
        await storage.write(key: "user_id", value: payload['sub'].toString());
      }

      final session = RescuerSession.fromJwtPayload(
        Map<dynamic, dynamic>.from(payload),
      );

      final storageMap = session.toStorageMap();
      for (final entry in storageMap.entries) {
        await storage.write(key: entry.key, value: entry.value);
      }

      AppState().rescuerSession.value = session;

      AppState().role.value = UserRole.rescuer;

      print("💾 Session saved: $session");
    }
  }

  static Future<bool> isLoggedIn() async {
    final id = await storage.read(key: "user_id");

    if (id != null) {
      final allValues = await storage.readAll();
      final session = RescuerSession.fromStorageMap(
        Map<String, String>.from(allValues),
      );

      AppState().rescuerSession.value = session;
      AppState().role.value = UserRole.rescuer;
    }

    return id != null;
  }

  static Future<void> logout() async {
    await storage.deleteAll();
    AppState().rescuerSession.value = null;
    AppState().role.value = UserRole.user;
    print("🗑️ Session cleared");
  }
}
