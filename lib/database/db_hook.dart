import 'package:sqflite/sqflite.dart';
import 'initialize_db.dart';

const Set<String> _messageColumns = {
  'messageId',
  'message',
  'deviceId',
  'senderName',
  'expiresAt',
  'location',
  'time',
  'hopCount',
  'isSos',
  'isSynced',
  'lastSyncedAt',
  'ackStatus',
  'signature',
  'deviceSenderPublicKey',
  'triage',
};

Future<void> insertMessage(Map<String, dynamic> data) async {
  final db = await DatabaseHelper.instance.database;

  final row = <String, dynamic>{
    for (final e in data.entries)
      if (_messageColumns.contains(e.key)) e.key: e.value,
  };
  if (row['time'] == null ||
      (row['time'] is String && (row['time'] as String).isEmpty)) {
    final expiresAt = row['expiresAt'];
    String? derived;
    if (expiresAt is String && expiresAt.isNotEmpty) {
      try {
        final expiry = DateTime.parse(expiresAt).toUtc();
        derived = expiry.subtract(const Duration(days: 1)).toIso8601String();
      } catch (_) {}
    }
    row['time'] = derived ?? DateTime.now().toUtc().toIso8601String();
  }
  if (row['hopCount'] == null) {
    row['hopCount'] = 0;
  }

  await db.insert(
    'messages',
    row,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> insertMessageDevice({
  required String messageId,
  required String deviceId,
}) async {
  final db = await DatabaseHelper.instance.database;

  await db.insert('message_devices', {
    'messageId': messageId,
    'deviceId': deviceId,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

Future<List<Map<String, dynamic>>> getMessages() async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('messages');
}

Future<bool> messageExists(String messageId) async {
  final db = await DatabaseHelper.instance.database;

  final result = await db.query(
    'messages',
    where: 'messageId = ?',
    whereArgs: [messageId],
    limit: 1,
  );

  return result.isNotEmpty;
}

Future<List<Map<String, dynamic>>> getDevicesForMessage(
  String messageId,
) async {
  final db = await DatabaseHelper.instance.database;

  return await db.query(
    'message_devices',
    where: 'messageId = ?',
    whereArgs: [messageId],
  );
}

Future<List<Map<String, dynamic>>> getAllMessageDevices() async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('message_devices');
}

Future<List<Map<String, dynamic>>> getNonExpiredMessages() async {
  final db = await DatabaseHelper.instance.database;
  final now = DateTime.now().toUtc().toIso8601String();

  return await db.query('messages', where: 'expiresAt > ?', whereArgs: [now]);
}

Future<void> nukeDatabase() async {
  await DatabaseHelper.instance.deleteDb();
}

Future<List<Map<String, dynamic>>> getUnsyncedMessages() async {
  final db = await DatabaseHelper.instance.database;
  final batchSize = 10;

  return await db.query(
    'messages',
    where: 'isSynced = ?',
    whereArgs: [0],
    limit: batchSize,
    orderBy: 'isSos DESC, time ASC',
  );
}

Future<void> markAsSynced(String id) async {
  final db = await DatabaseHelper.instance.database;

  await db.update(
    'messages',
    {'isSynced': 1, 'lastSyncedAt': DateTime.now().toIso8601String()},
    where: 'messageId = ?',
    whereArgs: [id],
  );
}

Future<List<Map<String, dynamic>>> getRecentSosMessages({
  int withinHours = 24,
}) async {
  final db = await DatabaseHelper.instance.database;
  final cutoff = DateTime.now()
      .toUtc()
      .subtract(Duration(hours: withinHours))
      .toIso8601String();

  return await db.query(
    'messages',
    where: 'isSos = ? AND time >= ?',
    whereArgs: [1, cutoff],
    orderBy: 'time DESC',
  );
}

Future<List<Map<String, dynamic>>> getReportableIncidents({
  int withinHours = 24,
}) async {
  final db = await DatabaseHelper.instance.database;
  final cutoff = DateTime.now()
      .toUtc()
      .subtract(Duration(hours: withinHours))
      .toIso8601String();

  return await db.query(
    'messages',
    where: 'isSos = ? AND time >= ?',
    whereArgs: [1, cutoff],
    orderBy: 'time DESC',
  );
}

Future<void> updateAckStatus(String messageId, String status) async {
  final db = await DatabaseHelper.instance.database;
  await db.update(
    'messages',
    {'ackStatus': status},
    where: 'messageId = ?',
    whereArgs: [messageId],
  );
}
