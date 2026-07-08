import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/data/local/repositories/event_repository.dart';
import 'package:edutrack_family/core/data/local/repositories/student_repository.dart';
import 'package:edutrack_family/core/services/sync_service.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';
import 'package:edutrack_family/core/services/push_queue_service.dart';
import 'package:edutrack_family/core/constants/utils/notification_utils.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/connectivity_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT PROVIDER — EduTrack Family 2.0
// Eventos del estudiante activo (multi-tenant).
// ═══════════════════════════════════════════════════════════════

class EventNotifier extends StateNotifier<AsyncValue<List<EventModel>>> {
  EventNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  final Ref _ref;
  final _repo = EventRepository.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  /// Estudiante cuyo contenido se muestra ahora mismo.
  String? get _scopeStudentId {
    final user = _ref.read(authProvider);
    if (user == null) return null;
    if (user.isStudent) return user.uid;
    return _ref.read(activeStudentProvider)?.id;
  }

  Future<void> loadEvents() async {
    final scope = _scopeStudentId;
    final hasData = state.hasValue;

    // Mismo resguardo que taskProvider: no vaciar eventos ya
    // visibles por un scope momentáneamente null.
    if (scope == null && hasData) return;

    if (!hasData) state = const AsyncValue.loading();
    try {
      final events = scope == null
          ? <EventModel>[]
          : await _repo.getAllEvents(studentId: scope);
      // Mismo contenido exacto que ya está en pantalla → no reemplazar
      // el estado (evita parpadeos/reanimaciones en pantallas
      // derivadas por syncs que no trajeron cambios reales).
      if (hasData && _sameEvents(state.value!, events)) return;
      state = AsyncValue.data(events);
    } catch (e, st) {
      if (!hasData) {
        state = AsyncValue.error(e, st);
      } else {
        AppLog.d('[EventProvider] Error recargando eventos: $e');
      }
    }
  }

  bool _sameEvents(List<EventModel> a, List<EventModel> b) {
    if (a.length != b.length) return false;
    final byId = {for (final e in a) e.id: e.updatedAt};
    for (final e in b) {
      final prevUpdatedAt = byId[e.id];
      if (prevUpdatedAt == null || prevUpdatedAt != e.updatedAt) return false;
    }
    return true;
  }

  /// Avisa (solo push, sin tocar la campana propia del actor) al
  /// OTRO adulto vinculado al estudiante de que se creó/editó/
  /// eliminó un evento — mismo patrón que `_notifyOtherAdults` en
  /// task_provider.dart (editar/eliminar un evento ya está
  /// restringido a quien lo creó, así que assignedBy es confiable).
  Future<void> _notifyOtherAdults({
    required String studentId,
    required String actorUid,
    required String? actorRole,
    required String action,
    required String eventId,
  }) async {
    final student = await StudentRepository.instance.getById(studentId);
    if (student == null) return;

    final otherParents = student.parentIds.where((u) => u != actorUid).toList();
    final otherTeachers = student.teacherIds.where((u) => u != actorUid).toList();
    final payload = 'event:$eventId';

    if (otherParents.isNotEmpty) {
      await PushQueueService.instance.sendToUids(
        otherParents,
        title: '📅 Evento',
        body: RoleCopy.otherAdultActionText(
            actorRole, UserRole.parent, student.name, action),
        data: {'payload': payload},
      );
    }
    if (otherTeachers.isNotEmpty) {
      await PushQueueService.instance.sendToUids(
        otherTeachers,
        title: '📅 Evento',
        body: RoleCopy.otherAdultActionText(
            actorRole, UserRole.teacher, student.name, action),
        data: {'payload': payload},
      );
    }
  }

  Future<void> createEvent({
    required String title,
    String? description,
    required EventType type,
    required DateTime date,
    DateTime? endDate,
    bool isAllDay = true,
    int reminderMinutesBefore = 60,
    String? studentId,
  }) async {
    final sid = studentId ?? _scopeStudentId;
    if (sid == null) {
      AppLog.d('[EventProvider] createEvent sin estudiante activo');
      return;
    }
    final creator = _ref.read(authProvider);
    final now = DateTime.now();
    final event = EventModel(
      id: _uuid.v4(),
      studentId: sid,
      title: title,
      description: description,
      type: type,
      date: date,
      endDate: endDate,
      isAllDay: isAllDay,
      createdAt: now,
      updatedAt: now,
      reminderMinutesBefore: reminderMinutesBefore,
      assignedBy: creator?.uid,
      assignedByRole: creator?.role.name,
      assignedByName: creator?.displayName,
    );

    await _repo.createEvent(event);

    // Doble capa: Admin (local) + Estudiante (FCM)
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📅 Nuevo evento',
      body: '${RoleCopy.actorLabelForStudent(creator?.role.name)} agregó '
          '"${event.title}" al calendario.',
      internalType: NotificationType.eventCreated,
      channel: NotificationChannel.system,
      eventId: event.id,
      payload: 'event:${event.id}',
      targetUids: [sid],
      actorTitle: '📅 Evento creado',
      actorBody: 'Acabas de agregar "${event.title}" al calendario.',
    );

