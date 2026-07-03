import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/repositories/task_repository.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/connectivity_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/services/evidence_image_service.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';
import 'package:edutrack_family/core/services/notification_service.dart';
import 'package:edutrack_family/core/services/sync_service.dart';
import '../../main.dart';

// ═══════════════════════════════════════════════════════════════
// TASK PROVIDER — EduTrack Family 2.0
// Tareas SIEMPRE del estudiante activo:
//   sesión de estudiante → sus propias tareas (uid == studentId)
//   sesión de adulto     → las del hijo seleccionado en el selector
// ═══════════════════════════════════════════════════════════════

class TaskNotifier extends StateNotifier<AsyncValue<List<TaskModel>>> {
  TaskNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  final Ref _ref;
  final _repo = TaskRepository.instance;
  final _notifService = NotificationService.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  /// Estudiante cuyo contenido se muestra ahora mismo.
  String? get _scopeStudentId {
    final user = _ref.read(authProvider);
    if (user == null) return null;
    if (user.isStudent) return user.uid;
    return _ref.read(activeStudentProvider)?.id;
  }

  Future<void> loadTasks() async {
    final scope = _scopeStudentId;
    final hasData = state.hasValue;
    if (!hasData) state = const AsyncValue.loading();
    try {
      final tasks = scope == null
          ? <TaskModel>[]
          : await _repo.getAllActiveTasks(studentId: scope);
      state = AsyncValue.data(tasks);
      _checkOverdue(tasks);
    } catch (e, st) {
      if (!hasData) {
        state = AsyncValue.error(e, st);
      } else {
        debugPrint('[TaskProvider] Error recargando tareas: $e');
      }
    }
  }

  void _checkOverdue(List<TaskModel> tasks) async {
    final prefs = _ref.read(sharedPreferencesProvider);

    // Saltar durante la primera sincronización: no spamear vencimientos históricos
    if (!(prefs.getBool('is_first_sync_completed') ?? false)) return;

    final overdue =
        tasks.where((t) => t.isOverdueTask && !t.isCompleted).toList();
    if (overdue.isEmpty) return;

    final notifiedIds =
        Set<String>.from(prefs.getStringList('overdue_notified_ids') ?? []);

    bool changed = false;
    for (final t in overdue) {
      if (notifiedIds.contains(t.id)) continue;
      // Local en este dispositivo; cada dispositivo detecta lo suyo
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🔴 Tarea vencida',
        body: '"${t.title}" ya venció y sigue sin completarse.',
        internalType: NotificationType.taskOverdue,
        channel: NotificationChannel.urgent,
        requireConfirm: true,
        taskId: t.id,
        payload: 'task:${t.id}',
      );
      notifiedIds.add(t.id);
      changed = true;
    }
    if (changed) {
      await prefs.setStringList('overdue_notified_ids', notifiedIds.toList());
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CREAR (padre/profesor → estudiante concreto)
  // ─────────────────────────────────────────────────────────────

  Future<void> createTask({
    required String title,
    required String subject,
    String? description,
    required String category,
    required DateTime dueDate,
    int notificationDaysBefore = 1,
    List<String> referenceImagePaths = const [],
    String? studentId,
  }) async {
    final sid = studentId ?? _scopeStudentId;
    if (sid == null) {
      debugPrint('[TaskProvider] createTask sin estudiante activo');
      return;
    }
    final now = DateTime.now();
    final task = TaskModel(
      id: _uuid.v4(),
      studentId: sid,
      assignedBy: _ref.read(authProvider)?.uid,
      title: title,
      subject: subject,
      description: description,
      category: category,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
      notificationDaysBefore: notificationDaysBefore,
      referenceImagePaths: referenceImagePaths,
      // Flag: avisa que hay imágenes aunque los paths no viajen a Firestore
      hasReferenceImages: referenceImagePaths.isNotEmpty,
    );

    await _repo.createTask(task);
    await _notifService.scheduleForTask(task);

    // Campana local + FCM al dispositivo del estudiante
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📌 Nueva tarea asignada',
      body: '"${task.title}" fue agregada — vence ${_shortDate(task.dueDate)}.',
      internalType: NotificationType.taskAssigned,
      channel: NotificationChannel.system,
      taskId: task.id,
      payload: 'task:${task.id}',
      targetUids: [sid],
    );

    // Imágenes de referencia → Firebase Storage
    if (task.referenceImagePaths.isNotEmpty) {
      await EvidenceImageService.instance.uploadImages(
        studentId: sid,
        taskId: task.id,
        kind: 'reference',
        localPaths: task.referenceImagePaths,
      );
    }

    await _sync.pushTask(task);
    await loadTasks();
  }

  Future<void> updateTask(TaskModel task) async {
    final updated = task.copyWith(updatedAt: DateTime.now());
    await _repo.updateTask(updated);
    await _notifService.cancelForTask(updated.id);
    if (updated.isPending) {
      await _notifService.scheduleForTask(updated);
    }

    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '✏️ Tarea actualizada',
      body: '"${updated.title}" fue modificada.',
      internalType: NotificationType.taskUpdated,
      channel: NotificationChannel.system,
      taskId: updated.id,
      payload: 'task:${updated.id}',
      targetUids: [updated.studentId],
    );

    await loadTasks();

