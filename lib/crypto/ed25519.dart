/// P2-11 — per-device Ed25519 identity + packet signing.
///
/// On first use we generate a long-lived keypair, stash the 32-byte seed in
/// `flutter_secure_storage` (OS keystore-backed), and publish the public key
/// through the mesh inside every v3 packet. Signatures cover every packet
/// field EXCEPT `hopCount` (see `packet_codec.dart`) so relays can safely
/// bump the TTL without invalidating the signature.
///
/// NOTE: this is intentionally a flat "accept any sender-supplied public key
/// and record it" trust model for now. The long-term plan (see
/// docs/05-ACTION-PLAN.md P2-11) is to require a trusted-issuer JWT claim
/// that binds `deviceId → publicKey` before a packet is accepted. See the
/// TODO in `packet_codec.dart`.
library;

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPrivKeyKey = 'ed25519_private_key_b64';
const _kPubKeyKey = 'ed25519_public_key_b64';

const _storage = FlutterSecureStorage(
  // iOS: use kSecAttrAccessibleAfterFirstUnlock so the key remains readable
  // when the app is woken in the background by a CoreBluetooth event while
  // the device is locked (but has been unlocked at least once since boot).
  // The default kSecAttrAccessibleWhenUnlocked blocks all background relay
  // signing on a locked iOS device.
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
final _ed25519 = Ed25519();

String? _cachedPrivateSeedB64;
String? _cachedPublicKeyB64;

/// Generate-or-load the device's long-lived Ed25519 identity. Idempotent.
Future<void> ensureKeypair() async {
  final existingPriv = await _storage.read(key: _kPrivKeyKey);
  final existingPub = await _storage.read(key: _kPubKeyKey);
  if (existingPriv != null &&
      existingPriv.isNotEmpty &&
      existingPub != null &&
      existingPub.isNotEmpty) {
    _cachedPrivateSeedB64 = existingPriv;
    _cachedPublicKeyB64 = existingPub;
    return;
  }

  final keyPair = await _ed25519.newKeyPair();
  final seed = await keyPair.extractPrivateKeyBytes(); // 32-byte seed
  final pub = await keyPair.extractPublicKey();

  final privB64 = base64.encode(seed);
  final pubB64 = base64.encode(pub.bytes);

  await _storage.write(key: _kPrivKeyKey, value: privB64);
  await _storage.write(key: _kPubKeyKey, value: pubB64);

  _cachedPrivateSeedB64 = privB64;
  _cachedPublicKeyB64 = pubB64;
}

/// Returns the device's base64-encoded Ed25519 public key, or empty string
/// if [ensureKeypair] hasn't run yet (callers treat empty as "skip signing").
Future<String> getPublicKeyB64() async {
  if (_cachedPublicKeyB64 != null) return _cachedPublicKeyB64!;
  final pub = await _storage.read(key: _kPubKeyKey);
  _cachedPublicKeyB64 = pub ?? '';
  return _cachedPublicKeyB64!;
}

Future<SimpleKeyPair> _loadKeyPair() async {
  _cachedPrivateSeedB64 ??= await _storage.read(key: _kPrivKeyKey);
  if (_cachedPrivateSeedB64 == null || _cachedPrivateSeedB64!.isEmpty) {
    throw StateError(
      'ed25519 keypair not initialised — call ensureKeypair() first',
    );
  }
  final seedBytes = base64.decode(_cachedPrivateSeedB64!);
  return _ed25519.newKeyPairFromSeed(seedBytes);
}

/// Sign [packetString] with the device's private key. Returns base64.
///
/// [packetString] MUST be the canonical bytes a verifier will reconstruct —
/// i.e. it must NOT include the trailing signature field itself.
Future<String> signPacket(String packetString) async {
  final kp = await _loadKeyPair();
  final sig = await _ed25519.sign(utf8.encode(packetString), keyPair: kp);
  return base64.encode(sig.bytes);
}

/// Verify a signature produced by [signPacket]. Returns `false` (never
/// throws) on any decoding/verification error so callers can just drop the
/// packet.
Future<bool> verifyPacket(
  String packetString,
  String publicKeyB64,
  String signatureB64,
) async {
  try {
    final pubBytes = base64.decode(publicKeyB64);
    if (pubBytes.length != 32) return false;
    final sigBytes = base64.decode(signatureB64);
    if (sigBytes.length != 64) return false;

    final pub = SimplePublicKey(pubBytes, type: KeyPairType.ed25519);
    final sig = Signature(sigBytes, publicKey: pub);
    return await _ed25519.verify(utf8.encode(packetString), signature: sig);
  } catch (_) {
    return false;
  }
}

/// Test/diagnostic helper. Exposes only presence, never the seed.
Future<bool> hasKeypair() async {
  final priv = await _storage.read(key: _kPrivKeyKey);
  return priv != null && priv.isNotEmpty;
}
