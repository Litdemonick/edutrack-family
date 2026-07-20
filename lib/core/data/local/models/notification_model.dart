import 'dart:convert';

// ═══════════════════════════════════════════════════════════════
// INTERNAL NOTIFICATION MODEL — EduTrack Family
// Notificaciones internas guardadas en SharedPreferences.
// No son push; son el historial del campana 🔔 dentro de la app.
// ═══════════════════════════════════════════════════════════════

enum NotificationType {
  taskAssigned,
  taskUpdated,
  taskDeleted,
  taskOverdue,
  taskCompleted,
  taskAccepted,
  taskRejected,
  eventCreated,
  eventUpdated,
  eventDeleted,
  eventReminder,
  evidenceUploaded,
  deadline,
  familyUpdate,
  seismicAlert,
  wellnessCheck,
  general,
}

extension NotificationTypeX on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.taskAssigned:
        return 'Tarea asignada';
      case NotificationType.taskUpdated:
        return 'Tarea modificada';
      case NotificationType.taskDeleted:
        return 'Tarea eliminada';
      case NotificationType.taskOverdue:
        return 'Tarea vencida';
      case NotificationType.taskCompleted:
        return 'Tarea completada';
      case NotificationType.taskAccepted:
        return 'Tarea aceptada';
      case NotificationType.taskRejected:
        return 'Tarea rechazada';
      case NotificationType.eventCreated:
        return 'Nuevo evento';
      case NotificationType.eventUpdated:
        return 'Evento modificado';
      case NotificationType.eventDeleted:
        return 'Evento eliminado';
      case NotificationType.eventReminder:
        return 'Recordatorio de evento';
      case NotificationType.evidenceUploaded:
        return 'Evidencia enviada';
      case NotificationType.deadline:
        return 'Vencimiento';
      case NotificationType.familyUpdate:
        return 'Familia';
      case NotificationType.seismicAlert:
        return 'Alerta sísmica';
      case NotificationType.wellnessCheck:
        return '¿Estás bien?';
      case NotificationType.general:
        return 'General';
    }
  }

  String get emoji {
    switch (this) {
      case NotificationType.taskAssigned:   return '📌';
      case NotificationType.taskUpdated:    return '✏️';
      case NotificationType.taskDeleted:    return '🗑️';
      case NotificationType.taskOverdue:    return '🔴';
      case NotificationType.taskCompleted:  return '✅';
      case NotificationType.taskAccepted:   return '🎉';
      case NotificationType.taskRejected:   return '❌';
      case NotificationType.eventCreated:   return '📅';
      case NotificationType.eventUpdated:   return '📅';
      case NotificationType.eventDeleted:   return '🗑️';
      case NotificationType.eventReminder:  return '🔔';
      case NotificationType.evidenceUploaded: return '📷';
      case NotificationType.deadline:       return '⚠️';
      case NotificationType.familyUpdate:   return '🔗';
      case NotificationType.seismicAlert:   return '🌍';
      case NotificationType.wellnessCheck:  return '🧡';
      case NotificationType.general:        return '📢';
    }
  }
}

class InternalNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final String? taskId;
  final String? eventId;

  /// Ruta a la que navegar al tocar cuando NO es de tarea/evento (ej.
  /// cambios de vinculación de familia/profesor) — null = no navega.
  final String? route;
  final DateTime createdAt;
  final bool isRead;

  const InternalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.taskId,
    this.eventId,
    this.route,
    required this.createdAt,
    this.isRead = false,
  });

  InternalNotification copyWith({bool? isRead}) => InternalNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        taskId: taskId,
        eventId: eventId,
        route: route,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type.name,
        'taskId': taskId,
        'eventId': eventId,
        'route': route,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
      };

  factory InternalNotification.fromJson(Map<String, dynamic> json) {
    return InternalNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      taskId: json['taskId'] as String?,
      eventId: json['eventId'] as String?,
      route: json['route'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  // ignore: unused_element
  static String _toJsonString(InternalNotification n) => jsonEncode(n.toJson());
}
