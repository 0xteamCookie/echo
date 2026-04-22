/// Beacon BLE mesh wire format.
///
/// v3 packet (`||`-delimited, 13 fields including version tag) — P2-11 adds a
/// per-device Ed25519 signature and the sender's public key so receivers can
/// verify authenticity:
///
/// ```
/// v3||<messageId>||<b64(message)>||<deviceId>||<b64(senderName)>||<expiresAt>||<b64(location)>||<time>||<hopCount>||<isSos>||<b64(senderPublicKey)>||<b64(triage)>||<b64(signature)>
/// ```
///
/// The signed canonical string EXCLUDES `hopCount` and the trailing
/// `<signature>` field, so relays can bump the TTL without invalidating the
/// sender's signature.
///
/// v2 packet (prior, unsigned):
///
/// ```
/// v2||<messageId>||<b64(message)>||<deviceId>||<b64(senderName)>||<expiresAt>||<b64(location)>||<time>||<hopCount>||<isSos>
/// ```
///
/// Text-bearing fields are base64-encoded so arbitrary user input containing
/// `||` can never corrupt the frame (P1-1). v1 (legacy) is still accepted on
/// receive for backward-compat only; all outgoing packets MUST use v3.
library;

import 'dart:convert';

/// Drop any packet that has been relayed more than this many times.
const int maxHops = 8;

const String _v2Tag = 'v2';
const String _v3Tag = 'v3';
const String _delim = '||';

String _b64Encode(String? value) {
  final s = value ?? '';
  return base64.encode(utf8.encode(s));
}

String _b64Decode(String encoded) {
  try {
    return utf8.decode(base64.decode(encoded));
  } catch (_) {
    // Fall back to raw string on decode error so v1/garbled frames still yield
    // *something* for the UI rather than blowing up the receive pipeline.
    return encoded;
  }
}

/// Build the canonical "what we sign" string for a v3 packet. The hop count
/// is intentionally omitted so relays can bump the TTL without breaking the
/// sender's signature. The trailing `<signature>` trailer is also omitted by
/// definition. Field order MUST stay stable between sender and verifier.
String canonicalSignedString(Map<String, dynamic> packet) {
  final messageId = (packet['messageId'] ?? '').toString();
  final message = (packet['message'] ?? '').toString();
  final deviceId = (packet['deviceId'] ?? '').toString();
  final senderName = (packet['senderName'] ?? '').toString();
  final expiresAt = (packet['expiresAt'] ?? '').toString();
  final location = (packet['location'] ?? '').toString();
  final time = (packet['time'] ?? '').toString();
  final isSos = (packet['isSos'] is int)
      ? packet['isSos'] as int
      : int.tryParse((packet['isSos'] ?? '0').toString()) ?? 0;
  final pubKey = (packet['deviceSenderPublicKey'] ?? '').toString();
  final triage = (packet['triage'] ?? '').toString();

  return [
    _v3Tag,
    messageId,
    _b64Encode(message),
    deviceId,
    _b64Encode(senderName),
    expiresAt,
    _b64Encode(location),
    time,
    '$isSos',
    pubKey,
    _b64Encode(triage),
  ].join(_delim);
}

/// Serialize a packet map to the v3 wire format. [signatureB64] is the base64
/// Ed25519 signature over [canonicalSignedString] of the same packet map.
String encodePacketV3(Map<String, dynamic> packet, String signatureB64) {
  final messageId = (packet['messageId'] ?? '').toString();
  final message = (packet['message'] ?? '').toString();
  final deviceId = (packet['deviceId'] ?? '').toString();
  final senderName = (packet['senderName'] ?? '').toString();
  final expiresAt = (packet['expiresAt'] ?? '').toString();
  final location = (packet['location'] ?? '').toString();
  final time = (packet['time'] ?? '').toString();
  final hopCount = (packet['hopCount'] is int)
      ? packet['hopCount'] as int
      : int.tryParse((packet['hopCount'] ?? '0').toString()) ?? 0;
  final isSos = (packet['isSos'] is int)
      ? packet['isSos'] as int
      : int.tryParse((packet['isSos'] ?? '0').toString()) ?? 0;
  final pubKey = (packet['deviceSenderPublicKey'] ?? '').toString();
  final triage = (packet['triage'] ?? '').toString();

  return [
    _v3Tag,
    messageId,
    _b64Encode(message),
    deviceId,
    _b64Encode(senderName),
    expiresAt,
    _b64Encode(location),
    time,
    '$hopCount',
    '$isSos',
    pubKey,
    _b64Encode(triage),
    signatureB64,
  ].join(_delim);
}

