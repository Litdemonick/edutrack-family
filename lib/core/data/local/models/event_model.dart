import 'package:equatable/equatable.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT MODEL — EduTrack Family
// Representa eventos del calendario escolar:
// reuniones de padres, eventos especiales, períodos de exámenes, etc.
// ═══════════════════════════════════════════════════════════════

enum EventType { meeting, special, exam, holiday, other }

extension EventTypeExt on EventType {
  String get label {
    switch (this) {
      case EventType.meeting:
        return 'Reunión de Padres';
      case EventType.special:
        return 'Evento Especial';
      case EventType.exam:
        return 'Período de Exámenes';
      case EventType.holiday:
        return 'Vacaciones';
      case EventType.other:
        return 'Otro';
    }
  }

  String get emoji {
    switch (this) {
      case EventType.meeting:
        return '👪';
      case EventType.special:
        return '🎉';
      case EventType.exam:
        return '📝';
      case EventType.holiday:
        return '🏖️';
      case EventType.other:
        return '📌';
    }
  }
}

class EventModel extends Equatable {
  final String id;

  /// Estudiante dueño del evento (multi-tenant 2.0).
  /// '' solo durante la transición — todo evento nuevo debe llevarlo.
  final String studentId;

  final String title;
  final String? description;
  final EventType type;
  final DateTime date;
  final DateTime? endDate;
  final bool isAllDay;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int reminderMinutesBefore;

  const EventModel({
    required this.id,
    this.studentId = '',
    required this.title,
    this.description,
    required this.type,
    required this.date,
    this.endDate,
    this.isAllDay = true,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.reminderMinutesBefore = 60,
  });

  int get daysLeft => EduDateUtils.daysUntil(date);
  bool get isPast => daysLeft < 0;
  bool get isToday => daysLeft == 0;
  bool get isSoon => daysLeft >= 0 && daysLeft <= 7;

  EventModel copyWith({
    String? id,
    String? studentId,
    String? title,
    String? description,
    EventType? type,
    DateTime? date,
    DateTime? endDate,
    bool? isAllDay,
    DateTime? updatedAt,
    bool? isDeleted,
    int? reminderMinutesBefore,
  }) {
    return EventModel(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      date: date ?? this.date,
      endDate: endDate ?? this.endDate,
      isAllDay: isAllDay ?? this.isAllDay,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SQLITE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'student_id': studentId,
      'title': title,
      'description': description,
      'type': type.index,
      'date': EduDateUtils.toIso(date),
      'end_date': endDate != null ? EduDateUtils.toIso(endDate!) : null,
      'is_all_day': isAllDay ? 1 : 0,
      'created_at': EduDateUtils.toIso(createdAt),
      'updated_at': EduDateUtils.toIso(updatedAt),
      'is_deleted': isDeleted ? 1 : 0,
      'reminder_minutes_before': reminderMinutesBefore,
    };
  }

  factory EventModel.fromMap(Map<String, dynamic> map) {
    final typeIdx = map['type'] as int? ?? 0;
    return EventModel(
      id: map['id'] as String,
      studentId: map['student_id'] as String? ?? '',
      title: map['title'] as String,
      description: map['description'] as String?,
      type: typeIdx >= 0 && typeIdx < EventType.values.length
          ? EventType.values[typeIdx]
          : EventType.other,
      date: DateTime.parse(map['date'] as String),
      endDate:
          map['end_date'] != null
              ? DateTime.parse(map['end_date'] as String)
              : null,
      isAllDay: (map['is_all_day'] as int? ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      reminderMinutesBefore: map['reminder_minutes_before'] as int? ?? 60,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FIRESTORE
  // ─────────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'date': date.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_all_day': isAllDay,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted,
      'reminder_minutes_before': reminderMinutesBefore,
    };
  }

  /// [studentId] viene de la ruta students/{studentId}/events/{id}.
  factory EventModel.fromFirestore(Map<String, dynamic> data, String id,
      {String studentId = ''}) {
    EventType parseType(String name) {
      return EventType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => EventType.other,
      );
    }

    return EventModel(
      id: id,
      studentId: studentId,
      title: data['title'] as String,
      description: data['description'] as String?,
      type: parseType(data['type'] as String),
      date: DateTime.parse(data['date'] as String),
      endDate:
          data['end_date'] != null
              ? DateTime.parse(data['end_date'] as String)
              : null,
      isAllDay: data['is_all_day'] as bool? ?? true,
      createdAt: DateTime.parse(data['created_at'] as String),
      updatedAt: DateTime.parse(data['updated_at'] as String),
      isDeleted: data['is_deleted'] as bool? ?? false,
      reminderMinutesBefore: data['reminder_minutes_before'] as int? ?? 60,
    );
  }

  @override
  List<Object?> get props => [id, studentId, title, type, date, isDeleted];
}
