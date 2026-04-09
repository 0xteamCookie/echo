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

Future<List<Map<String, dynamic>>> getMessages() async {
  final db = await DatabaseHelper.instance.database;
  return await db.query('messages');
}