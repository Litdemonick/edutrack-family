import 'dart:async';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import '../data/local/models/event_model.dart';
import '../data/local/models/schedule_block_model.dart';
import '../data/local/models/student_model.dart';
import '../data/local/models/task_model.dart';
import '../firebase/firestore_service.dart';

// ═══════════════════════════════════════════════════════════════
// SYNC SERVICE — EduTrack Family 2.0
// Sincronización bidireccional SQLite ↔ Firestore, SCOPED por
// estudiante vinculado (students/{id}/tasks|events|scheduleBlocks).
//
// Estrategia de conflictos: "last modified wins" por updatedAt.
//   - Solo existe local   → push a Firestore
//   - Solo existe remoto  → insert en SQLite
//   - Ambos existen       → gana el updatedAt más reciente
//
// Offline-first: los cambios locales se marcan is_dirty=1 y se
// suben en el siguiente fullSync() o push directo si hay red.
// ═══════════════════════════════════════════════════════════════

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Estudiantes vinculados a la sesión actual (los define el
  /// provider de sesión al hacer login / cambiar vínculos).
  List<String> _studentIds = const [];
  void setLinkedStudents(List<String> ids) => _studentIds = List.of(ids);

  final Map<String, StreamSubscription> _taskSubs = {};
  final Map<String, StreamSubscription> _eventSubs = {};
  final Map<String, StreamSubscription> _scheduleSubs = {};
  final Map<String, bool> _firstSnapshot = {};

  // ─────────────────────────────────────────────────────────────
  // SYNC INICIAL — descarga el subárbol de cada estudiante
  // ─────────────────────────────────────────────────────────────

  Future<void> initialSync({
    required Function() onTasksUpdated,
    required Function() onEventsUpdated,
  }) async {
    if (_isSyncing || _studentIds.isEmpty) return;
    _isSyncing = true;
    try {
      for (final sid in _studentIds) {
        await _pullTasks(sid);
        await _pullEvents(sid);
        await _pullScheduleBlocks(sid);
      }
      onTasksUpdated();
      onEventsUpdated();
    } catch (e) {
      debugPrint('[Sync] initialSync falló: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // TIEMPO REAL — un listener por estudiante y colección
  // ─────────────────────────────────────────────────────────────

  void startRealtimeSync({
    Function(TaskModel task)? onNewTaskReceived,
    Function(TaskModel oldTask, TaskModel newTask)? onTaskUpdated,
    required Function() onTasksUpdated,
    required Function() onEventsUpdated,
  }) {
    stopRealtimeSync();
    for (final sid in _studentIds) {
      _firstSnapshot['tasks_$sid'] = true;

      _taskSubs[sid] =
          FirestoreService.instance.watchTasks(sid).listen((remoteTasks) async {
        final isFirst = _firstSnapshot['tasks_$sid'] ?? true;
        _firstSnapshot['tasks_$sid'] = false;

        final db = DatabaseHelper.instance;
        final localRows = await db.queryAll(
          DatabaseHelper.tableTask,
          where: 'student_id = ?',
          whereArgs: [sid],
        );
        final localById = {
          for (final row in localRows) row['id'] as String: TaskModel.fromMap(row)
        };

        var changed = false;
        for (final remote in remoteTasks) {
          final local = localById[remote.id];
          if (local == null) {
            await db.insert(DatabaseHelper.tableTask, remote.toMap());
            changed = true;
            if (!isFirst &&
                !remote.isDeleted &&
                remote.isPending &&
                onNewTaskReceived != null) {
              onNewTaskReceived(remote);
            }
          } else if (remote.updatedAt.isAfter(local.updatedAt)) {
            await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
            changed = true;
            if (!isFirst && onTaskUpdated != null) {
              onTaskUpdated(local, remote);
            }
          }
        }
        if (changed) onTasksUpdated();
      }, onError: (e) => debugPrint('[Sync] stream tasks($sid): $e'));

      _eventSubs[sid] =
          FirestoreService.instance.watchEvents(sid).listen((remoteEvents) async {
        final db = DatabaseHelper.instance;
        final localRows = await db.queryAll(
          DatabaseHelper.tableEvent,
          where: 'student_id = ?',
          whereArgs: [sid],
        );
        final localById = {
          for (final row in localRows)
            row['id'] as String: EventModel.fromMap(row)
        };

        var changed = false;
        for (final remote in remoteEvents) {
          final local = localById[remote.id];
          if (local == null) {
            await db.insert(DatabaseHelper.tableEvent, remote.toMap());
            changed = true;
          } else if (remote.updatedAt.isAfter(local.updatedAt)) {
            await db.update(
                DatabaseHelper.tableEvent, remote.toMap(), remote.id);
            changed = true;
          }
        }
        if (changed) onEventsUpdated();
      }, onError: (e) => debugPrint('[Sync] stream events($sid): $e'));

      _scheduleSubs[sid] = FirestoreService.instance
          .watchScheduleBlocks(sid)
          .listen((remoteBlocks) async {
        final db = DatabaseHelper.instance;
        for (final block in remoteBlocks) {
          await db.insert(DatabaseHelper.tableScheduleBlock, block.toMap());
        }
      }, onError: (e) => debugPrint('[Sync] stream schedule($sid): $e'));
    }
  }

  void stopRealtimeSync() {
    for (final sub in _taskSubs.values) {
      sub.cancel();
    }
    for (final sub in _eventSubs.values) {
      sub.cancel();
    }
    for (final sub in _scheduleSubs.values) {
      sub.cancel();
    }
    _taskSubs.clear();
    _eventSubs.clear();
    _scheduleSubs.clear();
    _firstSnapshot.clear();
  }

  // ─────────────────────────────────────────────────────────────
  // FULL SYNC — push de dirty rows + pull incremental
  // ─────────────────────────────────────────────────────────────

  Future<void> fullSync() async {
    if (_isSyncing || _studentIds.isEmpty) return;
    _isSyncing = true;
    try {
      await _pushDirty();
      for (final sid in _studentIds) {
        await _pullTasks(sid);
        await _pullEvents(sid);
        await _pullScheduleBlocks(sid);
      }
    } catch (e) {
      debugPrint('[Sync] fullSync falló: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pushDirty() async {
    final db = DatabaseHelper.instance;

    for (final row in await db.queryDirty(DatabaseHelper.tableTask)) {
      final task = TaskModel.fromMap(row);
      if (task.studentId.isEmpty) continue;
      try {
        await FirestoreService.instance.uploadTask(_stripLocalPaths(task));
        await db.setDirty(DatabaseHelper.tableTask, task.id, false);
      } catch (e) {
        debugPrint('[Sync] push dirty task ${task.id}: $e');
      }
    }

    for (final row in await db.queryDirty(DatabaseHelper.tableEvent)) {
      final event = EventModel.fromMap(row);
      if (event.studentId.isEmpty) continue;
      try {
        await FirestoreService.instance.uploadEvent(event);
        await db.setDirty(DatabaseHelper.tableEvent, event.id, false);
      } catch (e) {
        debugPrint('[Sync] push dirty event ${event.id}: $e');
      }
    }

    for (final row in await db.queryDirty(DatabaseHelper.tableScheduleBlock)) {
      final block = ScheduleBlock.fromMap(row);
      try {
        await FirestoreService.instance.uploadScheduleBlock(block);
        await db.setDirty(DatabaseHelper.tableScheduleBlock, block.id, false);
      } catch (e) {
        debugPrint('[Sync] push dirty block ${block.id}: $e');
      }
    }
  }

  Future<void> _pullTasks(String sid) async {
    final db = DatabaseHelper.instance;
    final since = await db.getLastPulledAt('tasks', sid);
    final remoteTasks = await FirestoreService.instance.downloadTasks(
      sid,
      updatedAfter: since != null ? DateTime.parse(since) : null,
    );

    for (final remote in remoteTasks) {
      final localRow = await db.queryById(DatabaseHelper.tableTask, remote.id);
      if (localRow == null) {
        await db.insert(DatabaseHelper.tableTask, remote.toMap());
      } else {
        final local = TaskModel.fromMap(localRow);
        final isDirty = (localRow['is_dirty'] ?? 0) == 1;
        // No pisar cambios locales pendientes de subir
        if (!isDirty && remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
        }
      }
    }
    await db.setLastPulledAt('tasks', sid, DateTime.now().toIso8601String());
  }

  Future<void> _pullEvents(String sid) async {
    final db = DatabaseHelper.instance;
    final since = await db.getLastPulledAt('events', sid);
    final remoteEvents = await FirestoreService.instance.downloadEvents(
      sid,
      updatedAfter: since != null ? DateTime.parse(since) : null,
    );

    for (final remote in remoteEvents) {
      final localRow = await db.queryById(DatabaseHelper.tableEvent, remote.id);
      if (localRow == null) {
        await db.insert(DatabaseHelper.tableEvent, remote.toMap());
      } else {
        final local = EventModel.fromMap(localRow);
        final isDirty = (localRow['is_dirty'] ?? 0) == 1;
        if (!isDirty && remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableEvent, remote.toMap(), remote.id);
        }
      }
    }
    await db.setLastPulledAt('events', sid, DateTime.now().toIso8601String());
  }

  Future<void> _pullScheduleBlocks(String sid) async {
    final db = DatabaseHelper.instance;
    final blocks = await FirestoreService.instance.downloadScheduleBlocks(sid);
    for (final block in blocks) {
      await db.insert(DatabaseHelper.tableScheduleBlock, block.toMap());
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUSH INDIVIDUAL (lo llaman los providers al crear/editar)
  // Si falla (offline), el is_dirty=1 garantiza reintento después.
  // ─────────────────────────────────────────────────────────────

  Future<void> pushTask(TaskModel task) async {
    if (task.studentId.isEmpty) return;
    try {
      await FirestoreService.instance.uploadTask(_stripLocalPaths(task));
      await DatabaseHelper.instance
          .setDirty(DatabaseHelper.tableTask, task.id, false);
    } catch (e) {
      debugPrint('[Sync] pushTask offline/error (${task.id}), queda dirty: $e');
    }
  }

  Future<void> pushEvent(EventModel event) async {
    if (event.studentId.isEmpty) return;
    try {
      await FirestoreService.instance.uploadEvent(event);
      await DatabaseHelper.instance
          .setDirty(DatabaseHelper.tableEvent, event.id, false);
    } catch (e) {
      debugPrint('[Sync] pushEvent offline/error (${event.id}): $e');
    }
  }

  Future<void> pushStudent(StudentProfile student) async {
    try {
      await FirestoreService.instance.upsertStudent(student);
      await DatabaseHelper.instance
          .setDirty(DatabaseHelper.tableStudent, student.id, false);
    } catch (e) {
      debugPrint('[Sync] pushStudent offline/error (${student.id}): $e');
    }
  }

  /// Las rutas de archivo locales nunca viajan a Firestore:
  /// las imágenes van por Firebase Storage y cada dispositivo
  /// resuelve sus paths localmente (los flags has_* sí viajan).
  TaskModel _stripLocalPaths(TaskModel task) {
    return task.copyWith(
      evidencePhotoPaths: const [],
      referenceImagePaths: const [],
    );
  }
}
