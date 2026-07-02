// ═══════════════════════════════════════════════════════════════
// SCHEDULE MODEL — EduTrack Family
// Horario de clases de Yordan — Grado 5° B
// Maestra: Ereida De Beitia
//
// Datos extraídos de la foto del horario real.
// weekday: 1=Lunes, 2=Martes, 3=Miércoles, 4=Jueves, 5=Viernes
// ═══════════════════════════════════════════════════════════════

class ScheduleEntry {
  final String id;
  final int weekday;
  final String startTime;
  final String endTime;
  final String subject;
  final bool isBreak;

  const ScheduleEntry({
    required this.id,
    required this.weekday,
    required this.startTime,
    required this.endTime,
    required this.subject,
    this.isBreak = false,
  });

  String get timeRange => '$startTime – $endTime';
}

// ─────────────────────────────────────────────────────────────
// HORARIO COMPLETO DE YORDAN — cargado estáticamente
// ─────────────────────────────────────────────────────────────
class YordanSchedule {
  YordanSchedule._();

  static const String teacher = 'Ereida De Beitia';
  static const String grade = '5° B';
  static const String school = 'Escuela';

  static const List<ScheduleEntry> entries = [
    // ── LUNES ─────────────────────────────────────────────────
    ScheduleEntry(id: 'l1', weekday: 1, startTime: '7:00', endTime: '7:35', subject: 'Acto Cívico'),
    ScheduleEntry(id: 'l2', weekday: 1, startTime: '7:35', endTime: '8:10', subject: 'Inglés'),
    ScheduleEntry(id: 'l3', weekday: 1, startTime: '8:10', endTime: '8:45', subject: 'Inglés'),
    ScheduleEntry(id: 'l4', weekday: 1, startTime: '8:45', endTime: '9:20', subject: 'Exp. Artísticas'),
    ScheduleEntry(id: 'l5', weekday: 1, startTime: '9:20', endTime: '9:40', subject: 'Receso', isBreak: true),
    ScheduleEntry(id: 'l6', weekday: 1, startTime: '9:40', endTime: '10:15', subject: 'Español'),
    ScheduleEntry(id: 'l7', weekday: 1, startTime: '10:15', endTime: '10:50', subject: 'C. Naturales'),
    ScheduleEntry(id: 'l8', weekday: 1, startTime: '10:50', endTime: '11:25', subject: 'Matemáticas'),
    ScheduleEntry(id: 'l9', weekday: 1, startTime: '11:25', endTime: '12:00', subject: 'Matemáticas'),

    // ── MARTES ────────────────────────────────────────────────
    ScheduleEntry(id: 'm1', weekday: 2, startTime: '7:00', endTime: '7:35', subject: 'Religión'),
    ScheduleEntry(id: 'm2', weekday: 2, startTime: '7:35', endTime: '8:10', subject: 'Laboratorio'),
    ScheduleEntry(id: 'm3', weekday: 2, startTime: '8:10', endTime: '8:45', subject: 'Laboratorio'),
    ScheduleEntry(id: 'm4', weekday: 2, startTime: '8:45', endTime: '9:20', subject: 'Matemáticas'),
    ScheduleEntry(id: 'm5', weekday: 2, startTime: '9:20', endTime: '9:40', subject: 'Receso', isBreak: true),
    ScheduleEntry(id: 'm6', weekday: 2, startTime: '9:40', endTime: '10:15', subject: 'Informática'),
    ScheduleEntry(id: 'm7', weekday: 2, startTime: '10:15', endTime: '10:50', subject: 'Exp. Artísticas'),
    ScheduleEntry(id: 'm8', weekday: 2, startTime: '10:50', endTime: '11:25', subject: 'Español'),
    ScheduleEntry(id: 'm9', weekday: 2, startTime: '11:25', endTime: '12:00', subject: 'C. Sociales'),

    // ── MIÉRCOLES ─────────────────────────────────────────────
    ScheduleEntry(id: 'x1', weekday: 3, startTime: '7:00', endTime: '7:35', subject: 'Exp. Artísticas'),
    ScheduleEntry(id: 'x2', weekday: 3, startTime: '7:35', endTime: '8:10', subject: 'Inglés'),
    ScheduleEntry(id: 'x3', weekday: 3, startTime: '8:10', endTime: '8:45', subject: 'Inglés'),
    ScheduleEntry(id: 'x4', weekday: 3, startTime: '8:45', endTime: '9:20', subject: 'Matemáticas'),
    ScheduleEntry(id: 'x5', weekday: 3, startTime: '9:20', endTime: '9:40', subject: 'Receso', isBreak: true),
    ScheduleEntry(id: 'x6', weekday: 3, startTime: '9:40', endTime: '10:15', subject: 'Educ. Física'),
    ScheduleEntry(id: 'x7', weekday: 3, startTime: '10:15', endTime: '10:50', subject: 'Educ. Física'),
    ScheduleEntry(id: 'x8', weekday: 3, startTime: '10:50', endTime: '11:25', subject: 'Religión'),
    ScheduleEntry(id: 'x9', weekday: 3, startTime: '11:25', endTime: '12:00', subject: 'Español'),

    // ── JUEVES ────────────────────────────────────────────────
    ScheduleEntry(id: 'j1', weekday: 4, startTime: '7:00', endTime: '7:35', subject: 'C. Naturales'),
    ScheduleEntry(id: 'j2', weekday: 4, startTime: '7:35', endTime: '8:10', subject: 'Español'),
    ScheduleEntry(id: 'j3', weekday: 4, startTime: '8:10', endTime: '8:45', subject: 'Español'),
    ScheduleEntry(id: 'j4', weekday: 4, startTime: '8:45', endTime: '9:20', subject: 'FDC'),
    ScheduleEntry(id: 'j5', weekday: 4, startTime: '9:20', endTime: '9:40', subject: 'Receso', isBreak: true),
    ScheduleEntry(id: 'j6', weekday: 4, startTime: '9:40', endTime: '10:15', subject: 'FDC'),
    ScheduleEntry(id: 'j7', weekday: 4, startTime: '10:15', endTime: '10:50', subject: 'Inglés'),
    ScheduleEntry(id: 'j8', weekday: 4, startTime: '10:50', endTime: '11:25', subject: 'Inglés'),
    ScheduleEntry(id: 'j9', weekday: 4, startTime: '11:25', endTime: '12:00', subject: 'C. Sociales'),

    // ── VIERNES ───────────────────────────────────────────────
    ScheduleEntry(id: 'v1', weekday: 5, startTime: '7:00', endTime: '7:35', subject: 'C. Sociales'),
    ScheduleEntry(id: 'v2', weekday: 5, startTime: '7:35', endTime: '8:10', subject: 'C. Sociales'),
    ScheduleEntry(id: 'v3', weekday: 5, startTime: '8:10', endTime: '8:45', subject: 'Español'),
    ScheduleEntry(id: 'v4', weekday: 5, startTime: '8:45', endTime: '9:20', subject: 'Español'),
    ScheduleEntry(id: 'v5', weekday: 5, startTime: '9:20', endTime: '9:40', subject: 'Receso', isBreak: true),
    ScheduleEntry(id: 'v6', weekday: 5, startTime: '9:40', endTime: '10:15', subject: 'Inglés'),
    ScheduleEntry(id: 'v7', weekday: 5, startTime: '10:15', endTime: '10:50', subject: 'Agropecuaria'),
    ScheduleEntry(id: 'v8', weekday: 5, startTime: '10:50', endTime: '11:25', subject: 'Agropecuaria'),
    ScheduleEntry(id: 'v9', weekday: 5, startTime: '11:25', endTime: '12:00', subject: 'Matemáticas'),
  ];

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE CONSULTA
  // ─────────────────────────────────────────────────────────────

