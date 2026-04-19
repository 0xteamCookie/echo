import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const storage = FlutterSecureStorage();

  // Replace this with your actual ES256 Public Key
  static const String publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
YOUR_ES256_PUBLIC_KEY_HERE
-----END PUBLIC KEY-----
''';

  /// Verifies the token using ES256 algorithms and saves the session if valid.
  static Future<bool> verifyAndSaveToken(String token) async {
    try {
      // Use ECPublicKey for ES256
      final jwt = JWT.verify(
        token,
        ECPublicKey(publicKeyPem),
      );

      print("✅ VALID USER");
      print("Payload: ${jwt.payload}");

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

  /// Saves the parsed payload to secure storage
  static Future<void> _saveSession(dynamic payload) async {
    if (payload is Map) {
      // Convert values to string for storage
      if (payload['id'] != null) {
        await storage.write(key: "user_id", value: payload['id'].toString());
      }
      if (payload['role'] != null) {
        await storage.write(key: "role", value: payload['role'].toString());
      }
      print("💾 Session saved");
    }
  }

  /// Checks if a valid session exists on app start
  static Future<bool> isLoggedIn() async {
    final id = await storage.read(key: "user_id");
    return id != null;
  }

  /// Logs out the user by clearing storage
  static Future<void> logout() async {
    await storage.deleteAll();
    print("🗑️ Session cleared");
  }
}