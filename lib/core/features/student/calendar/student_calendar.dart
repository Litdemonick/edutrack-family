import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/features/student/calendar/widgets/calendar_task_item.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT CALENDAR — EduTrack Family
// Calendario mensual con indicadores de tareas (azul parpadeante)
// y eventos (morado fijo). Al tocar un día abre un bottom sheet.
// ═══════════════════════════════════════════════════════════════

class StudentCalendar extends ConsumerStatefulWidget {
  const StudentCalendar({super.key});

  @override
  ConsumerState<StudentCalendar> createState() => _StudentCalendarState();
}

class _StudentCalendarState extends ConsumerState<StudentCalendar>
    with SingleTickerProviderStateMixin {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  late final AnimationController _blinkCtrl;
  late final Animation<double> _blinkAnim;

  @override
  void initState() {
    super.initState();
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _blinkAnim = CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    super.dispose();
  }

  void _onDayTapped(
    BuildContext context,
    DateTime date,
    List<TaskModel> allTasks,
    List<EventModel> allEvents,
    bool isDark,
  ) {
    final dayTasks = allTasks
        .where((t) => EduDateUtils.isSameDay(t.dueDate, date))
        .toList();
    final dayEvents = allEvents
        .where((e) => EduDateUtils.isSameDay(e.date, date))
        .toList();
    setState(() => _selectedDay = date);
    // Delay sheet until after the setState rebuild to avoid visual stutter
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showDaySheet(context, date, dayTasks, dayEvents, isDark);
    });
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<TaskModel> tasks,
    List<EventModel> events,
    bool isDark,
  ) {
    final total = tasks.length + events.length;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayDetailSheet(
        date: date,
        tasks: tasks,
        events: events,
        isDark: isDark,
        initialSize: total == 0 ? 0.42 : (total <= 3 ? 0.68 : 0.85),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(taskProvider);
    final eventsAsync = ref.watch(eventProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return tasksAsync.when(
      data: (tasks) => eventsAsync.when(
        data: (events) => _buildCalendar(context, tasks, events, isDark),
        loading: () => _buildCalendar(context, tasks, [], isDark),
        error: (_, _) => _buildCalendar(context, tasks, [], isDark),
      ),
      loading: () => const Center(child: LoadingWidget()),
      error: (e, _) =>
          EmptyState(emoji: '⚠️', title: 'Error', subtitle: e.toString()),
    );
  }

  Widget _buildCalendar(
    BuildContext context,
    List<TaskModel> tasks,
    List<EventModel> events,
    bool isDark,
  ) {
    final taskDays = <DateTime>{};
    for (final t in tasks) {
      if (!t.isCompleted && !t.isArchived) {
        taskDays.add(EduDateUtils.normalizeDate(t.dueDate));
      }
    }
    final eventDays = <DateTime>{};
    for (final e in events) {
      eventDays.add(EduDateUtils.normalizeDate(e.date));
    }

    return CustomScrollView(
      slivers: [
        // ── AppBar con mes y navegación ──────────────────────
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          expandedHeight: 0,
          title: Text(
            EduDateUtils.monthYearLabel(_focusedMonth),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month - 1);
              }),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => setState(() {
                _focusedMonth =
                    DateTime(_focusedMonth.year, _focusedMonth.month + 1);
              }),
            ),
          ],
        ),

        // ── Calendario ──────────────────────────────────────
        SliverToBoxAdapter(
          child: _MiniCalendar(
            focusedMonth: _focusedMonth,
            selectedDay: _selectedDay,
            taskDays: taskDays,
            eventDays: eventDays,
            blinkAnim: _blinkAnim,
            isDark: isDark,
            onDaySelected: (date) =>
                _onDayTapped(context, date, tasks, events, isDark),
          ),
        ),

        // ── Leyenda ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
            child: Row(
              children: [
                _LegendItem(
                  color: AppColors.accentBlue,
                  label: 'Tareas pendientes',
                  blink: true,
                  blinkAnim: _blinkAnim,
                ),
                const SizedBox(width: 20),
                _LegendItem(
                  color: const Color(0xFF7C4DFF),
                  label: 'Eventos',
                  blink: false,
                  blinkAnim: _blinkAnim,
                ),
              ],
            ),
          ),
        ),

        // ── Pista interactiva ────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 5, 24, 24),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: isDark ? Colors.white30 : AppColors.grey,
                ),
                const SizedBox(width: 5),
                Text(
                  'Toca cualquier día para ver el detalle',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MINI CALENDAR — grilla mensual con indicadores debajo del número
// Puntos fuera del círculo de selección para que siempre sean visibles.
// ─────────────────────────────────────────────────────────────

class _MiniCalendar extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final Set<DateTime> taskDays;
  final Set<DateTime> eventDays;
  final Animation<double> blinkAnim;
  final bool isDark;
  final ValueChanged<DateTime> onDaySelected;

  const _MiniCalendar({
    required this.focusedMonth,
    required this.selectedDay,
    required this.taskDays,
    required this.eventDays,
    required this.blinkAnim,
    required this.isDark,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final startOffset = (firstDay.weekday - 1) % 7;
    const dayHeaders = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabecera de días de la semana
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: dayHeaders.map((h) {
                final isSun = h == 'D';
                final isSat = h == 'S';
                return Expanded(
                  child: Center(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSun || isSat
                            ? AppColors.accentBlue
                                .withValues(alpha: isDark ? 0.7 : 0.55)
                            : (isDark ? Colors.white38 : AppColors.grey),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Cuadrícula de días
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 2,
              crossAxisSpacing: 0,
              childAspectRatio: 0.75,
            ),
            itemCount: startOffset + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox();

              final dayNum = index - startOffset + 1;
              final date = DateTime(
                  focusedMonth.year, focusedMonth.month, dayNum);
              final normalized = EduDateUtils.normalizeDate(date);
              final isSelected = EduDateUtils.isSameDay(date, selectedDay);
              final isToday = EduDateUtils.isToday(date);
              final hasTask = taskDays.contains(normalized);
              final hasEvent = eventDays.contains(normalized);

              Color textColor;
              Color? circleBg;
              Border? circleBorder;

              if (isSelected) {
                circleBg = AppColors.accentBlue;
                textColor = Colors.white;
              } else if (isToday) {
                circleBorder = Border.all(
                  color: AppColors.accentBlue,
                  width: 1.5,
                );
                textColor = AppColors.accentBlue;
              } else {
                textColor = isDark ? Colors.white70 : AppColors.navyBlue;
              }

              return GestureDetector(
                onTap: () => onDaySelected(date),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Número del día con fondo circular ──
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: circleBg,
                        shape: BoxShape.circle,
                        border: circleBorder,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accentBlue
                                      .withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNum',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),

                    // ── Puntos DEBAJO del círculo ─────────
                    // Siempre reserva espacio (SizedBox de 8px)
                    // para que todas las celdas tengan la misma altura.
                    SizedBox(
                      height: 8,
                      child: (hasTask || hasEvent)
                          ? Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasTask)
                                    AnimatedBuilder(
                                      animation: blinkAnim,
                                      builder: (_, child) => Opacity(
                                        opacity: 0.45 +
                                            blinkAnim.value * 0.55,
                                        child: Transform.scale(
                                          scale:
                                              0.75 + blinkAnim.value * 0.5,
                                          child: child,
                                        ),
                                      ),
                                      child: Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.accentBlue,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  if (hasTask && hasEvent)
                                    const SizedBox(width: 3),
                                  if (hasEvent)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                                .withValues(alpha: 0.85)
                                            : const Color(0xFF7C4DFF),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DAY DETAIL SHEET — bottom sheet con tareas y eventos del día
// ─────────────────────────────────────────────────────────────

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final List<TaskModel> tasks;
  final List<EventModel> events;
  final bool isDark;
  final double initialSize;

  const _DayDetailSheet({
    required this.date,
    required this.tasks,
    required this.events,
    required this.isDark,
    required this.initialSize,
  });

  @override
  Widget build(BuildContext context) {
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;
    final total = tasks.length + events.length;
    final isToday = EduDateUtils.isToday(date);

    return DraggableScrollableSheet(
      initialChildSize: initialSize,
      minChildSize: 0.30,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D2347), Color(0xFF1A5098)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          EduDateUtils.fullDateLabel(date),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isToday
                              ? '¡Hoy!'
                              : total == 0
                                  ? 'Día libre'
                                  : '$total ${total == 1 ? "actividad" : "actividades"}',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: isToday
                                ? AppColors.accentBlue
                                : (isDark
                                    ? Colors.white54
                                    : AppColors.grey),
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    _CountBadge(
                      count: tasks.length,
                      color: AppColors.accentBlue,
                      icon: Icons.assignment_outlined,
                    ),
                  if (tasks.isNotEmpty && events.isNotEmpty)
                    const SizedBox(width: 6),
                  if (events.isNotEmpty)
                    _CountBadge(
                      count: events.length,
                      color: const Color(0xFF7C4DFF),
                      icon: Icons.event_rounded,
                    ),
                ],
              ),
            ),

            Divider(
              height: 1,
              color: isDark ? Colors.white12 : AppColors.lightGrey,
            ),

            // ── Contenido ────────────────────────────────────
            Expanded(
              child: total == 0
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : AppColors.offWhite,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_available_rounded,
                              size: 30,
                              color: isDark
                                  ? Colors.white38
                                  : AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Día libre 🎉',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.navyBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sin tareas ni eventos este día.',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 13,
                              color:
                                  isDark ? Colors.white38 : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      controller: controller,
                      padding:
                          const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      children: [
                        if (events.isNotEmpty) ...[
                          _SheetSectionHeader(
                            icon: Icons.event_rounded,
                            title: 'Eventos (${events.length})',
                            color: const Color(0xFF7C4DFF),
                            isDark: isDark,
                          ),
                          ...events.map(
                              (e) => _EventItem(event: e, isDark: isDark)),
                          if (tasks.isNotEmpty)
                            const SizedBox(height: 12),
                        ],
                        if (tasks.isNotEmpty) ...[
                          _SheetSectionHeader(
                            icon: Icons.assignment_outlined,
                            title: 'Tareas (${tasks.length})',
                            color: AppColors.accentBlue,
                            isDark: isDark,
                          ),
                          ...tasks
                              .map((t) => CalendarTaskItem(task: t)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EVENT ITEM
// ─────────────────────────────────────────────────────────────

class _EventItem extends StatelessWidget {
  final EventModel event;
  final bool isDark;

  const _EventItem({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7C4DFF);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        splashColor: purple.withValues(alpha: 0.12),
        onTap: () {
          Navigator.of(context).pop();
          context.push(AppRoutes.eventView, extra: {'event': event, 'isAdmin': false});
        },
        child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: isDark ? 0.14 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purple.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(event.type.emoji,
                  style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.description!,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppColors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    event.type.label,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: purple,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────

class _SheetSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;

  const _SheetSectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  final IconData icon;

  const _CountBadge({
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool blink;
  final Animation<double> blinkAnim;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.blink,
    required this.blinkAnim,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    if (blink) {
      dot = AnimatedBuilder(
        animation: blinkAnim,
        builder: (_, child) => Opacity(
          opacity: 0.45 + blinkAnim.value * 0.55,
          child: Transform.scale(
            scale: 0.75 + blinkAnim.value * 0.5,
            child: child,
          ),
        ),
        child: dot,
      );
    }
    return Row(
      children: [
        dot,
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 12,
            color: isDark ? Colors.white54 : AppColors.grey,
          ),
        ),
      ],
    );
  }
}
