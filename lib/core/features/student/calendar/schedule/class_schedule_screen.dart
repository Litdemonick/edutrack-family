import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/schedule_model.dart';

// ═══════════════════════════════════════════════════════════════
// CLASS SCHEDULE SCREEN — EduTrack Family
// Horario semanal de Yordan — Grado 5°B, Maestra: Ereida De Beitia
// ═══════════════════════════════════════════════════════════════

class ClassScheduleScreen extends StatefulWidget {
  const ClassScheduleScreen({super.key});

  @override
  State<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {
  // Default to today's weekday (clamped to 1–5), or 1 on weekends
  late int _selectedDay;

  @override
  void initState() {
    super.initState();
    final wd = DateTime.now().weekday;
    _selectedDay = wd > 5 ? 1 : wd;
  }

  static const _dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie'];
  static const _dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entries = YordanSchedule.entries
        .where((e) => e.weekday == _selectedDay)
        .toList();
    final currentClass = YordanSchedule.currentClass;
    final isToday = DateTime.now().weekday == _selectedDay;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          expandedHeight: 0,
          title: const Text(
            'Horario de Clases',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Selector de día
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: List.generate(5, (i) {
                final day = i + 1;
                final isSelected = day == _selectedDay;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentBlue
                            : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentBlue
                              : (isDark
                                  ? Colors.white12
                                  : AppColors.lightGrey),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _dayLabels[i],
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white70
                                      : AppColors.navyBlue),
                            ),
                          ),
                          if (DateTime.now().weekday == day)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Colors.white70
                                    : AppColors.accentBlue,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Encabezado del día
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  _dayNames[_selectedDay - 1],
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '• ${YordanSchedule.grade}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
                const Spacer(),
                if (isToday && currentClass != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ahora: ${currentClass.subject}',
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Lista de períodos
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final entry = entries[i];
                final isCurrent = isToday &&
                    currentClass != null &&
                    currentClass.id == entry.id;

                return _ScheduleRow(
                  entry: entry,
                  isCurrent: isCurrent,
                  isDark: isDark,
                );
              },
              childCount: entries.length,
            ),
          ),
        ),

        // Info de maestra al final
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E2E)
                    : AppColors.offWhite,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded,
                      size: 18, color: AppColors.accentBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Maestra: ${YordanSchedule.teacher}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.navyBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FILA DE PERÍODO
// ─────────────────────────────────────────────────────────────
class _ScheduleRow extends StatelessWidget {
  final ScheduleEntry entry;
  final bool isCurrent;
  final bool isDark;

  const _ScheduleRow({
    required this.entry,
    required this.isCurrent,
    required this.isDark,
  });

  Color _subjectColor(String subject) {
    final s = subject.toLowerCase();
    if (s.contains('matemát')) return const Color(0xFF4CAF50);
    if (s.contains('español')) return const Color(0xFF2196F3);
    if (s.contains('inglés')) return const Color(0xFF9C27B0);
    if (s.contains('naturales')) return const Color(0xFF00BCD4);
    if (s.contains('sociales')) return const Color(0xFFFF9800);
    if (s.contains('física')) return const Color(0xFFE91E63);
    if (s.contains('artíst')) return const Color(0xFFFF5722);
    if (s.contains('religión')) return const Color(0xFF795548);
    if (s.contains('informát')) return const Color(0xFF607D8B);
    if (s.contains('laborat')) return const Color(0xFF009688);
    if (s.contains('agropec')) return const Color(0xFF8BC34A);
    if (s.contains('fdc')) return const Color(0xFFCDDC39);
    if (s.contains('cívico')) return const Color(0xFFF44336);
    return AppColors.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    if (entry.isBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.free_breakfast_outlined,
                size: 14, color: AppColors.statusAmber),
            const SizedBox(width: 6),
            Text(
              'Receso  ${entry.startTime} – ${entry.endTime}',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: AppColors.statusAmber,
              ),
            ),
          ],
        ),
      );
    }

    final color = _subjectColor(entry.subject);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withValues(alpha: 0.15)
            : (isDark ? const Color(0xFF1E1E2E) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent ? color : color.withValues(alpha: 0.2),
          width: isCurrent ? 1.5 : 1,
        ),
        boxShadow: isCurrent
            ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.subject,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCurrent
                        ? color
                        : (isDark ? Colors.white : AppColors.navyBlue),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.timeRange,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Ahora',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
