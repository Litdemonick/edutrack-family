import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ═══════════════════════════════════════════════════════════════
// DATABASE HELPER — EduTrack Family
// Singleton que gestiona la base de datos SQLite local.
// ═══════════════════════════════════════════════════════════════

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  static const String _dbName = 'edutrack.db';
  static const int _dbVersion = 7;

  // ─────────────────────────────────────────────────────────────
  // NOMBRES DE TABLAS Y COLUMNAS
  // ─────────────────────────────────────────────────────────────

  static const String tableTask = 'tasks';
  static const String tableEvent = 'events';
  static const String tableEvidence = 'photo_evidences';

  // ─────────────────────────────────────────────────────────────
  // ACCESO A LA BASE DE DATOS
  // ─────────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CREACIÓN DE TABLAS
  // ─────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTask (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        photo_evidence_path TEXT,
        evidence_photo_paths TEXT,
        has_evidence_images INTEGER NOT NULL DEFAULT 0,
        completion_note TEXT,
        reference_image_path TEXT,
        has_reference_images INTEGER NOT NULL DEFAULT 0,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        notification_days_before INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        conversation_history TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE $tableEvent (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        end_date TEXT,
        is_all_day INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        reminder_minutes_before INTEGER NOT NULL DEFAULT 60
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableEvidence (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        local_path TEXT NOT NULL,
        remote_url TEXT,
        captured_at TEXT NOT NULL,
        is_synced_to_cloud INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (task_id) REFERENCES $tableTask (id) ON DELETE CASCADE
      )
    ''');

    // Índices para búsquedas frecuentes
    await db.execute('CREATE INDEX idx_task_due ON $tableTask (due_date)');
    await db.execute('CREATE INDEX idx_task_status ON $tableTask (status)');
    await db.execute('CREATE INDEX idx_task_archived ON $tableTask (is_archived)');
    await db.execute('CREATE INDEX idx_event_date ON $tableEvent (date)');
    await db.execute('CREATE INDEX idx_evidence_task ON $tableEvidence (task_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: multi-foto, nota de finalización e imagen de referencia
      await db.execute(
        'ALTER TABLE $tableTask ADD COLUMN evidence_photo_paths TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableTask ADD COLUMN completion_note TEXT',
      );
      await db.execute(
        'ALTER TABLE $tableTask ADD COLUMN reference_image_path TEXT',
      );
    }
    if (oldVersion < 3) {
      // v2 → v3: hora específica en eventos (is_all_day)
      try {
        await db.execute(
          'ALTER TABLE $tableEvent ADD COLUMN is_all_day INTEGER NOT NULL DEFAULT 1',
        );
      } catch (_) {
        // La columna ya existe en instalaciones más nuevas
      }
    }
    if (oldVersion < 4) {
      // v3 → v4: borrado lógico (soft delete)
      try {
        await db.execute(
          'ALTER TABLE $tableTask ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $tableEvent ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 5) {
      // v4 → v5: flag para saber si la tarea tiene imágenes de referencia
      // (aunque las rutas estén vacías porque viajan por task_images en Firestore)
      try {
        await db.execute(
          'ALTER TABLE $tableTask ADD COLUMN has_reference_images INTEGER NOT NULL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE $tableTask ADD COLUMN has_evidence_images INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute(
          'ALTER TABLE $tableEvent ADD COLUMN reminder_minutes_before INTEGER NOT NULL DEFAULT 60',
        );
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute(
          'ALTER TABLE $tableTask ADD COLUMN conversation_history TEXT',
        );
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // OPERACIONES CRUD GENÉRICAS
  // ─────────────────────────────────────────────────────────────

  Future<void> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String id,
  ) async {
    final db = await database;
    await db.update(table, data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> queryAll(
    String table, {
    String? orderBy,
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  Future<Map<String, dynamic>?> queryById(String table, String id) async {
    final db = await database;
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isEmpty ? null : results.first;
  }

  Future<void> deleteAll(String table) async {
    final db = await database;
    await db.delete(table);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
