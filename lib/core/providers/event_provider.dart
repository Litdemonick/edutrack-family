import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/repositories/event_repository.dart';
import 'package:edutrack_family/core/services/sync_service.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';
import 'package:edutrack_family/core/constants/utils/notification_utils.dart';
import 'package:edutrack_family/core/providers/connectivity_provider.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT PROVIDER — EduTrack Family
// Estado global de eventos del calendario.
// ═══════════════════════════════════════════════════════════════

class EventNotifier extends StateNotifier<AsyncValue<List<EventModel>>> {
  EventNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadEvents();
  }

  final Ref _ref;
  final _repo = EventRepository.instance;
  final _sync = SyncService.instance;
  final _uuid = const Uuid();

  Future<void> loadEvents() async {
    final hasData = state.hasValue;
    if (!hasData) state = const AsyncValue.loading();
    try {
      final events = await _repo.getAllEvents();
      state = AsyncValue.data(events);
    } catch (e, st) {
      if (!hasData) {
        state = AsyncValue.error(e, st);
      } else {
        debugPrint('[EventProvider] Error recargando eventos: $e');
      }
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
  }) async {
    final now = DateTime.now();
    final event = EventModel(
      id: _uuid.v4(),
      title: title,
      description: description,
      type: type,
      date: date,
      endDate: endDate,
      isAllDay: isAllDay,
      createdAt: now,
      updatedAt: now,
      reminderMinutesBefore: reminderMinutesBefore,
    );

    await _repo.createEvent(event);

    // Doble capa: Admin (local) + Estudiante (FCM)
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📅 Nuevo evento',
      body: '"${event.title}" fue agregado al calendario.',
      internalType: NotificationType.eventCreated,
      channel: NotificationChannel.system,
      eventId: event.id,
      payload: 'event:${event.id}',
      targetRole: 'student',
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

    // Doble capa: Admin + Estudiante
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📅 Evento actualizado',
      body: '"${updated.title}" fue modificado.',
      internalType: NotificationType.eventUpdated,
      channel: NotificationChannel.system,
      eventId: updated.id,
      payload: 'event:${updated.id}',
      targetRole: 'student',
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
      // Doble capa: Admin + Estudiante
      await NotificationBus.dispatchFromProvider(
        ref: _ref,
        title: '🗑️ Evento eliminado',
        body: '"${toDelete.title}" fue eliminado del calendario.',
        internalType: NotificationType.eventDeleted,
        channel: NotificationChannel.system,
        eventId: eventId,
        payload: 'event_deleted:$eventId',
        targetRole: 'student',
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
      return EventNotifier(ref);
    });
