import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';

// ═══════════════════════════════════════════════════════════════
// CALENDAR TASK ITEM — EduTrack Family
// Fila compacta de tarea para el calendario mensual.
// Detecta el rol del usuario y abre la vista correcta.
// ═══════════════════════════════════════════════════════════════

class CalendarTaskItem extends ConsumerWidget {
  final TaskModel task;

  const CalendarTaskItem({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: task.isCompleted, isOverdue: task.isUrgent);
    final isAdmin = ref.watch(authProvider)?.isAdmin ?? false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(
            AppRoutes.taskView,
            extra: {'task': task, 'isAdmin': isAdmin},
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.subject,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.grey,
                      ),
                    ),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted
                            ? (isDark ? Colors.white38 : AppColors.grey)
                            : (isDark ? Colors.white : AppColors.navyBlue),
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TrafficLightBadge(task: task, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
