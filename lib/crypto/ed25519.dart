library;

import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _kPrivKeyKey = 'ed25519_private_key_b64';
const _kPubKeyKey = 'ed25519_public_key_b64';

const _storage = FlutterSecureStorage(
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
final _ed25519 = Ed25519();

String? _cachedPrivateSeedB64;
String? _cachedPublicKeyB64;

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
  final seed = await keyPair.extractPrivateKeyBytes();
  final pub = await keyPair.extractPublicKey();

  final privB64 = base64.encode(seed);
  final pubB64 = base64.encode(pub.bytes);

  await _storage.write(key: _kPrivKeyKey, value: privB64);
  await _storage.write(key: _kPubKeyKey, value: pubB64);

  _cachedPrivateSeedB64 = privB64;
  _cachedPublicKeyB64 = pubB64;
}

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

Future<String> signPacket(String packetString) async {
  final kp = await _loadKeyPair();
  final sig = await _ed25519.sign(utf8.encode(packetString), keyPair: kp);
  return base64.encode(sig.bytes);
}

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

Future<bool> hasKeypair() async {
  final priv = await _storage.read(key: _kPrivKeyKey);
  return priv != null && priv.isNotEmpty;
}
