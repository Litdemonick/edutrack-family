import 'dart:async';
import 'dart:math' as math;

import '../database/database_helper.dart';
import '../data/local/models/event_model.dart';
import '../data/local/models/schedule_block_model.dart';
import '../data/local/models/student_model.dart';
import '../data/local/models/task_model.dart';
import '../firebase/firestore_service.dart';
import '../utils/app_log.dart';

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

  // Igual que _firstSnapshot, pero para el pull REST (_pullTasks/
  // _pullEvents, usado por initialSync() Y por el fullSync()
  // periódico de respaldo cada 45s) — sin esto, ese pull silencioso
  // insertaba tareas/eventos nuevos en SQLite SIN avisar a nadie
  // (ni campana ni refresco de pantalla), y si le ganaba la carrera
  // al listener en tiempo real (algo normal, corre apenas entrás y
  // cada 45s), el listener llegaba después, veía el dato "ya
  // insertado" y tampoco avisaba — doble silencio.
  final Map<String, bool> _hasPulledBefore = {};

  // Reconexión con backoff cuando un stream de Firestore muere
  // (onError). Sin esto, un listener caído se quedaba muerto hasta
  // el próximo restart de la app — el único "arreglo" era esperar
  // al refresco periódico de 45s. Con esto, se reintenta solo en
  // 2s, 4s, 8s... hasta un techo de 20s (siempre antes que ese
  // refresco periódico, que queda solo como red de respaldo extra).
  int _syncGeneration = 0;
  final Map<String, int> _retryAttempts = {};
  final Map<String, Timer> _reconnectTimers = {};

  Function(TaskModel task)? _onNewTaskReceived;
  Function(TaskModel oldTask, TaskModel newTask)? _onTaskUpdated;
  Function(EventModel event)? _onNewEventReceived;
  Function(EventModel oldEvent, EventModel newEvent)? _onEventUpdated;
  Function(ScheduleBlock block)? _onScheduleBlockAdded;
  Function(ScheduleBlock oldBlock, ScheduleBlock newBlock)? _onScheduleBlockUpdated;
  Function()? _onTasksUpdated;
  Function()? _onEventsUpdated;

  void _scheduleReconnect(
    String key,
    String sid,
    int generation,
    void Function() reconnect,
  ) {
    if (generation != _syncGeneration) return;
    _reconnectTimers[key]?.cancel();
    final attempt = (_retryAttempts[key] ?? 0) + 1;
    _retryAttempts[key] = attempt;
    final delaySeconds = math.min(20, 1 << attempt); // 2,4,8,16,20,20...
    AppLog.d('[Sync] reconectando $key en ${delaySeconds}s (intento $attempt)');
    _reconnectTimers[key] = Timer(Duration(seconds: delaySeconds), () {
      if (generation != _syncGeneration) return;
      if (!_studentIds.contains(sid)) return;
      reconnect();
    });
  }

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
      AppLog.d('[Sync] initialSync falló: $e');
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
    Function(EventModel event)? onNewEventReceived,
    Function(EventModel oldEvent, EventModel newEvent)? onEventUpdated,
    Function(ScheduleBlock block)? onScheduleBlockAdded,
    Function(ScheduleBlock oldBlock, ScheduleBlock newBlock)? onScheduleBlockUpdated,
    required Function() onTasksUpdated,
    required Function() onEventsUpdated,
  }) {
    // Los callbacks se refrescan siempre (son closures nuevas cada
    // llamada, baratas de reasignar). Pero si las suscripciones YA
    // están activas para exactamente el mismo conjunto de
    // estudiantes, no las tiramos y las rearmamos — eso reiniciaba
    // "isFirst" a mitad de camino cada vez que algo volvía a llamar a
    // este método (ej. un `resumed` espurio del ciclo de vida justo al
    // abrir la app en Windows), y si un cambio real llegaba justo en
    // ese instante, el reinicio lo hacía pasar como "ya estaba" en vez
    // de "nuevo" — silenciando esa notificación por pura casualidad
    // de timing. Confirmado con logs: isFirst true→true→false→true en
    // segundos, sin que _studentIds cambiara.
    _onNewTaskReceived = onNewTaskReceived;
    _onTaskUpdated = onTaskUpdated;
    _onNewEventReceived = onNewEventReceived;
    _onEventUpdated = onEventUpdated;
    _onScheduleBlockAdded = onScheduleBlockAdded;
    _onScheduleBlockUpdated = onScheduleBlockUpdated;
    _onTasksUpdated = onTasksUpdated;
    _onEventsUpdated = onEventsUpdated;

    final currentSids = _taskSubs.keys.toSet();
    final wantedSids = _studentIds.toSet();
    if (currentSids.isNotEmpty &&
        currentSids.length == wantedSids.length &&
        currentSids.containsAll(wantedSids)) {
      AppLog.d('[Sync] startRealtimeSync: ya activo para los mismos '
          '${wantedSids.length} estudiante(s), no se rearma.');
      return;
    }

    stopRealtimeSync();
    final generation = _syncGeneration;

    for (final sid in _studentIds) {
      _firstSnapshot['tasks_$sid'] = true;
      _firstSnapshot['events_$sid'] = true;
      _firstSnapshot['schedule_$sid'] = true;
      _subscribeTasks(sid, generation);
      _subscribeEvents(sid, generation);
      _subscribeSchedule(sid, generation);
    }
  }

  void _subscribeTasks(String sid, int generation) {
    _taskSubs[sid]?.cancel();
    _taskSubs[sid] =
        FirestoreService.instance.watchTasks(sid).listen((remoteTasks) async {
      _retryAttempts.remove('tasks_$sid');
      final isFirst = _firstSnapshot['tasks_$sid'] ?? true;
      _firstSnapshot['tasks_$sid'] = false;
      if (isFirst) {
        AppLog.d('[Sync] ✅ tasks($sid) LISTO — línea base establecida '
            '(${remoteTasks.length} docs). Cualquier cambio DE ACÁ EN '
            'ADELANTE sí va a notificar.');
      }

      final db = DatabaseHelper.instance;
      final localRows = await db.queryAll(
        DatabaseHelper.tableTask,
        where: 'student_id = ?',
        whereArgs: [sid],
      );
      final localById = {
        for (final row in localRows) row['id'] as String: TaskModel.fromMap(row)
      };

      AppLog.d('[Sync] tasks($sid) snapshot: ${remoteTasks.length} docs, isFirst=$isFirst');
      var changed = false;
      for (final remote in remoteTasks) {
        final local = localById[remote.id];
        if (local == null) {
          await db.insert(DatabaseHelper.tableTask, remote.toMap());
          changed = true;
          final shouldNotify = !isFirst && !remote.isDeleted && remote.isPending;
          AppLog.d('[Sync] tasks($sid): nueva tarea ${remote.id} '
              '(isFirst=$isFirst, isDeleted=${remote.isDeleted}, '
              'isPending=${remote.isPending}, shouldNotify=$shouldNotify, '
              'callback=${_onNewTaskReceived != null})');
          if (shouldNotify && _onNewTaskReceived != null) {
            _onNewTaskReceived!(remote);
          }
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
          changed = true;
          if (!isFirst && _onTaskUpdated != null) {
            _onTaskUpdated!(local, remote);
          }
        }
      }
      if (changed) _onTasksUpdated?.call();
    }, onError: (e) {
      AppLog.d('[Sync] stream tasks($sid): $e');
      _scheduleReconnect(
          'tasks_$sid', sid, generation, () => _subscribeTasks(sid, generation));
    });
  }

  void _subscribeEvents(String sid, int generation) {
    _eventSubs[sid]?.cancel();
    _eventSubs[sid] =
        FirestoreService.instance.watchEvents(sid).listen((remoteEvents) async {
      _retryAttempts.remove('events_$sid');
      final isFirst = _firstSnapshot['events_$sid'] ?? true;
      _firstSnapshot['events_$sid'] = false;
      if (isFirst) {
        AppLog.d('[Sync] ✅ events($sid) LISTO — línea base establecida '
            '(${remoteEvents.length} docs). Cualquier cambio DE ACÁ EN '
            'ADELANTE sí va a notificar.');
      }

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
          if (!isFirst && !remote.isDeleted && _onNewEventReceived != null) {
            _onNewEventReceived!(remote);
          }
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(
              DatabaseHelper.tableEvent, remote.toMap(), remote.id);
          changed = true;
          if (!isFirst && _onEventUpdated != null) {
            _onEventUpdated!(local, remote);
          }
        }
      }
      if (changed) _onEventsUpdated?.call();
    }, onError: (e) {
      AppLog.d('[Sync] stream events($sid): $e');
      _scheduleReconnect('events_$sid', sid, generation,
          () => _subscribeEvents(sid, generation));
    });
  }

  void _subscribeSchedule(String sid, int generation) {
    _scheduleSubs[sid]?.cancel();
    _scheduleSubs[sid] = FirestoreService.instance
        .watchScheduleBlocks(sid)
        .listen((remoteBlocks) async {
      _retryAttempts.remove('schedule_$sid');
      final isFirst = _firstSnapshot['schedule_$sid'] ?? true;
      _firstSnapshot['schedule_$sid'] = false;

      final db = DatabaseHelper.instance;
      final localRows = await db.queryAll(
        DatabaseHelper.tableScheduleBlock,
        where: 'student_id = ?',
        whereArgs: [sid],
      );
      final localById = {
        for (final row in localRows)
          row['id'] as String: ScheduleBlock.fromMap(row)
      };

      for (final remote in remoteBlocks) {
        final local = localById[remote.id];
        await db.insert(DatabaseHelper.tableScheduleBlock, remote.toMap());
        if (isFirst) continue;
        if (local == null) {
          if (!remote.isDeleted) _onScheduleBlockAdded?.call(remote);
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          _onScheduleBlockUpdated?.call(local, remote);
        }
      }
    }, onError: (e) {
      AppLog.d('[Sync] stream schedule($sid): $e');
      _scheduleReconnect('schedule_$sid', sid, generation,
          () => _subscribeSchedule(sid, generation));
    });
  }

  void stopRealtimeSync() {
    _syncGeneration++;
    for (final sub in _taskSubs.values) {
      sub.cancel();
    }
    for (final sub in _eventSubs.values) {
      sub.cancel();
    }
    for (final sub in _scheduleSubs.values) {
      sub.cancel();
    }
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _taskSubs.clear();
    _eventSubs.clear();
    _scheduleSubs.clear();
    _firstSnapshot.clear();
    _reconnectTimers.clear();
    _retryAttempts.clear();
  }

  /// Se llama al cerrar sesión — a diferencia de stopRealtimeSync(),
  /// esto también resetea la marca de "primer pull" del sync
  /// periódico/inicial, para que una sesión nueva (mismo u otro
  /// usuario) no trate el backlog completo como "cambios nuevos" y
  /// bombardee de notificaciones al volver a loguearse.
  void resetPullState() {
    _hasPulledBefore.clear();
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
      AppLog.d('[Sync] fullSync falló: $e');
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
        AppLog.d('[Sync] push dirty task ${task.id}: $e');
      }
    }

    for (final row in await db.queryDirty(DatabaseHelper.tableEvent)) {
      final event = EventModel.fromMap(row);
      if (event.studentId.isEmpty) continue;
      try {
        await FirestoreService.instance.uploadEvent(event);
        await db.setDirty(DatabaseHelper.tableEvent, event.id, false);
      } catch (e) {
        AppLog.d('[Sync] push dirty event ${event.id}: $e');
      }
    }

    for (final row in await db.queryDirty(DatabaseHelper.tableScheduleBlock)) {
      final block = ScheduleBlock.fromMap(row);
      try {
        await FirestoreService.instance.uploadScheduleBlock(block);
        await db.setDirty(DatabaseHelper.tableScheduleBlock, block.id, false);
      } catch (e) {
        AppLog.d('[Sync] push dirty block ${block.id}: $e');
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

    final isFirstPull = !(_hasPulledBefore['tasks_$sid'] ?? false);
    _hasPulledBefore['tasks_$sid'] = true;
    AppLog.d('[Sync] _pullTasks($sid): ${remoteTasks.length} docs desde '
        '$since, isFirstPull=$isFirstPull');

    for (final remote in remoteTasks) {
      final localRow = await db.queryById(DatabaseHelper.tableTask, remote.id);
      if (localRow == null) {
        await db.insert(DatabaseHelper.tableTask, remote.toMap());
        final shouldNotify = !isFirstPull && !remote.isDeleted && remote.isPending;
        AppLog.d('[Sync] _pullTasks($sid): tarea nueva ${remote.id} '
            'shouldNotify=$shouldNotify callback=${_onNewTaskReceived != null}');
        if (shouldNotify && _onNewTaskReceived != null) {
          _onNewTaskReceived!(remote);
        }
      } else {
        final local = TaskModel.fromMap(localRow);
        final isDirty = (localRow['is_dirty'] ?? 0) == 1;
        // No pisar cambios locales pendientes de subir
        if (!isDirty && remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
          if (!isFirstPull && _onTaskUpdated != null) {
            _onTaskUpdated!(local, remote);
          }
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

    final isFirstPull = !(_hasPulledBefore['events_$sid'] ?? false);
    _hasPulledBefore['events_$sid'] = true;
    AppLog.d('[Sync] _pullEvents($sid): ${remoteEvents.length} docs desde '
        '$since, isFirstPull=$isFirstPull');

    for (final remote in remoteEvents) {
      final localRow = await db.queryById(DatabaseHelper.tableEvent, remote.id);
      if (localRow == null) {
        await db.insert(DatabaseHelper.tableEvent, remote.toMap());
        final shouldNotify = !isFirstPull && !remote.isDeleted;
        AppLog.d('[Sync] _pullEvents($sid): evento nuevo ${remote.id} '
            'shouldNotify=$shouldNotify callback=${_onNewEventReceived != null}');
        if (shouldNotify && _onNewEventReceived != null) {
          _onNewEventReceived!(remote);
        }
      } else {
        final local = EventModel.fromMap(localRow);
        final isDirty = (localRow['is_dirty'] ?? 0) == 1;
        if (!isDirty && remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableEvent, remote.toMap(), remote.id);
          if (!isFirstPull && _onEventUpdated != null) {
            _onEventUpdated!(local, remote);
          }
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
      AppLog.d('[Sync] pushTask offline/error (${task.id}), queda dirty: $e');
    }
  }

  Future<void> pushEvent(EventModel event) async {
    if (event.studentId.isEmpty) return;
    try {
      await FirestoreService.instance.uploadEvent(event);
      await DatabaseHelper.instance
          .setDirty(DatabaseHelper.tableEvent, event.id, false);
    } catch (e) {
      AppLog.d('[Sync] pushEvent offline/error (${event.id}): $e');
    }
  }

  Future<void> pushStudent(StudentProfile student) async {
    try {
      await FirestoreService.instance.upsertStudent(student);
      await DatabaseHelper.instance
          .setDirty(DatabaseHelper.tableStudent, student.id, false);
    } catch (e) {
      AppLog.d('[Sync] pushStudent offline/error (${student.id}): $e');
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
