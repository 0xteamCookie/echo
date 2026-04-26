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

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
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
        time TEXT,
        hopCount INTEGER DEFAULT 0,
        isSos INTEGER DEFAULT 0,
        isSynced INTEGER DEFAULT 0,
        lastSyncedAt TEXT,
        ackStatus TEXT,
        signature TEXT,
        deviceSenderPublicKey TEXT,
        triage TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE message_devices (
        messageId TEXT,
        deviceId TEXT,
        PRIMARY KEY (messageId, deviceId)
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_time ON messages(time);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_isSynced ON messages(isSynced);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_expiresAt ON messages(expiresAt);',
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add `time` and `hopCount` columns that P0-1 / P1-2 rely on.
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN time TEXT;');
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE messages ADD COLUMN hopCount INTEGER DEFAULT 0;',
        );
      } catch (_) {}
      // Backfill: derive time from expiresAt - 24h so existing rows are sortable.
      await db.execute(
        "UPDATE messages SET time = expiresAt WHERE time IS NULL OR time = '';",
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_time ON messages(time);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_isSynced ON messages(isSynced);',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_expiresAt ON messages(expiresAt);',
      );
      if (oldVersion < 3) {
        // P1-5: track rescuer acknowledgement state per message.
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN ackStatus TEXT;');
        } catch (_) {}
      }
      if (oldVersion < 4) {
        // P2-11: ed25519 signature + sender public key fields, and P2-7
        // on-device triage blob. All nullable; v1/v2 rows stay valid.
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN signature TEXT;');
        } catch (_) {}
        try {
          await db.execute(
            'ALTER TABLE messages ADD COLUMN deviceSenderPublicKey TEXT;',
          );
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE messages ADD COLUMN triage TEXT;');
        } catch (_) {}
      }
    }
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
