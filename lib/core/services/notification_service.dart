import 'package:edutrack_family/core/constants/utils/notification_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION SERVICE — EduTrack Family
// Orquesta el ciclo de vida de notificaciones de tareas:
// programa al crear, cancela al completar o eliminar.
// ═══════════════════════════════════════════════════════════════

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> scheduleForTask(TaskModel task) async {
    await NotificationUtils.scheduleTaskNotifications(
      taskId: task.id,
      taskTitle: task.title,
      dueDate: task.dueDate,
      category: task.category,
    );
  }

  Future<void> cancelForTask(String taskId) async {
    await NotificationUtils.cancelTaskNotifications(taskId);
  }

  Future<void> alertTaskNotDone({
    required String taskId,
    required String taskTitle,
    String linkedPersonWord = 'hijo/a',
  }) async {
    await NotificationUtils.showTaskNotDoneAlert(
      taskId: taskId,
      taskTitle: taskTitle,
      linkedPersonWord: linkedPersonWord,
    );
  }

  Future<void> cancelAll() async {
    await NotificationUtils.cancelAll();
  }
}
