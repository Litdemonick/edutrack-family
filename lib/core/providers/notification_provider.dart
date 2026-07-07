import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../data/local/models/notification_model.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION PROVIDER — EduTrack Family
// Gestiona el historial de notificaciones internas (campana 🔔).
// Persiste en SharedPreferences, máx 50 entradas.
// ═══════════════════════════════════════════════════════════════

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<InternalNotification>>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationNotifier(prefs);
  },
);

final unreadNotificationCountProvider = Provider<int>((ref) {
  return ref.watch(notificationProvider).where((n) => !n.isRead).length;
});

// ─────────────────────────────────────────────────────────────

class NotificationNotifier
    extends StateNotifier<List<InternalNotification>> {
  final SharedPreferences _prefs;
  static const _key = 'internal_notifications';

  NotificationNotifier(this._prefs) : super([]) {
    _load();
  }

  void _load() {
    final raw = _prefs.getStringList(_key) ?? [];
    state = raw
        .map((s) {
          try {
            return InternalNotification.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<InternalNotification>()
        .toList();
  }

  void _save() {
    _prefs.setStringList(
      _key,
      state.map((n) => jsonEncode(n.toJson())).toList(),
    );
  }

  /// Ventana para considerar dos notificaciones "el mismo aviso" — el
  /// eco de Firestore en tiempo real y el push remoto (ver
  /// _notifyOtherAdults en task/event_provider.dart +
  /// _listenForegroundPush en app.dart) pueden llegar casi al mismo
  /// tiempo para el mismo cambio; sin esto, cualquier rol (padre,
  /// profesor o estudiante) veía la campana duplicada.
  static const _dedupeWindow = Duration(seconds: 20);

  void add(InternalNotification notification) {
    final isDuplicate = state.any((n) {
      // Además de la misma tarea/evento, debe ser el MISMO tipo de
      // aviso — sin esto, dos notificaciones genuinamente distintas
      // sobre la misma tarea que caen dentro de la ventana (ej.
      // "rechazada" seguida poco después de "evidencia recibida" al
      // reenviar rápido) se trataban como duplicado y la segunda se
      // perdía en silencio.
      if (n.type != notification.type) return false;
      final sameTask =
          notification.taskId != null && n.taskId == notification.taskId;
      final sameEvent =
          notification.eventId != null && n.eventId == notification.eventId;
      if (!sameTask && !sameEvent) return false;
      return DateTime.now().difference(n.createdAt) < _dedupeWindow;
    });
    if (isDuplicate) return;

    final updated = [notification, ...state];
    state = updated.length > 50 ? updated.take(50).toList() : updated;
    _save();
  }

  void markRead(String id) {
    state = state
        .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    _save();
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _save();
  }

  void delete(String id) {
    state = state.where((n) => n.id != id).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER — construye y agrega una notificación con ID automático
// ─────────────────────────────────────────────────────────────

extension NotificationNotifierX on NotificationNotifier {
  void dispatch({
    required String title,
    required String body,
    required NotificationType type,
    String? taskId,
  }) {
    add(InternalNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      taskId: taskId,
      createdAt: DateTime.now(),
    ));
  }

  void dispatchFull({
    required String title,
    required String body,
    required NotificationType type,
    String? taskId,
    String? eventId,
    String? route,
  }) {
    add(InternalNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      type: type,
      taskId: taskId,
      eventId: eventId,
      route: route,
      createdAt: DateTime.now(),
    ));
  }
}
