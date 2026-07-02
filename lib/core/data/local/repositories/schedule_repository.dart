import 'package:edutrack_family/core/data/local/models/schedule_model.dart';

// ═══════════════════════════════════════════════════════════════
// SCHEDULE REPOSITORY — EduTrack Family
// Acceso al horario estático de Yordan.
// El horario es fijo (no se edita desde la app).
// ═══════════════════════════════════════════════════════════════

class ScheduleRepository {
  ScheduleRepository._();
  static final ScheduleRepository instance = ScheduleRepository._();

  List<ScheduleEntry> getForDay(int weekday) =>
      YordanSchedule.forDay(weekday);

  List<ScheduleEntry> getToday() => YordanSchedule.today;

  ScheduleEntry? getCurrentClass() => YordanSchedule.currentClass;

  ScheduleEntry? getNextClass() => YordanSchedule.nextClass;

  List<ScheduleEntry> get allEntries => YordanSchedule.entries;

  List<Map<String, String>> get trimestres => YordanSchedule.trimestres;
}
