import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';

class PendingAlertCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const PendingAlertCard({super.key, required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: false, isOverdue: task.isUrgent);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          AppRoutes.taskView,
          extra: {'task': task, 'isAdmin': true},
        ),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
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
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      EduDateUtils.shortDateLabel(task.dueDate),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              TrafficLightBadge(task: task),
            ],
          ),
        ),
      ),
    );
  }
}
