import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// TASK REPOSITORY — EduTrack Family
// Operaciones CRUD sobre tareas en SQLite.
// ═══════════════════════════════════════════════════════════════

class TaskRepository {
  TaskRepository._();
  static final TaskRepository instance = TaskRepository._();

  final _db = DatabaseHelper.instance;
  static const _table = DatabaseHelper.tableTask;

  // ─────────────────────────────────────────────────────────────
  // CREAR
  // ─────────────────────────────────────────────────────────────

  Future<void> createTask(TaskModel task) async {
    await _db.insert(_table, task.toMap());
  }

  // ─────────────────────────────────────────────────────────────
  // LEER
  // ─────────────────────────────────────────────────────────────

  Future<List<TaskModel>> getAllActiveTasks() async {
    final rows = await _db.queryAll(
      _table,
      where: 'is_archived = 0 AND is_deleted = 0',
      orderBy: 'due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getAllTasksForStats() async {
    final rows = await _db.queryAll(
      _table,
      where: 'is_archived = 0',
      orderBy: 'due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getPendingTasks() async {
    final rows = await _db.queryAll(
      _table,
      where: 'status = ? AND is_archived = 0 AND is_deleted = 0',
      whereArgs: [TaskStatus.pending.index],
      orderBy: 'due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getCompletedTasks() async {
    final rows = await _db.queryAll(
      _table,
      where: 'status = ? AND is_archived = 0 AND is_deleted = 0',
      whereArgs: [TaskStatus.completed.index],
      orderBy: 'completed_at DESC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getArchivedTasks() async {
    final rows = await _db.queryAll(
      _table,
      where: 'is_archived = 1 AND is_deleted = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<List<TaskModel>> getTasksForDate(DateTime date) async {
    final dateStr = EduDateUtils.toDateOnly(date);
    final rows = await _db.queryAll(
      _table,
      where: "due_date LIKE ? AND is_archived = 0 AND is_deleted = 0",
      whereArgs: ['$dateStr%'],
      orderBy: 'due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  Future<TaskModel?> getTaskById(String id) async {
    final row = await _db.queryById(_table, id);
    return row != null ? TaskModel.fromMap(row) : null;
  }

  Future<List<TaskModel>> getUrgentTasks() async {
    final in2days = EduDateUtils.toDateOnly(
      DateTime.now().add(const Duration(days: 2)),
    );
    final rows = await _db.queryAll(
      _table,
      where: "due_date <= ? AND status = ? AND is_archived = 0 AND is_deleted = 0",
      whereArgs: [in2days, TaskStatus.pending.index],
      orderBy: 'due_date ASC',
    );
    return rows.map(TaskModel.fromMap).toList();
  }

  // ─────────────────────────────────────────────────────────────
  // ACTUALIZAR
  // ─────────────────────────────────────────────────────────────

  Future<void> updateTask(TaskModel task) async {
    await _db.update(_table, task.toMap(), task.id);
  }

  Future<void> markCompleted(
    String id, {
    String? photoPath,
    List<String>? photoPaths,
  }) async {
    final task = await getTaskById(id);
    if (task == null) return;

    final paths = photoPaths ?? (photoPath != null ? [photoPath] : []);
    final updated = task.copyWith(
      status: TaskStatus.completed,
      evidencePhotoPaths: paths,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await updateTask(updated);
  }

  Future<void> submitForReview(
    String id, {
    String? photoPath,
    List<String>? photoPaths,
    String? note,
  }) async {
    final task = await getTaskById(id);
    if (task == null) return;

    final paths = photoPaths ?? (photoPath != null ? [photoPath] : []);
    final now = DateTime.now();
    final history = List<ConversationEntry>.from(task.conversationHistory)
      ..add(ConversationEntry(
        author: 'student',
        type: 'resubmit',
        text: note,
        photoPaths: paths,
        timestamp: now,
      ));
    final updated = task.copyWith(
      status: TaskStatus.pendingReview,
      evidencePhotoPaths: paths,
      completionNote: note,
      completedAt: now,
      updatedAt: now,
      conversationHistory: history,
    );
    await updateTask(updated);
  }

  Future<void> acceptTask(String id) async {
    final task = await getTaskById(id);
    if (task == null) return;
    final now = DateTime.now();
    final history = List<ConversationEntry>.from(task.conversationHistory)
      ..add(ConversationEntry(
        author: 'system',
        type: 'accept',
        text: 'Admin aceptó la tarea.',
        timestamp: now,
      ));
    final updated = task.copyWith(
      status: TaskStatus.completed,
      updatedAt: now,
      conversationHistory: history,
    );
    await updateTask(updated);
  }

  Future<void> rejectTask(String id, {String? reason}) async {
    final task = await getTaskById(id);
    if (task == null) return;
    final now = DateTime.now();
    final msg = reason != null && reason.isNotEmpty
        ? reason
        : 'Por favor corrige y vuelve a enviar.';
    final history = List<ConversationEntry>.from(task.conversationHistory)
      ..add(ConversationEntry(
        author: 'admin',
        type: 'reject',
        text: msg,
        timestamp: now,
      ));
    // No sobreescribir completionNote (nota original de Yordan)
    final updated = task.copyWith(
      status: TaskStatus.pending,
      updatedAt: now,
      conversationHistory: history,
    );
    await updateTask(updated);
  }

  Future<void> archiveTask(String id) async {
    final task = await getTaskById(id);
    if (task == null) return;

    final updated = task.copyWith(
      isArchived: true,
      updatedAt: DateTime.now(),
    );
    await updateTask(updated);
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR
  // ─────────────────────────────────────────────────────────────

  Future<void> deleteTask(String id) async {
    final task = await getTaskById(id);
    if (task == null) return;
    final updated = task.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
    );
    await updateTask(updated);
  }

  Future<void> clearArchivedOlderThan(int days) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final cutoffStr = EduDateUtils.toIso(cutoff);
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      _table,
      where: 'is_archived = 1 AND updated_at < ?',
      whereArgs: [cutoffStr],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ESTADÍSTICAS
  // ─────────────────────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final historical = await getAllTasksForStats();
    final current = historical.where((t) => !t.isDeleted).toList();
    final counted = historical
        .where((t) => !t.isDeleted || t.isCompleted || t.completedAt != null)
        .toList();
    final pending = current.where((t) => t.isPending).length;
    final completed = counted.where((t) => t.isCompleted).length;
    final overdue = current.where((t) => t.isOverdueTask).length;
    final urgent = current.where((t) => t.isUrgent && !t.isOverdueTask).length;

    return {
      'total': counted.length,
      'pending': pending,
      'completed': completed,
      'overdue': overdue,
      'urgent': urgent,
    };
  }
}
