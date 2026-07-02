import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════
// SCHEDULE BLOCK — EduTrack Family 2.0
// Bloque del horario semanal de UN estudiante, data-driven.
// Reemplaza al YordanSchedule hardcodeado de la v1.
// SQLite: schedule_blocks · Firestore: students/{id}/scheduleBlocks
// ═══════════════════════════════════════════════════════════════

class ScheduleBlock extends Equatable {
  final String id;
  final String studentId;

  /// 1 = lunes … 7 = domingo (DateTime.weekday)
  final int weekday;

  /// Minutos desde medianoche (ej. 7:00 AM = 420)
  final int startMin;
  final int endMin;

  final String subject;
  final bool isBreak;
  final int? color;
  final DateTime updatedAt;
  final bool isDeleted;

  const ScheduleBlock({
    required this.id,
    required this.studentId,
    required this.weekday,
    required this.startMin,
    required this.endMin,
    required this.subject,
    this.isBreak = false,
    this.color,
    required this.updatedAt,
    this.isDeleted = false,
  });

  String get startLabel => _fmt(startMin);
  String get endLabel => _fmt(endMin);
  String get timeRange => '$startLabel – $endLabel';

  static String _fmt(int minutes) {
    final h24 = minutes ~/ 60;
    final m = minutes % 60;
    final suffix = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }

  /// ¿Este bloque está en curso ahora mismo?
  bool isCurrentAt(DateTime now) {
    if (now.weekday != weekday) return false;
    final nowMin = now.hour * 60 + now.minute;
    return nowMin >= startMin && nowMin < endMin;
  }

  ScheduleBlock copyWith({
    int? weekday,
    int? startMin,
    int? endMin,
    String? subject,
    bool? isBreak,
    int? color,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return ScheduleBlock(
      id: id,
      studentId: studentId,
      weekday: weekday ?? this.weekday,
      startMin: startMin ?? this.startMin,
      endMin: endMin ?? this.endMin,
      subject: subject ?? this.subject,
      isBreak: isBreak ?? this.isBreak,
      color: color ?? this.color,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // ── SQLite ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'weekday': weekday,
        'start_min': startMin,
        'end_min': endMin,
        'subject': subject,
        'is_break': isBreak ? 1 : 0,
        'color': color,
        'updated_at': updatedAt.toIso8601String(),
        'is_deleted': isDeleted ? 1 : 0,
      };

  factory ScheduleBlock.fromMap(Map<String, dynamic> map) {
    return ScheduleBlock(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      weekday: map['weekday'] as int,
      startMin: map['start_min'] as int,
      endMin: map['end_min'] as int,
      subject: map['subject'] as String,
      isBreak: (map['is_break'] ?? 0) == 1,
      color: map['color'] as int?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] ?? 0) == 1,
    );
  }

  // ── Firestore ────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'weekday': weekday,
        'startMin': startMin,
        'endMin': endMin,
        'subject': subject,
        'isBreak': isBreak,
        'color': color,
        'updatedAt': updatedAt.toIso8601String(),
        'isDeleted': isDeleted,
      };

  factory ScheduleBlock.fromFirestore(
      Map<String, dynamic> data, String id, String studentId) {
    return ScheduleBlock(
      id: id,
      studentId: studentId,
      weekday: (data['weekday'] ?? 1) as int,
      startMin: (data['startMin'] ?? 0) as int,
      endMin: (data['endMin'] ?? 0) as int,
      subject: (data['subject'] ?? '') as String,
      isBreak: (data['isBreak'] ?? false) as bool,
      color: data['color'] as int?,
      updatedAt: DateTime.tryParse((data['updatedAt'] ?? '') as String) ??
          DateTime.now(),
      isDeleted: (data['isDeleted'] ?? false) as bool,
    );
  }

  @override
  List<Object?> get props =>
      [id, studentId, weekday, startMin, endMin, subject, isBreak, color, isDeleted];
}