/// Serialize a packet map to the v2 wire format. Kept for tests and
/// back-compat (e.g. peers that don't yet support v3).
String encodePacketV2(Map<String, dynamic> packet) {
  final messageId = (packet['messageId'] ?? '').toString();
  final message = (packet['message'] ?? '').toString();
  final deviceId = (packet['deviceId'] ?? '').toString();
  final senderName = (packet['senderName'] ?? '').toString();
  final expiresAt = (packet['expiresAt'] ?? '').toString();
  final location = (packet['location'] ?? '').toString();
  final time = (packet['time'] ?? '').toString();
  final hopCount = (packet['hopCount'] is int)
      ? packet['hopCount'] as int
      : int.tryParse((packet['hopCount'] ?? '0').toString()) ?? 0;
  final isSos = (packet['isSos'] is int)
      ? packet['isSos'] as int
      : int.tryParse((packet['isSos'] ?? '0').toString()) ?? 0;

  return [
    _v2Tag,
    messageId,
    _b64Encode(message),
    deviceId,
    _b64Encode(senderName),
    expiresAt,
    _b64Encode(location),
    time,
    '$hopCount',
    '$isSos',
  ].join(_delim);
}

/// Decode a v3 (preferred) / v2 / v1 (legacy) packet. Returns `null` if the
/// frame is an ACK, malformed, or unknown.
///
/// v3 packets populate `deviceSenderPublicKey`, `signature` and `triage`
/// keys on the returned map. Signature verification is left to the caller
/// (see `receive-message.dart`). v1/v2 packets omit these fields; callers
/// should treat them as `insecure` (soft-migration tolerance per P2-11).
///
/// TODO(P2-11 — trusted issuer): once a rescuer/admin issues a JWT that
/// binds `deviceId → publicKey`, reject v3 packets whose
/// `deviceSenderPublicKey` doesn't match the bound key for `deviceId`. For
/// now we accept any sender-declared public key and only enforce that the
/// signature verifies against it.
Map<String, dynamic>? decodePacket(String raw) {
  if (raw.startsWith('ACK$_delim')) {
    // ACKs are handled by the caller; not a data packet.
    return null;
  }

  final parts = raw.split(_delim);
  if (parts.isEmpty) return null;

  if (parts.first == _v3Tag) {
    if (parts.length != 13) return null;
    return {
      'messageId': parts[1],
      'message': _b64Decode(parts[2]),
      'deviceId': parts[3],
      'senderName': _b64Decode(parts[4]),
      'expiresAt': parts[5],
      'location': _b64Decode(parts[6]),
      'time': parts[7],
      'hopCount': int.tryParse(parts[8]) ?? 0,
      'isSos': int.tryParse(parts[9]) ?? 0,
      'deviceSenderPublicKey': parts[10],
      'triage': _b64Decode(parts[11]),
      'signature': parts[12],
      'protocolVersion': 3,
    };
  }

  if (parts.first == _v2Tag) {
    if (parts.length != 10) return null;
    return {
      'messageId': parts[1],
      'message': _b64Decode(parts[2]),
      'deviceId': parts[3],
      'senderName': _b64Decode(parts[4]),
      'expiresAt': parts[5],
      'location': _b64Decode(parts[6]),
      'time': parts[7],
      'hopCount': int.tryParse(parts[8]) ?? 0,
      'isSos': int.tryParse(parts[9]) ?? 0,
      'protocolVersion': 2,
    };
  }

  // Legacy v1: 7 parts, plaintext fields, no time, no hopCount.
  if (parts.length == 7) {
    return {
      'messageId': parts[0],
      'message': parts[1],
      'deviceId': parts[2],
      'senderName': parts[3],
      'expiresAt': parts[4],
      'location': parts[5],
      'time': '', // will be derived from expiresAt - 24h at insertMessage time
      'hopCount': 0,
      'isSos': int.tryParse(parts[6]) ?? 0,
      'protocolVersion': 1,
    };
  }

  return null;
}

/// Build an ACK control frame (plaintext).
///
/// v2 shape: `ACK||<messageId>||<relayerId>||<status>` where `status` is one
/// of `ack` / `enroute` / `resolved` (rescuer report flow).
/// Legacy 3-field `ACK||<messageId>||<relayerId>` frames are still accepted
/// by [decodeAck] so older peers stay compatible.
String encodeAck(
  String messageId,
  String relayerId, {
  String status = 'ack',
}) =>
    'ACK$_delim$messageId$_delim$relayerId$_delim$status';

/// Parse an ACK control frame. Returns `null` if [raw] is not an ACK or is
/// malformed. Accepts both the v2 (4-field) and legacy (3-field) shapes.
Map<String, String>? decodeAck(String raw) {
  if (!raw.startsWith('ACK$_delim')) return null;
  final parts = raw.split(_delim);
  if (parts.length < 3) return null;
  return {
    'messageId': parts[1],
    'relayerId': parts[2],
    'status': parts.length >= 4 ? parts[3] : 'ack',
  };
}
