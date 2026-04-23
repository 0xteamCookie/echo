import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import '../models/rescuer_session.dart';

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