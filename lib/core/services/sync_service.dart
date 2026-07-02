import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:edutrack_family/core/data/local/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/remote/firestore_service.dart';
import 'package:edutrack_family/core/data/local/repositories/event_repository.dart';

// ═══════════════════════════════════════════════════════════════
// SYNC SERVICE — EduTrack Family
// Sincronización bidireccional SQLite ↔ Firestore.
//
// Estrategia de conflictos: "last modified wins" por updatedAt.
//   - Solo existe local   → push a Firestore
//   - Solo existe remoto  → insert en SQLite
//   - Ambos existen       → gana el updatedAt más reciente
//   - Timestamps iguales  → sin acción (ya están sincronizados)
// ═══════════════════════════════════════════════════════════════

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  bool _isFirstSnapshot = true;

  StreamSubscription? _tasksSub;
  StreamSubscription? _eventsSub;

  // ─────────────────────────────────────────────────────────────
  // CARGA INICIAL — descarga todo lo que hay en Firestore a SQLite
  // Se llama al hacer login o al reinstalar la app.
  // ─────────────────────────────────────────────────────────────

  Future<void> initialSync({
    required Function() onTasksUpdated,
    required Function() onEventsUpdated,
  }) async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      await _pullAllTasks();
      await _pullAllEvents();
      onTasksUpdated();
      onEventsUpdated();
    } catch (e) {
      debugPrint('[Sync] initialSync falló: $e');
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _pullAllTasks() async {
    final remoteTasks = await FirestoreService.instance.downloadAllTasks();
    if (remoteTasks.isEmpty) return;

    final db = DatabaseHelper.instance;
    final allLocalRows = await db.queryAll(DatabaseHelper.tableTask);
    final localById = {
      for (final r in allLocalRows) r['id'] as String: r
    };

    for (final remote in remoteTasks) {
      try {
        final localRow = localById[remote.id];
        if (localRow == null) {
          await db.insert(DatabaseHelper.tableTask, remote.toMap());
        } else {
          final localUpdatedAt = DateTime.parse(localRow['updated_at'] as String);
          if (remote.updatedAt.isAfter(localUpdatedAt)) {
            await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
          }
        }
      } catch (_) {
        // Error en un registro individual: seguimos con el resto
      }
    }
  }

  Future<void> _pullAllEvents() async {
    final remoteEvents = await FirestoreService.instance.downloadAllEvents();
    if (remoteEvents.isEmpty) return;

    final db = DatabaseHelper.instance;
    final allLocalRows = await db.queryAll(DatabaseHelper.tableEvent);
    final localById = {
      for (final r in allLocalRows) r['id'] as String: r
    };

    for (final remote in remoteEvents) {
      try {
        final localRow = localById[remote.id];
        if (localRow == null) {
          await db.insert(DatabaseHelper.tableEvent, remote.toMap());
        } else {
          final localUpdatedAt = DateTime.parse(localRow['updated_at'] as String);
          if (remote.updatedAt.isAfter(localUpdatedAt)) {
            await db.update(DatabaseHelper.tableEvent, remote.toMap(), remote.id);
          }
        }
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SINCRONIZACIÓN EN TIEMPO REAL
  // ─────────────────────────────────────────────────────────────

  void startRealtimeSync({
    required Function(TaskModel) onNewTaskReceived,
    Function(TaskModel, TaskModel)? onTaskUpdated,
    required Function() onTasksUpdated,
    required Function() onEventsUpdated,
  }) {
    // Cancelar streams previos antes de crear nuevos
    _tasksSub?.cancel();
    _eventsSub?.cancel();
    _isFirstSnapshot = true;

    _tasksSub = FirestoreService.instance.watchTasks().listen(
      (remoteTasks) async {
        final db = DatabaseHelper.instance;
        final allLocalRows = await db.queryAll(DatabaseHelper.tableTask);
        final localTasks = <TaskModel>[];
        for (final row in allLocalRows) {
          try {
            localTasks.add(TaskModel.fromMap(row));
          } catch (_) {}
        }
        final localById = {for (final t in localTasks) t.id: t};

        bool hasChanges = false;
        for (final remote in remoteTasks) {
          try {
            final local = localById[remote.id];
            if (local == null) {
              await db.insert(DatabaseHelper.tableTask, remote.toMap());
              hasChanges = true;
              if (!remote.isDeleted && remote.isPending) {
                if (!_isFirstSnapshot) {
                  onNewTaskReceived(remote);
                }
              }
            } else if (remote.updatedAt.isAfter(local.updatedAt)) {
              await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
              hasChanges = true;
              if (!_isFirstSnapshot) {
                onTaskUpdated?.call(local, remote);
              }
            }
          } catch (_) {}
        }
        _isFirstSnapshot = false;
        if (hasChanges) onTasksUpdated();
      },
      onError: (_) {
        // Error en el stream: no hacer nada, se auto-reconecta
      },
    );

    _eventsSub = FirestoreService.instance.watchEvents().listen(
      (remoteEvents) async {
        final db = DatabaseHelper.instance;
        final localRows = await db.queryAll(DatabaseHelper.tableEvent);
        final localEvents = <EventModel>[];
        for (final row in localRows) {
          try {
            localEvents.add(EventModel.fromMap(row));
          } catch (_) {}
        }
        final localById = {for (final e in localEvents) e.id: e};

        bool hasChanges = false;
        for (final remote in remoteEvents) {
          try {
            final local = localById[remote.id];
            if (local == null) {
              await db.insert(DatabaseHelper.tableEvent, remote.toMap());
              hasChanges = true;
            } else if (remote.updatedAt.isAfter(local.updatedAt)) {
              await db.update(DatabaseHelper.tableEvent, remote.toMap(), remote.id);
              hasChanges = true;
            }
          } catch (_) {}
        }
        if (hasChanges) onEventsUpdated();
      },
      onError: (_) {},
    );
  }

  void stopRealtimeSync() {
    _tasksSub?.cancel();
    _tasksSub = null;
    _eventsSub?.cancel();
    _eventsSub = null;
  }

  // ─────────────────────────────────────────────────────────────
  // SINCRONIZACIÓN COMPLETA (bidireccional, para uso interno)
  // ─────────────────────────────────────────────────────────────

  Future<bool> fullSync() async {
    if (_isSyncing) return false;
    _isSyncing = true;
    try {
      await _syncTasks();
      await _syncEvents();
      return true;
    } catch (e) {
      debugPrint('[Sync] fullSync falló: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncTasks() async {
    final remoteTasks = await FirestoreService.instance.downloadAllTasks();
    final allLocalRows = await DatabaseHelper.instance.queryAll(DatabaseHelper.tableTask);
    final localTasks = <TaskModel>[];
    for (final row in allLocalRows) {
      try { localTasks.add(TaskModel.fromMap(row)); } catch (_) {}
    }

    final remoteById = {for (final t in remoteTasks) t.id: t};
    final localById = {for (final t in localTasks) t.id: t};
    final db = DatabaseHelper.instance;

    for (final local in localTasks) {
      try {
        final remote = remoteById[local.id];
        if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
          // Solo mandar rutas http a Firestore (las locales las maneja ImageTransferService)
          final firestoreTask = local.copyWith(
            referenceImagePaths: local.referenceImagePaths
                .where((p) => p.startsWith('http'))
                .toList(),
            evidencePhotoPaths: local.evidencePhotoPaths
                .where((p) => p.startsWith('http'))
                .toList(),
          );
          await FirestoreService.instance.uploadTask(firestoreTask);
        }
      } catch (_) {}
    }

    for (final remote in remoteTasks) {
      try {
        final local = localById[remote.id];
        if (local == null) {
          await db.insert(DatabaseHelper.tableTask, remote.toMap());
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableTask, remote.toMap(), remote.id);
        }
      } catch (_) {}
    }
  }

  Future<void> _syncEvents() async {
    final remoteEvents = await FirestoreService.instance.downloadAllEvents();
    final localEvents = await EventRepository.instance.getAllEvents();

    final remoteById = {for (final e in remoteEvents) e.id: e};
    final localById = {for (final e in localEvents) e.id: e};
    final db = DatabaseHelper.instance;

    for (final local in localEvents) {
      try {
        final remote = remoteById[local.id];
        if (remote == null || local.updatedAt.isAfter(remote.updatedAt)) {
          await FirestoreService.instance.uploadEvent(local);
        }
      } catch (_) {}
    }

    for (final remote in remoteEvents) {
      try {
        final local = localById[remote.id];
        if (local == null) {
          await db.insert(DatabaseHelper.tableEvent, remote.toMap());
        } else if (remote.updatedAt.isAfter(local.updatedAt)) {
          await db.update(DatabaseHelper.tableEvent, remote.toMap(), remote.id);
        }
      } catch (_) {}
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PUSH INDIVIDUAL — llamado al crear / editar / completar
  // ─────────────────────────────────────────────────────────────

  Future<void> pushTask(TaskModel task) async {
    try {
      // Filtrar rutas locales - solo rutas http van a Firestore.
      // copyWith() preserva los flags hasReferenceImages/hasEvidenceImages
      // aunque los paths queden vacios, garantizando que el otro dispositivo
      // sepa que debe descargar las imagenes de la coleccion task_images.
      final firestoreTask = task.copyWith(
        referenceImagePaths: task.referenceImagePaths
            .where((p) => p.startsWith('http'))
            .toList(),
        evidencePhotoPaths: task.evidencePhotoPaths
            .where((p) => p.startsWith('http'))
            .toList(),
      );
      await FirestoreService.instance.uploadTask(firestoreTask);
    } catch (e) {
      debugPrint('[Sync] pushTask error para ${task.id}: $e');
    }
  }

  Future<void> pushEvent(EventModel event) async {
    try {
      await FirestoreService.instance.uploadEvent(event);
    } catch (e) {
      debugPrint('[Sync] pushEvent error para ${event.id}: $e');
    }
  }

}
