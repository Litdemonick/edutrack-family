import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/data/local/repositories/task_repository.dart';
import 'package:edutrack_family/core/data/local/repositories/student_repository.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/connectivity_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/services/evidence_image_service.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';
import 'package:edutrack_family/core/services/notification_service.dart';
import 'package:edutrack_family/core/services/push_queue_service.dart';
import 'package:edutrack_family/core/services/sync_service.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';
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

    // Si ya había tareas visibles y el scope viene momentáneamente
    // null (p. ej. justo al reabrir la app desde una notificación,
    // antes de que auth/estudiantes terminen de restaurarse), no
    // reemplazar la lista por una vacía — eso es lo que causaba el
    // "parpadeo" de tareas que desaparecían y volvían solas. En
    // cuanto el scope real esté listo, el próximo loadTasks() (ya
    // disparado por los mismos ref.listen) las vuelve a traer bien.
    if (scope == null && hasData) return;

    if (!hasData) state = const AsyncValue.loading();
    try {
      final tasks = scope == null
          ? <TaskModel>[]
          : await _repo.getAllActiveTasks(studentId: scope);
      _checkOverdue(tasks);
      // Mismo contenido exacto (mismos ids con el mismo updatedAt) que
      // ya está en pantalla → no reemplazar el estado. Sin esto, cada
      // sync (poll de escritorio, eco en tiempo real, etc.) emitía una
      // lista "nueva" aunque nada hubiera cambiado, y pantallas
      // derivadas (ej. Estadísticas, que anima sus barras desde 0 en
      // cada valor nuevo) parpadeaban/reiniciaban su animación sin
      // motivo real.
      if (hasData && _sameTasks(state.value!, tasks)) return;
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      if (!hasData) {
        state = AsyncValue.error(e, st);
      } else {
        debugPrint('[TaskProvider] Error recargando tareas: $e');
      }
    }
  }

  bool _sameTasks(List<TaskModel> a, List<TaskModel> b) {
    if (a.length != b.length) return false;
    final byId = {for (final t in a) t.id: t.updatedAt};
    for (final t in b) {
      final prevUpdatedAt = byId[t.id];
      if (prevUpdatedAt == null || prevUpdatedAt != t.updatedAt) return false;
    }
    return true;
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

  /// Avisa (solo push, sin tocar la campana propia del actor — eso ya
  /// lo hizo el dispatch al estudiante) al OTRO adulto vinculado al
  /// estudiante (el padre/tutor si actuó el profesor, o viceversa)
  /// de que se creó/editó/eliminó una tarea — mencionando quién lo
  /// hizo y de qué estudiante se trata. Como editar/eliminar una
  /// tarea ya está restringido a quien la creó (ver firestore.rules),
  /// [actorUid]/[actorRole] siempre coinciden con quien puede haber
  /// hecho la acción.
  Future<void> _notifyOtherAdults({
    required String studentId,
    required String actorUid,
    required String? actorRole,
    required String action,
    required String taskId,
  }) async {
    final student = await StudentRepository.instance.getById(studentId);
    if (student == null) return;

    final otherParents = student.parentIds.where((u) => u != actorUid).toList();
    final otherTeachers = student.teacherIds.where((u) => u != actorUid).toList();
    final payload = 'task:$taskId';

    if (otherParents.isNotEmpty) {
      await PushQueueService.instance.sendToUids(
        otherParents,
        title: '📌 Tarea',
        body: RoleCopy.otherAdultActionText(
            actorRole, UserRole.parent, student.name, action),
        data: {'payload': payload},
      );
    }
    if (otherTeachers.isNotEmpty) {
      await PushQueueService.instance.sendToUids(
        otherTeachers,
        title: '📌 Tarea',
        body: RoleCopy.otherAdultActionText(
            actorRole, UserRole.teacher, student.name, action),
        data: {'payload': payload},
      );
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
    final creator = _ref.read(authProvider);
    final now = DateTime.now();
    final task = TaskModel(
      id: _uuid.v4(),
      studentId: sid,
      assignedBy: creator?.uid,
      assignedByRole: creator?.role.name,
      assignedByName: creator?.displayName,
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
      body: '${RoleCopy.actorLabelForStudent(creator?.role.name)} agregó '
          '"${task.title}" — vence ${_shortDate(task.dueDate)}.',
      internalType: NotificationType.taskAssigned,
      channel: NotificationChannel.system,
      taskId: task.id,
      payload: 'task:${task.id}',
      targetUids: [sid],
      actorTitle: '📌 Tarea creada',
      actorBody: 'Acabas de agregar "${task.title}" — vence '
          '${_shortDate(task.dueDate)}.',
    );

    // Avisar al OTRO adulto vinculado (el que no la creó) — con la
    // app abierta, el eco de Firestore en app.dart ya le completa la
    // campana; esto cubre además su push con la app cerrada/en
    // segundo plano.
    await _notifyOtherAdults(
      studentId: sid,
      actorUid: creator?.uid ?? '',
      actorRole: creator?.role.name,
      action: 'agregó una nueva tarea "${task.title}"',
      taskId: task.id,
    );

    // Imágenes de referencia → Cloudflare R2 (vía el Worker)
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

    final actor = _ref.read(authProvider);
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '✏️ Tarea actualizada',
      body: '${RoleCopy.actorLabelForStudent(actor?.role.name)} modificó '
          '"${updated.title}".',
      internalType: NotificationType.taskUpdated,
      channel: NotificationChannel.system,
      taskId: updated.id,
      payload: 'task:${updated.id}',
      targetUids: [updated.studentId],
      actorTitle: '✏️ Tarea actualizada',
      actorBody: 'Acabas de actualizar "${updated.title}".',
    );

    await _notifyOtherAdults(
      studentId: updated.studentId,
      actorUid: actor?.uid ?? '',
      actorRole: actor?.role.name,
      action: 'actualizó la tarea "${updated.title}"',
      taskId: updated.id,
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
        // Antes esto solo quedaba en la campana del propio estudiante —
        // padres/profesores nunca se enteraban si la tarea no pasaba
        // por revisión (sin evidencia adjunta).
        targetUids: await NotificationBus.guardianTargets(task.studentId),
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
      // Evidencias → Cloudflare R2 (vía el Worker). Versionada por
      // completedAt (este envío específico) — así el Historial puede
      // seguir mostrando las fotos de cada envío por separado, en vez
      // de que cada reenvío borre las del anterior.
      if (task.evidencePhotoPaths.isNotEmpty) {
        await EvidenceImageService.instance.uploadImages(
          studentId: task.studentId,
          taskId: task.id,
          kind: 'evidence',
          localPaths: task.evidencePhotoPaths,
          version: task.completedAt!.millisecondsSinceEpoch.toString(),
        );
      }
      await _sync.pushTask(task);
      final assignerLabel = RoleCopy.assignedByLabel(task.assignedByRole);
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '📤 Evidencia recibida',
        body: assignerLabel != null
            ? '"${task.title}" (tarea de $assignerLabel) fue enviada a revisión.'
            : '"${task.title}" fue enviada a revisión.',
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
      // Ya se aprobó — el historial de idas y vueltas ya se limpió en
      // el repo; borrar también las fotos (evidencia, todas las
      // versiones, Y referencia) en R2 para que no se acumulen
      // indefinidamente en el storage remoto.
      await EvidenceImageService.instance.deleteAllTaskImages(
        studentId: task.studentId,
        taskId: task.id,
      );
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

  /// Verifica contra Firestore (no el cache local, que puede tardar
  /// unos segundos en enterarse de un borrado hecho desde otro
  /// dispositivo) si la tarea sigue vigente. Se llama justo antes de
  /// dejar completar una acción sobre ella (enviar evidencia,
  /// aprobar/rechazar, editar) para no procesar algo sobre una tarea
  /// que otro adulto ya eliminó mientras el sync todavía no llegaba.
  /// Si ya no existe o está marcada eliminada, sincroniza el estado
  /// local (para que desaparezca de la lista) y devuelve false.
  Future<bool> isTaskStillActive(TaskModel task) async {
    try {
      final data = await FirestoreService.instance
          .getRawDoc(FirestorePaths.task(task.studentId, task.id));
      final isDeletedRemotely = data == null || data['is_deleted'] == true;
      if (isDeletedRemotely) {
        await _repo.deleteTask(task.id);
        await loadTasks();
        return false;
      }
      return true;
    } catch (e) {
      // Sin red o error transitorio: no bloquear al usuario por un
      // problema de conectividad, dejar pasar la acción.
      debugPrint('[TaskProvider] isTaskStillActive no se pudo verificar: $e');
      return true;
    }
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
      // Tarea eliminada — ya no queda ningún Historial que mostrar,
      // borrar también sus fotos (evidencia, todas las versiones, Y
      // referencia) en R2 para no dejarlas huérfanas para siempre.
      await EvidenceImageService.instance.deleteAllTaskImages(
        studentId: task.studentId,
        taskId: task.id,
      );
      final actor = _ref.read(authProvider);
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🗑️ Tarea eliminada',
        body: '${RoleCopy.actorLabelForStudent(actor?.role.name)} eliminó '
            '"${task.title}" del sistema.',
        internalType: NotificationType.taskDeleted,
        channel: NotificationChannel.system,
        taskId: taskId,
        payload: 'task_deleted:$taskId',
        targetUids: [task.studentId],
        actorTitle: '🗑️ Tarea eliminada',
        actorBody: 'Acabas de eliminar "${task.title}".',
      );
      await _notifyOtherAdults(
        studentId: task.studentId,
        actorUid: actor?.uid ?? '',
        actorRole: actor?.role.name,
        action: 'eliminó la tarea "${task.title}"',
        taskId: taskId,
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
