import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';

class AuthService {
  static const storage = FlutterSecureStorage();

  static const String publicKeyPem = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAncV95GpNZ549VoX/J4TL
mdyOaZVGeS8RZA5G4ANBnL394M6Vow0+Z8yBwTEcfTuZDqBmDHVxQ/Lj8SqM7iKe
lHiXLBrWQp4/2sUNYP4z9qpMiuQImjU1F0xdMb7/UVnxhlrYw0GuYgt2j8qplnKO
TTKsMDS6DVGfSY6DRR3UZ4CnkCQQ/IieOsRFF94bfplviB8WOrIpcC+6Gh4lnCdP
aShPCIM4+UY5kHcjVrAp2C2p3samiHBOppYb0CAfE1ZG5AJluoKjoBfqVwvDYocF
Kba/x7f/qXLePcGA54NvTDIopv+LdUgFUAbmPWFRHwpntHsUlJJk3rJiKVPB1Ifb
9QIDAQAB
-----END PUBLIC KEY-----
''';

  /// Verifies the token using ES256 algorithms and saves the session if valid.
  static Future<bool> verifyAndSaveToken(String token) async {
    try {
      // Use ECPublicKey for ES256
      final jwt = JWT.verify(
        token,
        RSAPublicKey(publicKeyPem),
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
      if (payload['sub'] != null) {
        await storage.write(key: "user_id", value: payload['sub'].toString());
      }
      
      if (payload['role'] != null) {
        await storage.write(key: "role", value: payload['role'].toString());
        
        if (payload['role'].toString().toLowerCase() == 'rescuer') {
          AppState().role.value = UserRole.rescuer;
        } else {
          AppState().role.value = UserRole.user;
        }
      }

      if (payload['name'] != null) {
        await storage.write(key: "name", value: payload['name'].toString());
      }
      if (payload['org'] != null) {
        await storage.write(key: "org", value: payload['org'].toString());
      }
      
      print("💾 Session saved with user ID: ${payload['sub']}");
    }
  }

  /// Checks if a valid session exists on app start
  static Future<bool> isLoggedIn() async {
    final id = await storage.read(key: "user_id");
    
    // Also restore the role state if session exists
    if (id != null) {
      final role = await storage.read(key: "role");
      if (role?.toLowerCase() == 'rescuer') {
        AppState().role.value = UserRole.rescuer;
      }
    }
    
    return id != null;
  }

  /// Logs out the user by clearing storage
  static Future<void> logout() async {
    await storage.deleteAll();
    print("🗑️ Session cleared");
  }
}