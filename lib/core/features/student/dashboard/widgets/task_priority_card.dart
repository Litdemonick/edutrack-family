import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';

// ═══════════════════════════════════════════════════════════════
// TASK PRIORITY CARD — EduTrack Family
// Tarjeta de tarea con semáforo. Al tocar muestra hoja de acciones.
// ═══════════════════════════════════════════════════════════════

class TaskPriorityCard extends ConsumerWidget {
  final TaskModel task;

  const TaskPriorityCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: task.isCompleted, isOverdue: task.isUrgent);
    final inReview = task.isInReview;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showActionSheet(context, isDark),
          borderRadius: BorderRadius.circular(16),
          child: Opacity(
            opacity: inReview ? 0.80 : 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: color.withValues(alpha: task.isCompleted ? 0.15 : 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Indicador lateral de color
                  Container(
                    width: 4,
                    height: 56,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: task.isCompleted ? 0.4 : 1.0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Contenido principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.subject,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white54 : AppColors.grey,
                                  letterSpacing: 0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (inReview)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  '⏳ Revisión',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7C4DFF),
                                  ),
                                ),
                              )
                            else
                              TrafficLightBadge(task: task),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          task.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: task.isCompleted
                                ? (isDark ? Colors.white38 : AppColors.grey)
                                : (isDark ? Colors.white : AppColors.navyBlue),
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 11,
                              color: isDark ? Colors.white38 : AppColors.grey,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              EduDateUtils.shortDateLabel(task.dueDate),
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                color: isDark ? Colors.white38 : AppColors.grey,
                              ),
                            ),
                            if (task.category.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : AppColors.offWhite,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  task.category,
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 10,
                                    color: isDark ? Colors.white54 : AppColors.grey,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (task.hasEvidence)
                              Icon(Icons.photo_camera_outlined, size: 14, color: AppColors.statusGreen),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 6),
                  Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: isDark ? Colors.white24 : AppColors.lightGrey,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, bool isDark) {
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: task.isCompleted, isOverdue: task.isUrgent);
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Task preview
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navyBlue,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        task.subject,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: isDark ? Colors.white10 : AppColors.lightGrey),
            const SizedBox(height: 8),

            // Acción: Ver detalles
            _ActionTile(
              icon: Icons.visibility_outlined,
              label: 'Ver detalles',
              color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.taskView, extra: {'task': task, 'isAdmin': false});
              },
            ),

            // Acción: Completar (solo si no está completa ni en revisión)
            if (!task.isCompleted && !task.isInReview)
              _ActionTile(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completar tarea',
                color: AppColors.statusGreen,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.studentCompleteTaskPath(task.id), extra: task);
                },
              ),

            // Info: en revisión
            if (task.isInReview)
              _ActionTile(
                icon: Icons.hourglass_top_rounded,
                label: 'Esperando revisión del admin',
                color: const Color(0xFF7C4DFF),
                isDark: isDark,
                onTap: () => Navigator.pop(context),
                isInfo: true,
              ),
          ],
        ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTION TILE — fila de acción en el bottom sheet
// ─────────────────────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final bool isInfo;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.isInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isInfo ? 0.08 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color.withValues(alpha: isInfo ? 0.6 : 1.0)),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isInfo
                      ? (isDark ? Colors.white38 : AppColors.grey)
                      : (isDark ? Colors.white : AppColors.navyBlue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