  /// Clases del día (weekday 1=Lunes…5=Viernes), sin recesos
  static List<ScheduleEntry> forDay(int weekday) {
    return entries.where((e) => e.weekday == weekday && !e.isBreak).toList();
  }

  /// Clases del día de hoy
  static List<ScheduleEntry> get today {
    final wd = DateTime.now().weekday;
    if (wd > 5) return [];
    return forDay(wd);
  }

  /// La clase actual según la hora del sistema
  static ScheduleEntry? get currentClass {
    final now = DateTime.now();
    final wd = now.weekday;
    if (wd > 5) return null;

    final todayEntries = entries.where((e) => e.weekday == wd).toList();
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final entry in todayEntries) {
      if (hhmm.compareTo(entry.startTime) >= 0 &&
          hhmm.compareTo(entry.endTime) < 0) {
        return entry;
      }
    }
    return null;
  }

  /// La próxima clase según la hora del sistema
  static ScheduleEntry? get nextClass {
    final now = DateTime.now();
    final wd = now.weekday;
    if (wd > 5) return null;

    final todayEntries =
        entries.where((e) => e.weekday == wd && !e.isBreak).toList();
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final entry in todayEntries) {
      if (entry.startTime.compareTo(hhmm) > 0) return entry;
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────
  // PERÍODOS TRIMESTRALES
  // ─────────────────────────────────────────────────────────────
  static const List<Map<String, String>> trimestres = [
    {
      'label': '1° Trimestre',
      'start': '2025-03-02',
      'end': '2025-05-29',
      'color': 'green',
    },
    {
      'label': 'Receso 1',
      'start': '2025-06-01',
      'end': '2025-06-05',
      'color': 'amber',
    },
    {
      'label': '2° Trimestre',
      'start': '2025-06-08',
      'end': '2025-09-04',
      'color': 'blue',
    },
    {
      'label': 'Receso 2',
      'start': '2025-09-07',
      'end': '2025-09-11',
      'color': 'amber',
    },
    {
      'label': '3° Trimestre',
      'start': '2025-09-14',
      'end': '2025-12-11',
      'color': 'purple',
    },
  ];
}
