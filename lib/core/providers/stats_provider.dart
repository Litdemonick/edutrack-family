import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/repositories/task_repository.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';

// ═══════════════════════════════════════════════════════════════
// STATS PROVIDER — EduTrack Family
// Calcula métricas de rendimiento a partir de las tareas cargadas.
// ═══════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────
// MODELOS DE ESTADÍSTICAS
// ─────────────────────────────────────────────────────────────

class SubjectStat {
  final String subject;
  final int total;
  final int completed;

  const SubjectStat({
    required this.subject,
    required this.total,
    required this.completed,
  });

  double get rate => total == 0 ? 0 : completed / total;
  int get pending => total - completed;
}

class DayStat {
  final DateTime date;
  final int count;
  const DayStat({required this.date, required this.count});
}

class TaskStats {
  final int total;
  final int completed;
  final int pending;
  final int inReview;
  final int overdue;
  final double completionRate;
  final int streak;
  final List<SubjectStat> bySubject;
  final List<DayStat> last7Days;
  final List<DayStat> last4Weeks;
  final int completedOnTime;
  final int completedLate;
  final int thisWeekCompleted;
  final int lastWeekCompleted;
  final int totalHistorical;

  const TaskStats({
    required this.total,
    required this.completed,
    required this.pending,
    required this.inReview,
    required this.overdue,
    required this.completionRate,
    required this.streak,
    required this.bySubject,
    required this.last7Days,
    required this.last4Weeks,
    required this.completedOnTime,
    required this.completedLate,
    required this.thisWeekCompleted,
    required this.lastWeekCompleted,
    required this.totalHistorical,
  });

  // Diferencia porcentual entre esta semana y la pasada
  double get weekTrend {
    if (lastWeekCompleted == 0) return thisWeekCompleted > 0 ? 1.0 : 0.0;
    return (thisWeekCompleted - lastWeekCompleted) / lastWeekCompleted;
  }

  bool get isImprovingWeek => thisWeekCompleted >= lastWeekCompleted;

  int get max7Days => last7Days.isEmpty
      ? 1
      : last7Days.map((d) => d.count).reduce((a, b) => a > b ? a : b).clamp(1, 999);

  int get max4Weeks => last4Weeks.isEmpty
      ? 1
      : last4Weeks.map((d) => d.count).reduce((a, b) => a > b ? a : b).clamp(1, 999);
}

// ─────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────

final _historicalTaskStatsProvider = FutureProvider<TaskStats?>((ref) async {
  final tasksState = ref.watch(taskProvider);
  final hasLoadedTasks = tasksState.maybeWhen(
    data: (_) => true,
    orElse: () => false,
  );
  if (!hasLoadedTasks) return null;
  final tasks = await TaskRepository.instance.getAllTasksForStats();
  return _compute(tasks);
});

final taskStatsProvider = Provider<TaskStats?>((ref) {
  final historical = ref.watch(_historicalTaskStatsProvider);
  return historical.maybeWhen(
    data: (stats) => stats,
    orElse: () => ref.watch(taskProvider).whenOrNull(data: _compute),
  );
});

TaskStats _compute(List<TaskModel> tasks) {
  final current = tasks.where((t) => !t.isArchived && !t.isDeleted).toList();
  final historical = tasks.where((t) => !t.isArchived).toList();
  final scored = historical
      .where((t) => !t.isDeleted || t.isCompleted || t.completedAt != null)
      .toList();

  final total     = scored.length;
  final completed = scored.where((t) => t.isCompleted).length;
  final inReview  = current.where((t) => t.isInReview).length;
  final overdue   = current.where((t) => t.isUrgent).length;
  final pending   = current.where((t) => t.isPending).length;

  final completedTasks = historical.where((t) => t.completedAt != null).toList();

  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ── Racha de días consecutivos con completadas ─────────────
  final completionDays = completedTasks
      .map((t) => DateTime(
            t.completedAt!.year,
            t.completedAt!.month,
            t.completedAt!.day,
          ))
      .toSet();

  int streak = 0;
  var checkDay = today;
  while (completionDays.contains(checkDay)) {
    streak++;
    checkDay = checkDay.subtract(const Duration(days: 1));
  }

  // ── Últimos 7 días ─────────────────────────────────────────
  final last7Days = List.generate(7, (i) {
    final day = today.subtract(Duration(days: 6 - i));
    final count = completedTasks.where((t) {
      final d = DateTime(
          t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      return d == day;
    }).length;
    return DayStat(date: day, count: count);
  });

  // ── Últimas 4 semanas ──────────────────────────────────────
  final last4Weeks = List.generate(4, (i) {
    final weekEnd   = today.subtract(Duration(days: (3 - i) * 7));
    final weekStart = weekEnd.subtract(const Duration(days: 6));
    final count = completedTasks.where((t) {
      final d = DateTime(
          t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
      return !d.isBefore(weekStart) && !d.isAfter(weekEnd);
    }).length;
    return DayStat(date: weekStart, count: count);
  });

  // ── Por materia ────────────────────────────────────────────
  final subjects = scored.map((t) => t.subject).toSet();
  final bySubject = subjects.map((s) {
    final sub = scored.where((t) => t.subject == s).toList();
    return SubjectStat(
      subject: s,
      total:     sub.length,
      completed: sub.where((t) => t.isCompleted).length,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  // ── A tiempo vs tarde ──────────────────────────────────────
  int onTime = 0, late = 0;
  for (final t in completedTasks) {
    if (t.completedAt!.isBefore(t.dueDate) ||
        t.completedAt!.isAtSameMomentAs(t.dueDate)) {
      onTime++;
    } else {
      late++;
    }
  }

  // ── Esta semana vs semana pasada ───────────────────────────
  final thisWeekStart = today.subtract(Duration(days: today.weekday - 1));
  final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
  final lastWeekEnd   = thisWeekStart.subtract(const Duration(days: 1));

  final thisWeek = completedTasks.where((t) {
    final d = DateTime(
        t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
    return !d.isBefore(thisWeekStart);
  }).length;

  final lastWeek = completedTasks.where((t) {
    final d = DateTime(
        t.completedAt!.year, t.completedAt!.month, t.completedAt!.day);
    return !d.isBefore(lastWeekStart) && !d.isAfter(lastWeekEnd);
  }).length;

  return TaskStats(
    total:               total,
    completed:           completed,
    pending:             pending,
    inReview:            inReview,
    overdue:             overdue,
    completionRate:      total == 0 ? 0 : completed / total,
    streak:              streak,
    bySubject:           bySubject,
    last7Days:           last7Days,
    last4Weeks:          last4Weeks,
    completedOnTime:     onTime,
    completedLate:       late,
    thisWeekCompleted:   thisWeek,
    lastWeekCompleted:   lastWeek,
    totalHistorical:     historical.length,
  );
}
