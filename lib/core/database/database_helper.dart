import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'daily_pass.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        detail TEXT,
        repeat_type INTEGER NOT NULL,
        repeat_config TEXT,
        use_notification INTEGER NOT NULL DEFAULT 0,
        notification_time TEXT,
        is_notification_persistent INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE completions (
        id TEXT PRIMARY KEY,
        activity_id TEXT NOT NULL,
        completed_date TEXT NOT NULL,
        completed_at TEXT NOT NULL,
        is_completed INTEGER NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY,
        theme_mode INTEGER NOT NULL DEFAULT 0,
        week_start_day INTEGER NOT NULL DEFAULT 0,
        default_view TEXT NOT NULL DEFAULT 'day'
      )
    ''');

    // Insert default settings
    await db.insert('settings', {
      'id': 1,
      'theme_mode': 0,
      'week_start_day': 0,
      'default_view': 'day',
    });

    // Create indexes
    await db.execute('CREATE INDEX idx_completions_activity ON completions(activity_id)');
    await db.execute('CREATE INDEX idx_completions_date ON completions(completed_date)');
    await db.execute('CREATE INDEX idx_activities_updated ON activities(updated_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE activities ADD COLUMN use_notification INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE activities ADD COLUMN notification_time TEXT');
      await db.execute('ALTER TABLE activities ADD COLUMN is_notification_persistent INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('completions');
    await db.delete('activities');
  }
}
