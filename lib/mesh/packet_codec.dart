library;

import 'dart:convert';

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
    return encoded;
  }
}

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

Map<String, dynamic>? decodePacket(String raw) {
  if (raw.startsWith('ACK$_delim')) {
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

  if (parts.length == 7) {
    return {
      'messageId': parts[0],
      'message': parts[1],
      'deviceId': parts[2],
      'senderName': parts[3],
      'expiresAt': parts[4],
      'location': parts[5],
      'time': '',
      'hopCount': 0,
      'isSos': int.tryParse(parts[6]) ?? 0,
      'protocolVersion': 1,
    };
  }

  return null;
}

String encodeAck(String messageId, String relayerId, {String status = 'ack'}) =>
    'ACK$_delim$messageId$_delim$relayerId$_delim$status';

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
