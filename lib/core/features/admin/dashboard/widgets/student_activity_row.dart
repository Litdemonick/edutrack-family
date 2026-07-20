import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

class StudentActivityRow extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const StudentActivityRow({super.key, required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.statusGreen.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                size: 18, color: AppColors.statusGreen),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${task.subject} • ${task.completedAt != null ? EduDateUtils.shortDateLabel(task.completedAt!) : "—"}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (task.hasEvidence)
            const Icon(Icons.photo_camera_outlined,
                size: 16, color: AppColors.statusGreen),
        ],
      ),
    );
  }
}
