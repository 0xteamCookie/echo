/// Beacon BLE mesh wire format.
///
/// v2 packet (`||`-delimited, 10 fields including version tag):
///
/// ```
/// v2||<messageId>||<b64(message)>||<deviceId>||<b64(senderName)>||<expiresAt>||<b64(location)>||<time>||<hopCount>||<isSos>
/// ```
///
/// Text-bearing fields (`message`, `senderName`, `location`) are base64-encoded
/// so arbitrary user input containing `||` can never corrupt the frame (P1-1).
/// `time` is the original UTC timestamp of the SOS/message (stable across
/// hops so sync ordering is correct). `hopCount` enables a strict TTL so
/// dense meshes don't flood forever (P1-2).
///
/// v1 packet (legacy) is still accepted on receive for backward-compat only:
///
/// ```
/// <messageId>||<message>||<deviceId>||<senderName>||<expiresAt>||<location>||<isSos>
/// ```
///
/// All outgoing packets MUST use v2.
library;

import 'dart:convert';

/// Drop any packet that has been relayed more than this many times.
const int maxHops = 8;

const String _v2Tag = 'v2';
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

/// Serialize a packet map to the v2 wire format.
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

/// Decode a v2 (preferred) or v1 (legacy) packet. Returns `null` if the frame
/// is an ACK, malformed, or unknown.
Map<String, dynamic>? decodePacket(String raw) {
  if (raw.startsWith('ACK$_delim')) {
    // ACKs are handled by the caller; not a data packet.
    return null;
  }

  final parts = raw.split(_delim);

  if (parts.isNotEmpty && parts.first == _v2Tag) {
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
