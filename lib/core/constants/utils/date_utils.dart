import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_strings.dart';

// ═══════════════════════════════════════════════════════════════
// DATE UTILS — EduTrack Family
// Todas las operaciones de fecha/hora de la app en un solo lugar.
// Zona horaria: América/Panamá (UTC-5, sin horario de verano)
// ═══════════════════════════════════════════════════════════════

class EduDateUtils {
  EduDateUtils._();

  // ─────────────────────────────────────────────────────────────
  // COMPARACIONES BÁSICAS
  // ─────────────────────────────────────────────────────────────

  /// Retorna true si [date] es hoy
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Retorna true si [date] es mañana
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  /// Retorna true si [date] fue ayer
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// Retorna true si [date] ya pasó (es anterior a hoy)
  static bool isOverdue(DateTime date) {
    final today = _startOfDay(DateTime.now());
    return date.isBefore(today);
  }

  /// Retorna true si [date] es hoy o pasó
  static bool isDueOrOverdue(DateTime date) {
    return isToday(date) || isOverdue(date);
  }

  /// Retorna true si [date] está en la misma semana que hoy
  static bool isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = _startOfDay(
      now.subtract(Duration(days: now.weekday - 1)),
    );
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return date.isAfter(startOfWeek) && date.isBefore(endOfWeek);
  }

  // ─────────────────────────────────────────────────────────────
  // CALCULAR DÍAS RESTANTES
  // ─────────────────────────────────────────────────────────────

  /// Días restantes hasta [dueDate] desde hoy.
  /// Negativo = ya venció. 0 = vence hoy. Positivo = días que quedan.
  static int daysUntil(DateTime dueDate) {
    final today = _startOfDay(DateTime.now());
    final due = _startOfDay(dueDate);
    return due.difference(today).inDays;
  }

  /// Días que han pasado desde [date] hasta hoy.
  static int daysSince(DateTime date) {
    final today = _startOfDay(DateTime.now());
    final from = _startOfDay(date);
    return today.difference(from).inDays;
  }

  // ─────────────────────────────────────────────────────────────
  // ETIQUETAS DE FECHA PARA LA UI
  // ─────────────────────────────────────────────────────────────

  /// Retorna una etiqueta legible para la fecha de entrega.
  /// Ejemplos: "Vence hoy", "Vence mañana", "En 3 días", "Vencida hace 2 días"
  static String dueDateLabel(DateTime dueDate) {
    final days = daysUntil(dueDate);
    return AppStrings.daysLeftLabel(days);
  }

  /// Retorna una etiqueta corta para mostrar en cards.
  /// Ejemplos: "Hoy", "Mañana", "Lun 12", "12 May"
  static String shortDateLabel(DateTime date) {
    if (isToday(date)) return 'Hoy';
    if (isTomorrow(date)) return 'Mañana';
    if (isYesterday(date)) return 'Ayer';

    final day = date.day;
    final monthStr = AppStrings.monthsShort[date.month - 1];
    final dayStr = AppStrings.weekDaysShort[date.weekday - 1];

    // Si es esta semana: "Lun 12"
    if (isThisWeek(date)) return '$dayStr $day';

    // Otro: "12 May"
    return '$day $monthStr';
  }

  /// Retorna fecha completa en español.
  /// Ejemplo: "Lunes, 12 de mayo de 2025"
  static String fullDateLabel(DateTime date) {
    final dayName = AppStrings.weekDays[date.weekday - 1];
    final day = date.day;
    final monthName = AppStrings.months[date.month - 1];
    final year = date.year;
    return '$dayName, $day de $monthName de $year';
  }

  /// Retorna fecha en formato corto.
  /// Ejemplo: "12/05/2025"
  static String numericDateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  /// Retorna fecha y hora.
  /// Ejemplo: "12 may, 2:30 PM"
  static String dateTimeLabel(DateTime date) {
    final day = date.day;
    final monthStr = AppStrings.monthsShort[date.month - 1].toLowerCase();
    final hour =
        date.hour > 12
            ? date.hour - 12
            : date.hour == 0
            ? 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$day $monthStr, $hour:$minute $period';
  }

  /// Retorna solo la hora en formato 12h.
  /// Ejemplo: "2:30 PM"
  static String timeLabel(DateTime date) {
    final hour =
        date.hour > 12
            ? date.hour - 12
            : date.hour == 0
            ? 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Retorna el nombre del mes y año.
  /// Ejemplo: "Mayo 2025"
  static String monthYearLabel(DateTime date) {
    return '${AppStrings.months[date.month - 1]} ${date.year}';
  }

  /// Retorna el nombre del día de la semana.
  /// Ejemplo: "Lunes"
  static String weekDayLabel(DateTime date) {
    return AppStrings.weekDays[date.weekday - 1];
  }

  /// Etiqueta para el header del dashboard según la hora del día.
  /// "Buenos días ☀", "Buenas tardes 🌤", "Buenas noches 🌙"
  static String greetingByHour() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Buenos días ☀️';
    if (hour >= 12 && hour < 18) return 'Buenas tardes 🌤️';
    return 'Buenas noches 🌙';
  }

  // ─────────────────────────────────────────────────────────────
  // COLORES SEGÚN FECHA (semáforo)
  // ─────────────────────────────────────────────────────────────

  /// Color del semáforo según días restantes, estado de completado y si ya venció.
  static Color statusColor(DateTime dueDate, {bool isCompleted = false, bool isOverdue = false}) {
    return AppColors.forDaysLeft(daysUntil(dueDate), isCompleted: isCompleted, isOverdue: isOverdue);
  }

  /// Color de fondo (claro) del semáforo.
  static Color statusColorLight(DateTime dueDate, {bool isCompleted = false, bool isOverdue = false}) {
    return AppColors.forDaysLeftLight(
      daysUntil(dueDate),
      isCompleted: isCompleted,
      isOverdue: isOverdue,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ORDENAR TAREAS POR PRIORIDAD DE FECHA
  // ─────────────────────────────────────────────────────────────

  /// Ordena una lista de fechas: primero las más urgentes.
  /// Vencidas → Hoy → Mañana → Próximas → Más lejanas
  static List<DateTime> sortByUrgency(List<DateTime> dates) {
    final sorted = List<DateTime>.from(dates);
    sorted.sort((a, b) => a.compareTo(b));
    return sorted;
  }

  /// Comparador para ordenar objetos con fecha de entrega.
  /// Úsalo con .sort() pasando la fecha de cada objeto.
  /// Ejemplo: tasks.sort((a, b) => EduDateUtils.compareByDueDate(a.dueDate, b.dueDate))
  static int compareByDueDate(DateTime a, DateTime b) => a.compareTo(b);

  // ─────────────────────────────────────────────────────────────
  // MANEJO DE FECHAS PARA SQLITE
  // SQLite no tiene tipo Date nativo, se guarda como String ISO 8601
  // ─────────────────────────────────────────────────────────────

  /// Convierte DateTime a String para guardar en SQLite.
  /// Formato: "2025-05-12T14:30:00.000"
  static String toIso(DateTime date) => date.toIso8601String();

  /// Convierte String de SQLite a DateTime.
  /// Retorna null si el string es inválido o nulo.
  static DateTime? fromIso(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      return DateTime.parse(isoString);
    } catch (_) {
      return null;
    }
  }

  /// Convierte DateTime a String solo de fecha (sin hora) para SQLite.
  /// Formato: "2025-05-12"
  static String toDateOnly(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Parsea String "2025-05-12" a DateTime (hora 00:00:00)
  static DateTime? fromDateOnly(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateTime.parse(dateString);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UTILIDADES PARA CALENDARIO (table_calendar)
  // ─────────────────────────────────────────────────────────────

  /// Normaliza una fecha a medianoche (00:00:00).
  /// Necesario para comparar fechas en table_calendar.
  static DateTime normalizeDate(DateTime date) => _startOfDay(date);

  /// Verifica si dos fechas son el mismo día (sin importar la hora).
  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Retorna el primer día del mes de [date]
  static DateTime firstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  /// Retorna el último día del mes de [date]
  static DateTime lastDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0);

  /// Retorna el primer día de la semana (lunes) que contiene [date]
  static DateTime firstDayOfWeek(DateTime date) {
    return _startOfDay(date.subtract(Duration(days: date.weekday - 1)));
  }

  /// Retorna el último día de la semana (domingo) que contiene [date]
  static DateTime lastDayOfWeek(DateTime date) {
    return _startOfDay(date.add(Duration(days: 7 - date.weekday)));
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIONES — calcular cuándo programar alertas
  // ─────────────────────────────────────────────────────────────

  /// Retorna la DateTime para notificar [daysBefore] días antes de [dueDate].
  /// La notificación se programa a las 8:00 AM del día calculado.
  static DateTime? notificationDateFor(DateTime dueDate, {int daysBefore = 1}) {
    final notifDate = dueDate.subtract(Duration(days: daysBefore));

    // Si ya pasó ese día, no programar
    if (notifDate.isBefore(DateTime.now())) return null;

    return DateTime(
      notifDate.year,
      notifDate.month,
      notifDate.day,
      8,
      0,
      0, // 8:00 AM
    );
  }

  /// Retorna las DateTimes para notificar según prioridad:
  /// - Examen / Parcial: 3 días antes, 1 día antes, el mismo día a las 7AM
  /// - Tarea / Ejercicio: 2 días antes, el mismo día a las 7AM
  /// - Otro: 1 día antes
  static List<DateTime> notificationScheduleFor(
    DateTime dueDate,
    String category,
  ) {
    final results = <DateTime>[];
    final cat = category.toLowerCase();

    List<int> daysBefore;

    if (cat == 'examen' || cat == 'parcial') {
      daysBefore = [3, 1, 0];
    } else if (cat == 'tarea' || cat == 'ejercicio') {
      daysBefore = [2, 0];
    } else {
      daysBefore = [1];
    }

    for (final days in daysBefore) {
      final notifDt = notificationDateFor(dueDate, daysBefore: days);
      if (notifDt != null) results.add(notifDt);
    }

    return results;
  }

  // ─────────────────────────────────────────────────────────────
  // HISTORIAL — limpieza automática
  // ─────────────────────────────────────────────────────────────

  /// Retorna true si [date] tiene más de [days] días de antigüedad.
  /// Úsalo para filtrar tareas del historial que deben limpiarse.
  static bool isOlderThan(DateTime date, {int days = 30}) {
    return daysSince(date) > days;
  }

  /// Retorna la fecha límite para la limpieza del historial.
  /// Tareas completadas/eliminadas antes de esta fecha se pueden borrar.
  static DateTime historyCleanupCutoff({int keepDays = 30}) {
    return DateTime.now().subtract(Duration(days: keepDays));
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS PRIVADOS
  // ─────────────────────────────────────────────────────────────

  /// Retorna la fecha con hora 00:00:00 (inicio del día)
  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// `builder:` para showDatePicker/showTimePicker — limita el
  /// textScale heredado del sistema. Sin esto, con el escalado de
  /// pantalla típico de Windows (125%/150%), las columnas de ancho
  /// fijo del picker nativo de Material (ej. el selector AM/PM)
  /// desbordan (RenderFlex overflow) porque el texto crece pero el
  /// contenedor no.
  static Widget clampPickerTextScale(BuildContext context, Widget? child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.2)),
      child: child!,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EXTENSION EN DATETIME
// Permite usar los métodos directamente sobre cualquier DateTime:
//   myDate.isToday
//   myDate.daysUntil
//   myDate.dueDateLabel
// ─────────────────────────────────────────────────────────────
extension EduDateTime on DateTime {
  bool get isToday => EduDateUtils.isToday(this);
  bool get isTomorrow => EduDateUtils.isTomorrow(this);
  bool get isYesterday => EduDateUtils.isYesterday(this);
  bool get isOverdue => EduDateUtils.isOverdue(this);
  bool get isThisWeek => EduDateUtils.isThisWeek(this);

  int get daysUntil => EduDateUtils.daysUntil(this);
  int get daysSince => EduDateUtils.daysSince(this);

  String get dueDateLabel => EduDateUtils.dueDateLabel(this);
  String get shortLabel => EduDateUtils.shortDateLabel(this);
  String get fullLabel => EduDateUtils.fullDateLabel(this);
  String get numericLabel => EduDateUtils.numericDateLabel(this);
  String get timeLabel => EduDateUtils.timeLabel(this);
  String get monthYearLabel => EduDateUtils.monthYearLabel(this);
  String get weekDayLabel => EduDateUtils.weekDayLabel(this);

  String get toIso => EduDateUtils.toIso(this);
  String get toDateOnly => EduDateUtils.toDateOnly(this);

  DateTime get normalized => EduDateUtils.normalizeDate(this);
  DateTime get firstDayOfMonth => EduDateUtils.firstDayOfMonth(this);
  DateTime get lastDayOfMonth => EduDateUtils.lastDayOfMonth(this);
  DateTime get firstDayOfWeek => EduDateUtils.firstDayOfWeek(this);
  DateTime get lastDayOfWeek => EduDateUtils.lastDayOfWeek(this);

  bool isSameDayAs(DateTime other) => EduDateUtils.isSameDay(this, other);

  Color statusColor({bool isCompleted = false, bool isOverdue = false}) =>
      EduDateUtils.statusColor(this, isCompleted: isCompleted, isOverdue: isOverdue);

  Color statusColorLight({bool isCompleted = false, bool isOverdue = false}) =>
      EduDateUtils.statusColorLight(this, isCompleted: isCompleted, isOverdue: isOverdue);

  bool isOlderThan({int days = 30}) =>
      EduDateUtils.isOlderThan(this, days: days);
}