    if (updated.referenceImagePaths.isNotEmpty) {
      EvidenceImageService.instance
          .uploadImages(
        studentId: updated.studentId,
        taskId: updated.id,
        kind: 'reference',
        localPaths: updated.referenceImagePaths,
      )
          .then((_) async {
        await _sync.pushTask(updated);
        await loadTasks();
      });
    } else {
      _sync.pushTask(updated).then((_) => loadTasks());
    }
  }

  Future<void> markCompleted(String taskId, {String? photoPath}) async {
    await _repo.markCompleted(taskId, photoPath: photoPath);
    await _notifService.cancelForTask(taskId);

    final task = await _repo.getTaskById(taskId);
    if (task != null) {
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '✅ Tarea completada',
        body: '"${task.title}" fue marcada como completada.',
        internalType: NotificationType.taskCompleted,
        channel: NotificationChannel.system,
        taskId: task.id,
        payload: 'task:${task.id}',
      );
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) await _sync.pushTask(task);
    }

    await loadTasks();
  }

  // ─────────────────────────────────────────────────────────────
  // FLUJO DE REVISIÓN (estudiante → padres/profesores)
  // ─────────────────────────────────────────────────────────────

  Future<void> submitForReview(
    String taskId, {
    String? photoPath,
    List<String>? photoPaths,
    String? note,
  }) async {
    await _repo.submitForReview(taskId, photoPaths: photoPaths, note: note);
    await _notifService.cancelForTask(taskId);

    final task = await _repo.getTaskById(taskId);
    if (task != null) {
      // Evidencias → Firebase Storage
      if (task.evidencePhotoPaths.isNotEmpty) {
        await EvidenceImageService.instance.uploadImages(
          studentId: task.studentId,
          taskId: task.id,
          kind: 'evidence',
          localPaths: task.evidencePhotoPaths,
        );
      }
      await _sync.pushTask(task);
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '📤 Evidencia recibida',
        body: '"${task.title}" fue enviada a revisión.',
        internalType: NotificationType.evidenceUploaded,
        channel: NotificationChannel.system,
        taskId: task.id,
        payload: 'task:${task.id}',
        targetUids: await NotificationBus.guardianTargets(task.studentId),
      );
    }
    await loadTasks();
  }

  Future<void> acceptTask(String taskId) async {
    await _repo.acceptTask(taskId);

    final task = await _repo.getTaskById(taskId);
    if (task != null) {
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🎉 ¡Tarea aceptada!',
        body: '"${task.title}" fue aprobada. ¡Buen trabajo!',
        internalType: NotificationType.taskAccepted,
        channel: NotificationChannel.system,
        taskId: task.id,
        payload: 'task:${task.id}',
        targetUids: [task.studentId],
      );
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) await _sync.pushTask(task);
    }
    await loadTasks();
  }

  Future<void> rejectTask(String taskId, {String? reason}) async {
    await _repo.rejectTask(taskId, reason: reason);

    final task = await _repo.getTaskById(taskId);
    if (task != null) {
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) await _sync.pushTask(task);
    }
    await loadTasks();
  }

  Future<void> deleteTask(String taskId) async {
    final task = await _repo.getTaskById(taskId);
    await _notifService.cancelForTask(taskId);
    await _repo.deleteTask(taskId);

    // Optimistic update: remove task del estado inmediatamente
    state = state.maybeWhen(
      data: (tasks) =>
          AsyncValue.data(tasks.where((t) => t.id != taskId).toList()),
      orElse: () => state,
    );

    if (task != null) {
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🗑️ Tarea eliminada',
        body: '"${task.title}" fue eliminada del sistema.',
        internalType: NotificationType.taskDeleted,
        channel: NotificationChannel.system,
        taskId: taskId,
        payload: 'task_deleted:$taskId',
        targetUids: [task.studentId],
      );
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) {
        final deletedTask = await _repo.getTaskById(taskId);
        if (deletedTask != null) {
          await _sync.pushTask(deletedTask);
        }
      }
    }

    try {
      await loadTasks();
    } catch (e) {
      debugPrint('[TaskProvider] Error recargando tras delete: $e');
    }
  }

  // Helper para mostrar fecha corta en notificaciones
  String _shortDate(DateTime d) {
    const months = ['ene','feb','mar','abr','may','jun',
                    'jul','ago','sep','oct','nov','dic'];
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> archiveTask(String taskId) async {
    await _repo.archiveTask(taskId);
    await loadTasks();
  }

  Future<Map<String, int>> getStats() =>
      _repo.getStats(studentId: _scopeStudentId);

  List<TaskModel> get pendingTasks {
    return state.maybeWhen(
      data: (tasks) => tasks.where((t) => t.isPending).toList(),
      orElse: () => [],
    );
  }

  List<TaskModel> get urgentTasks {
    return state.maybeWhen(
      data: (tasks) =>
          tasks.where((t) => t.isUrgent && !t.isOverdueTask).toList(),
      orElse: () => [],
    );
  }

  List<TaskModel> get overdueTasks {
    return state.maybeWhen(
      data: (tasks) => tasks.where((t) => t.isOverdueTask).toList(),
      orElse: () => [],
    );
  }

  List<TaskModel> tasksForDate(DateTime date) {
    return state.maybeWhen(
      data: (tasks) => tasks.where((t) {
        return t.dueDate.year == date.year &&
            t.dueDate.month == date.month &&
            t.dueDate.day == date.day;
      }).toList(),
      orElse: () => [],
    );
  }
}

final taskProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<List<TaskModel>>>((ref) {
  final notifier = TaskNotifier(ref);
  // Recargar al cambiar de estudiante activo o de sesión
  ref.listen(activeStudentIdProvider, (_, _) => notifier.loadTasks());
  ref.listen(linkedStudentsProvider, (_, _) => notifier.loadTasks());
  ref.listen(authProvider, (_, _) => notifier.loadTasks());
  return notifier;
});
