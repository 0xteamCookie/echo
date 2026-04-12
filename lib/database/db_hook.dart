import 'package:sqflite/sqflite.dart';
import 'initialize_db.dart';


Future<void> insertMessage(Map<String, dynamic> data) async {
  final db = await DatabaseHelper.instance.database;

  await db.insert(
    'messages',
    data,
    conflictAlgorithm: ConflictAlgorithm.replace, 
  );
}

Future<void> insertMessageDevice({
  required String messageId,
  required String deviceId,
}) async {
  final db = await DatabaseHelper.instance.database;

  await db.insert(
    'message_devices',
    {
      'messageId': messageId,
      'deviceId': deviceId,
    },
    conflictAlgorithm: ConflictAlgorithm.ignore, // prevents duplicates
  );
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

Future<List<Map<String, dynamic>>> getDevicesForMessage(String messageId) async {
  final db = await DatabaseHelper.instance.database;

  return await db.query(
    'message_devices',
    where: 'messageId = ?',
    whereArgs: [messageId],
  );
}