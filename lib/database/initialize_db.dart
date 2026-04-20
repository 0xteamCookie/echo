import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
  await db.execute('''
    CREATE TABLE messages (
      messageId TEXT PRIMARY KEY,
      message TEXT,
      deviceId TEXT,
      senderName TEXT,
      expiresAt TEXT,
      location TEXT,
      isSos INTEGER DEFAULT 0,
      isSynced INTEGER DEFAULT 0,
      lastSyncedAt TEXT
    );
  ''');

  await db.execute('''
    CREATE TABLE message_devices (
      messageId TEXT,
      deviceId TEXT,
      PRIMARY KEY (messageId, deviceId)
    );
  ''');
  }

  Future<void> deleteDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');
    
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }
    
    await deleteDatabase(path);
    _database = null; 
  }
} 
