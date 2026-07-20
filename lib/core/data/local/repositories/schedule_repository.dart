import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';

// ═══════════════════════════════════════════════════════════════
// SCHEDULE REPOSITORY — EduTrack Family 2.0
// Horario semanal DATA-DRIVEN por estudiante (SQLite + Firestore).
// Reemplaza al ScheduleBlock (horario v1) hardcodeado de la v1.
// ═══════════════════════════════════════════════════════════════

class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository instance = ScheduleRepository._();

  final _db = DatabaseHelper.instance;
  static const _table = DatabaseHelper.tableScheduleBlock;

  Future<List<ScheduleBlock>> getAll(String studentId) async {
    final rows = await _db.queryAll(
      _table,
      where: 'student_id = ? AND is_deleted = 0',
      whereArgs: [studentId],
      orderBy: 'weekday ASC, start_min ASC',
    );
    return rows.map(ScheduleBlock.fromMap).toList();
  }

  Future<List<ScheduleBlock>> getForDay(String studentId, int weekday) async {
    final rows = await _db.queryAll(
      _table,
      where: 'student_id = ? AND weekday = ? AND is_deleted = 0',
      whereArgs: [studentId, weekday],
      orderBy: 'start_min ASC',
    );
    return rows.map(ScheduleBlock.fromMap).toList();
  }

  /// Clase en curso ahora mismo (o null).
  Future<ScheduleBlock?> getCurrentClass(String studentId) async {
    final now = DateTime.now();
    final today = await getForDay(studentId, now.weekday);
    for (final block in today) {
      if (block.isCurrentAt(now)) return block;
    }
    return null;
  }

  /// Próxima clase de hoy (o null).
  Future<ScheduleBlock?> getNextClass(String studentId) async {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = await getForDay(studentId, now.weekday);
    for (final block in today) {
      if (block.startMin > nowMin) return block;
    }
    return null;
  }

  Future<ScheduleBlock> createBlock({
    required String studentId,
    required int weekday,
    required int startMin,
    required int endMin,
    required String subject,
    bool isBreak = false,
    int? color,
    String? assignedBy,
    String? assignedByRole,
    String? assignedByName,
  }) async {
    final block = ScheduleBlock(
      id: const Uuid().v4(),
      studentId: studentId,
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
      subject: subject,
      isBreak: isBreak,
      color: color,
      updatedAt: DateTime.now(),
      assignedBy: assignedBy,
      assignedByRole: assignedByRole,
      assignedByName: assignedByName,
    );
    final map = block.toMap();
    map['is_dirty'] = 1;
    await _db.insert(_table, map);
    // Push inmediato best-effort (si falla queda dirty)
    try {
      await FirestoreService.instance.uploadScheduleBlock(block);
      await _db.setDirty(_table, block.id, false);
    } catch (_) {}
    return block;
  }

  Future<void> updateBlock(ScheduleBlock block) async {
    final updated = block.copyWith(updatedAt: DateTime.now());
    final map = updated.toMap();
    map['is_dirty'] = 1;
    await _db.update(_table, map, updated.id);
    try {
      await FirestoreService.instance.uploadScheduleBlock(updated);
      await _db.setDirty(_table, updated.id, false);
    } catch (_) {}
  }

  Future<void> deleteBlock(ScheduleBlock block) async {
    // Soft delete para que la eliminación se propague por sync
    await updateBlock(block.copyWith(isDeleted: true));
  }
}
