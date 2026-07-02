import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

// ═══════════════════════════════════════════════════════════════
// TRAFFIC LIGHT BADGE — EduTrack Family
// Badge de semáforo: verde/amarillo/rojo según días restantes.
// ═══════════════════════════════════════════════════════════════

class TrafficLightBadge extends StatelessWidget {
  final TaskModel task;
  final bool compact;

  const TrafficLightBadge({super.key, required this.task, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final daysLeft = task.daysLeft;
    final isOverdue = task.isUrgent;
    final color = AppColors.forDaysLeft(daysLeft, isCompleted: task.isCompleted, isOverdue: isOverdue);
    final bgColor = AppColors.forDaysLeftLight(daysLeft, isCompleted: task.isCompleted, isOverdue: isOverdue);
    final label = task.isCompleted
        ? AppStrings.statusDone
        : isOverdue && daysLeft == 0
            ? 'Vencida hoy'
            : AppStrings.daysLeftLabel(daysLeft);

    if (compact) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 3),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