    await _notifyOtherAdults(
      studentId: sid,
      actorUid: creator?.uid ?? '',
      actorRole: creator?.role.name,
      action: 'agregó un nuevo evento "${event.title}"',
      eventId: event.id,
    );

    // Programar recordatorio si el evento tiene hora
    if (!isAllDay && reminderMinutesBefore > 0) {
      await NotificationUtils.scheduleEventReminder(
        eventId: event.id,
        eventTitle: event.title,
        eventDate: event.date,
        minutesBefore: reminderMinutesBefore,
      );
    }

    final isOnline = _ref.read(connectivityProvider);
    if (isOnline) await _sync.pushEvent(event);

    await loadEvents();
  }

  Future<void> updateEvent(EventModel event) async {
    final updated = event.copyWith(updatedAt: DateTime.now());
    await _repo.updateEvent(updated);

    final actor = _ref.read(authProvider);
    // Doble capa: Admin + Estudiante
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📅 Evento actualizado',
      body: '${RoleCopy.actorLabelForStudent(actor?.role.name)} modificó '
          '"${updated.title}".',
      internalType: NotificationType.eventUpdated,
      channel: NotificationChannel.system,
      eventId: updated.id,
      payload: 'event:${updated.id}',
      targetUids: [updated.studentId],
      actorTitle: '📅 Evento actualizado',
      actorBody: 'Acabas de actualizar "${updated.title}".',
    );

    await _notifyOtherAdults(
      studentId: updated.studentId,
      actorUid: actor?.uid ?? '',
      actorRole: actor?.role.name,
      action: 'actualizó el evento "${updated.title}"',
      eventId: updated.id,
    );

    // Reprogramar recordatorio
    await NotificationUtils.cancelEventReminder(updated.id);
    if (!updated.isAllDay && updated.reminderMinutesBefore > 0) {
      await NotificationUtils.scheduleEventReminder(
        eventId: updated.id,
        eventTitle: updated.title,
        eventDate: updated.date,
        minutesBefore: updated.reminderMinutesBefore,
      );
    }

    final isOnline = _ref.read(connectivityProvider);
    if (isOnline) await _sync.pushEvent(updated);

    await loadEvents();
  }

  Future<void> deleteEvent(String eventId) async {
    EventModel? toDelete;
    for (final e in state.valueOrNull ?? []) {
      if (e.id == eventId) { toDelete = e; break; }
    }
    await _repo.deleteEvent(eventId);

    // Cancelar recordatorio programado
    await NotificationUtils.cancelEventReminder(eventId);

    if (toDelete != null) {
      final actor = _ref.read(authProvider);
      // Doble capa: Admin + Estudiante
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🗑️ Evento eliminado',
        body: '${RoleCopy.actorLabelForStudent(actor?.role.name)} eliminó '
            '"${toDelete.title}" del calendario.',
        internalType: NotificationType.eventDeleted,
        channel: NotificationChannel.system,
        eventId: eventId,
        payload: 'event_deleted:$eventId',
        targetUids: [toDelete.studentId],
        actorTitle: '🗑️ Evento eliminado',
        actorBody: 'Acabas de eliminar "${toDelete.title}".',
      );
      await _notifyOtherAdults(
        studentId: toDelete.studentId,
        actorUid: actor?.uid ?? '',
        actorRole: actor?.role.name,
        action: 'eliminó el evento "${toDelete.title}"',
        eventId: eventId,
      );
      final isOnline = _ref.read(connectivityProvider);
      if (isOnline) {
        final deletedEvent = await _repo.getEventById(eventId);
        if (deletedEvent != null) {
          await _sync.pushEvent(deletedEvent);
        }
      }
    }
    await loadEvents();
  }

  List<EventModel> eventsForDate(DateTime date) {
    return state.maybeWhen(
      data: (events) => events.where((e) {
        return e.date.year == date.year &&
            e.date.month == date.month &&
            e.date.day == date.day;
      }).toList(),
      orElse: () => [],
    );
  }

  List<EventModel> get upcomingEvents {
    return state.maybeWhen(
      data: (events) =>
          events.where((e) => !e.isPast).take(5).toList(),
      orElse: () => [],
    );
  }
}

final eventProvider =
    StateNotifierProvider<EventNotifier, AsyncValue<List<EventModel>>>((ref) {
  final notifier = EventNotifier(ref);
  // Recargar al cambiar de estudiante activo o de sesión
  ref.listen(activeStudentIdProvider, (_, _) => notifier.loadEvents());
  ref.listen(linkedStudentsProvider, (_, _) => notifier.loadEvents());
  ref.listen(authProvider, (_, _) => notifier.loadEvents());
  return notifier;
});
