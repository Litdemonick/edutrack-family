import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// ═══════════════════════════════════════════════════════════════
// DATABASE HELPER — EduTrack Family 2.0
// SQLite multi-tenant: TODO lleva student_id.
// Archivo nuevo (edutrack_v2.db) — arranque limpio, sin migración
// del esquema v1 (decisión de proyecto: fresh start).
//
// Sync offline-first:
//   is_dirty = 1  → cambio local pendiente de subir a Firestore
//   sync_meta     → checkpoint de última descarga por (colección, estudiante)
// ═══════════════════════════════════════════════════════════════

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  static const String _dbName = 'edutrack_v2.db';
  static const int _dbVersion = 4;

  /// Nombre del archivo v1 que se elimina en el primer arranque 2.0.
  static const String legacyDbName = 'edutrack.db';

  // ─────────────────────────────────────────────────────────────
  // NOMBRES DE TABLAS
  // ─────────────────────────────────────────────────────────────

  static const String tableStudent = 'students';
  static const String tableTask = 'tasks';
  static const String tableEvent = 'events';
  static const String tableScheduleBlock = 'schedule_blocks';
  static const String tableEvidence = 'evidences';
  static const String tablePendingOp = 'pending_ops';
  static const String tableSyncMeta = 'sync_meta';
  static const String tableLocationBuffer = 'location_buffer';

  // ─────────────────────────────────────────────────────────────
  // ACCESO
  // ─────────────────────────────────────────────────────────────

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();

    // Fresh start 2.0: eliminar la base v1 si existe
    try {
      await deleteDatabase(join(dbPath, legacyDbName));
    } catch (_) {}

    return openDatabase(
      join(dbPath, _dbName),
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MIGRACIONES — ALTER TABLE ADD COLUMN, nunca se borra nada
  // ─────────────────────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Quién creó la tarea/evento (padre/tutor o profesor) — para
      // mostrar "Creado por: ..." en el detalle.
      await db.execute('ALTER TABLE $tableTask ADD COLUMN assigned_by_role TEXT');
      await db.execute('ALTER TABLE $tableTask ADD COLUMN assigned_by_name TEXT');
      await db.execute('ALTER TABLE $tableEvent ADD COLUMN assigned_by TEXT');
      await db.execute('ALTER TABLE $tableEvent ADD COLUMN assigned_by_role TEXT');
      await db.execute('ALTER TABLE $tableEvent ADD COLUMN assigned_by_name TEXT');
    }
    if (oldVersion < 3) {
      // Cédula del hijo/a — obligatoria para perfiles nuevos, ver
      // child_form_sheet.dart. Perfiles ya existentes quedan sin ella
      // hasta que el padre edite el perfil.
      await db.execute('ALTER TABLE $tableStudent ADD COLUMN cedula TEXT');
    }
    if (oldVersion < 4) {
      // Quién creó/editó por última vez cada bloque del horario —
      // igual que assigned_by* en tareas/eventos, solo para mostrar.
      await db.execute('ALTER TABLE $tableScheduleBlock ADD COLUMN assigned_by TEXT');
      await db.execute('ALTER TABLE $tableScheduleBlock ADD COLUMN assigned_by_role TEXT');
      await db.execute('ALTER TABLE $tableScheduleBlock ADD COLUMN assigned_by_name TEXT');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ESQUEMA v1 (2.0)
  // ─────────────────────────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    // Estudiantes vinculados a esta cuenta (espejo de students/{id})
    await db.execute('''
      CREATE TABLE $tableStudent (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cedula TEXT,
        grade TEXT,
        avatar_color INTEGER,
        photo_path TEXT,
        parent_ids TEXT NOT NULL DEFAULT '[]',
        teacher_ids TEXT NOT NULL DEFAULT '[]',
        location_sharing_enabled INTEGER NOT NULL DEFAULT 0,
        location_device_confirmed INTEGER NOT NULL DEFAULT 0,
        seismic_alerts_enabled INTEGER NOT NULL DEFAULT 1,
        seismic_min_magnitude REAL NOT NULL DEFAULT 4.5,
        updated_at TEXT NOT NULL,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableTask (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        title TEXT NOT NULL,
        subject TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 0,
        evidence_photo_paths TEXT,
        has_evidence_images INTEGER NOT NULL DEFAULT 0,
        completion_note TEXT,
        reference_image_paths TEXT,
        has_reference_images INTEGER NOT NULL DEFAULT 0,
        conversation_history TEXT,
        assigned_by TEXT,
        assigned_by_role TEXT,
        assigned_by_name TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_archived INTEGER NOT NULL DEFAULT 0,
        notification_days_before INTEGER NOT NULL DEFAULT 1,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableEvent (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        end_date TEXT,
        is_all_day INTEGER NOT NULL DEFAULT 1,
        reminder_minutes_before INTEGER NOT NULL DEFAULT 60,
        assigned_by TEXT,
        assigned_by_role TEXT,
        assigned_by_name TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_dirty INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Horario semanal data-driven (reemplaza el ScheduleBlock (horario v1) hardcodeado)
    await db.execute('''
      CREATE TABLE $tableScheduleBlock (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        weekday INTEGER NOT NULL,
        start_min INTEGER NOT NULL,
        end_min INTEGER NOT NULL,
        subject TEXT NOT NULL,
        is_break INTEGER NOT NULL DEFAULT 0,
        color INTEGER,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        is_dirty INTEGER NOT NULL DEFAULT 0,
        assigned_by TEXT,
        assigned_by_role TEXT,
        assigned_by_name TEXT
      )
    ''');

    // Evidencias: metadata local + cola de subida a Firebase Storage
    await db.execute('''
      CREATE TABLE $tableEvidence (
        id TEXT PRIMARY KEY,
        student_id TEXT NOT NULL,
        task_id TEXT NOT NULL,
        kind TEXT NOT NULL DEFAULT 'evidence',
        local_path TEXT NOT NULL,
        remote_path TEXT,
        captured_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Cola genérica de operaciones offline (ej. zoneEvents sin red)
    await db.execute('''
      CREATE TABLE $tablePendingOp (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        op_type TEXT NOT NULL,
        student_id TEXT,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Checkpoint de sync por colección y estudiante
    await db.execute('''
      CREATE TABLE $tableSyncMeta (
        collection TEXT NOT NULL,
        student_id TEXT NOT NULL,
        last_pulled_at TEXT,
        PRIMARY KEY (collection, student_id)
      )
    ''');

    // Buffer de puntos GPS del dispositivo del hijo (flush al reconectar)
    await db.execute('''
      CREATE TABLE $tableLocationBuffer (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL,
        speed REAL,
        battery INTEGER,
        ts TEXT NOT NULL
      )
    ''');

    // Índices para las queries frecuentes (siempre filtradas por estudiante)
    await db.execute(
        'CREATE INDEX idx_task_student_due ON $tableTask (student_id, due_date)');
    await db.execute(
        'CREATE INDEX idx_task_student_status ON $tableTask (student_id, status, is_archived)');
    await db.execute(
        'CREATE INDEX idx_task_dirty ON $tableTask (is_dirty)');
    await db.execute(
        'CREATE INDEX idx_event_student_date ON $tableEvent (student_id, date)');
    await db.execute(
        'CREATE INDEX idx_event_dirty ON $tableEvent (is_dirty)');
    await db.execute(
        'CREATE INDEX idx_schedule_student ON $tableScheduleBlock (student_id, weekday)');
    await db.execute(
        'CREATE INDEX idx_evidence_task ON $tableEvidence (task_id)');
    await db.execute(
        'CREATE INDEX idx_evidence_pending ON $tableEvidence (is_synced)');
    await db.execute(
        'CREATE INDEX idx_locbuf_student ON $tableLocationBuffer (student_id, ts)');
  }

  // ─────────────────────────────────────────────────────────────
  // OPERACIONES CRUD GENÉRICAS (misma API que v1 + extensiones)
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
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
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

  /// Borra todas las filas de [table] con ese student_id — usar al
  /// eliminar un hijo/a para limpiar tareas/eventos/horario/evidencias
  /// locales que ya no tienen dueño.
  Future<void> deleteWhereStudent(String table, String studentId) async {
    final db = await database;
    await db.delete(table, where: 'student_id = ?', whereArgs: [studentId]);
  }

  /// Marca/desmarca el flag de cambio local pendiente de sync.
  Future<void> setDirty(String table, String id, bool dirty) async {
    final db = await database;
    await db.update(table, {'is_dirty': dirty ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Filas con cambios locales pendientes de subir.
  Future<List<Map<String, dynamic>>> queryDirty(String table) async {
    final db = await database;
    return db.query(table, where: 'is_dirty = 1');
  }

  /// Checkpoint de sincronización por (colección, estudiante).
  Future<String?> getLastPulledAt(String collection, String studentId) async {
    final db = await database;
    final rows = await db.query(
      tableSyncMeta,
      where: 'collection = ? AND student_id = ?',
      whereArgs: [collection, studentId],
    );
    return rows.isEmpty ? null : rows.first['last_pulled_at'] as String?;
  }

  Future<void> setLastPulledAt(
      String collection, String studentId, String isoTime) async {
    final db = await database;
    await db.insert(
      tableSyncMeta,
      {
        'collection': collection,
        'student_id': studentId,
        'last_pulled_at': isoTime,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Borra TODOS los datos locales (logout / cambio de cuenta).
  Future<void> wipeAll() async {
    final db = await database;
    final batch = db.batch();
    for (final t in [
      tableStudent,
      tableTask,
      tableEvent,
      tableScheduleBlock,
      tableEvidence,
      tablePendingOp,
      tableSyncMeta,
      tableLocationBuffer,
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
