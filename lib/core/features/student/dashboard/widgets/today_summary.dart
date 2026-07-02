import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/task_priority_card.dart';

// ═══════════════════════════════════════════════════════════════
// TODAY SUMMARY — EduTrack Family
// Tarjeta de progreso circular + grid 2×2 de stats interactivas.
// ═══════════════════════════════════════════════════════════════

class TodaySummary extends StatelessWidget {
  final List<TaskModel> tasks;

  const TodaySummary({super.key, required this.tasks});

  String _motivationalText(double progress) {
    if (progress == 1.0) return '¡Todo completado! 🎉';
    if (progress >= 0.75) return '¡Casi lo logras! ✨';
    if (progress >= 0.5) return '¡Más de la mitad! 🔥';
    if (progress >= 0.25) return '¡Vas por buen camino!';
    if (progress > 0) return '¡Buen comienzo! 💪';
    return '¡Vamos, tú puedes! 💪';
  }

  void _showSheet(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<TaskModel> filtered,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskListSheet(
        title: title,
        icon: icon,
        color: color,
        tasks: filtered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final total = tasks.where((t) => !t.isArchived).toList();
    final completed = tasks.where((t) => t.isCompleted).toList();
    final urgent = tasks.where((t) => t.isUrgent).toList();
    final dueToday = tasks.where((t) => t.isDueToday).toList();

    final completedCount = completed.length;
    final totalCount = total.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final pct = (progress * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fecha ────────────────────────────────────────────
          Text(
            EduDateUtils.fullDateLabel(DateTime.now()),
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: isDark ? Colors.white54 : AppColors.grey,
            ),
          ),
          const SizedBox(height: 10),

          // ── Tarjeta de progreso ───────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2347), Color(0xFF1A5098)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A5098).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Texto izquierdo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Progreso del día',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontFamily: 'Poppins'),
                          children: [
                            TextSpan(
                              text: '$completedCount ',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1,
                              ),
                            ),
                            TextSpan(
                              text: '/ $totalCount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'tareas completadas',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _motivationalText(progress),
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Indicador circular de progreso
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 7,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 82,
                      height: 82,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        strokeCap: StrokeCap.round,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        Text(
                          'listo',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Grid 2×2 de stats interactivas ───────────────────
          Row(
            children: [
              _StatChip(
                label: 'Total',
                value: totalCount,
                color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
                icon: Icons.assignment_outlined,
                onTap: () => _showSheet(
                  context,
                  'Todas las tareas',
                  Icons.assignment_outlined,
                  isDark ? AppColors.skyBlue : AppColors.navyBlue,
                  total,
                ),
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Completadas',
                value: completedCount,
                color: AppColors.statusGreen,
                icon: Icons.check_circle_outline_rounded,
                onTap: () => _showSheet(
                  context,
                  'Completadas',
                  Icons.check_circle_outline_rounded,
                  AppColors.statusGreen,
                  completed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                label: 'Urgentes',
                value: urgent.length,
                color: AppColors.statusRed,
                icon: Icons.warning_amber_rounded,
                onTap: () => _showSheet(
                  context,
                  'Urgentes',
                  Icons.warning_amber_rounded,
                  AppColors.statusRed,
                  urgent,
                ),
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: 'Vencen hoy',
                value: dueToday.length,
                color: AppColors.statusAmber,
                icon: Icons.today_outlined,
                onTap: () => _showSheet(
                  context,
                  'Vencen hoy',
                  Icons.today_outlined,
                  AppColors.statusAmber,
                  dueToday,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CHIP DE ESTADÍSTICA — grid 2×2, con marca de agua y gradiente
// ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: isDark ? 0.20 : 0.13),
                  color.withValues(alpha: isDark ? 0.09 : 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.24 : 0.20),
              ),
            ),
            child: Stack(
              children: [
                // Barra de acento superior
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.65),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                  ),
                ),
                // Icono marca de agua
                Positioned(
                  right: -10, bottom: -10,
                  child: Icon(icon, size: 58,
                      color: color.withValues(alpha: 0.09)),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Icono pequeño + flecha
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 14, color: color),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_forward_ios_rounded,
                              size: 9,
                              color: color.withValues(alpha: 0.50)),
                        ],
                      ),
                      // Valor y etiqueta
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$value',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: color,
                              height: 1,
                            ),
                          ),
                          Text(
                            label,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color.withValues(alpha: 0.75),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — lista de tareas filtradas
// ─────────────────────────────────────────────────────────────

class _TaskListSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<TaskModel> tasks;

  const _TaskListSheet({
    required this.title,
    required this.icon,
    required this.color,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${tasks.length}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Text(
                        'Sin tareas en esta categoría',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          color: isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: tasks.length,
                      itemBuilder: (_, i) => TaskPriorityCard(task: tasks[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
