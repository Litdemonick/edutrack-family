import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';

// ═══════════════════════════════════════════════════════════════
// HISTORY SCREEN — EduTrack Family
// Log de toda la actividad del app (solo visible para admin).
// ═══════════════════════════════════════════════════════════════

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark         = Theme.of(context).brightness == Brightness.dark;
    final notifications  = ref.watch(notificationProvider);

    final sorted = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            title: const Text(
              'Historial de actividad',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
            actions: [
              if (sorted.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Limpiar historial',
                  onPressed: () => _confirmClear(context, ref),
                ),
            ],
          ),

          if (sorted.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: EmptyState(
                  emoji: '📋',
                  title: 'Sin actividad aún',
                  subtitle: 'Aquí verás todo lo que pase en la app:\n'
                      'tareas creadas, evidencias, aprobaciones y más.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  _buildItems(context, ref, sorted, isDark),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Agrupa por día y construye la lista de widgets
  // ─────────────────────────────────────────────────────────────
  List<Widget> _buildItems(
    BuildContext context,
    WidgetRef ref,
    List<InternalNotification> sorted,
    bool isDark,
  ) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final grouped = <DateTime, List<InternalNotification>>{};
    for (final n in sorted) {
      final day = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      grouped.putIfAbsent(day, () => []).add(n);
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final day = entry.key;
      final String label;
      if (day == today)          { label = 'HOY'; }
      else if (day == yesterday) { label = 'AYER'; }
      else                       { label = EduDateUtils.shortDateLabel(day); }

      widgets.add(_DayHeader(label: label, isDark: isDark));

      for (final n in entry.value) {
        widgets.add(
          Dismissible(
            key: Key(n.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.statusRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.statusRed),
            ),
            onDismissed: (_) =>
                ref.read(notificationProvider.notifier).delete(n.id),
            child: _ActivityItem(
              notification: n,
              isDark: isDark,
              onTap: () => _navigate(context, ref, n),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
    }
    return widgets;
  }

  // ─────────────────────────────────────────────────────────────
  // Navegación al tocar — busca tarea o evento por ID
  // ─────────────────────────────────────────────────────────────
  void _navigate(
    BuildContext context,
    WidgetRef ref,
    InternalNotification n,
  ) {
    if (n.taskId == null) return;

    final isEvent = n.type == NotificationType.eventCreated ||
        n.type == NotificationType.eventUpdated;

    if (isEvent) {
      EventModel? event;
      for (final e in ref.read(eventProvider).valueOrNull ?? []) {
        if (e.id == n.taskId) { event = e; break; }
      }
      if (event != null) {
        context.push(AppRoutes.eventView,
            extra: {'event': event, 'isAdmin': true});
      } else {
        _snack(context, 'El evento ya no existe o fue eliminado.');
      }
    } else {
      TaskModel? task;
      for (final t in ref.read(taskProvider).valueOrNull ?? []) {
        if (t.id == n.taskId) { task = t; break; }
      }
      if (task != null) {
        context.push(AppRoutes.taskView,
            extra: {'task': task, 'isAdmin': true});
      } else {
        _snack(context, 'La tarea ya no existe o fue eliminada.');
      }
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Nunito')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Confirmación para limpiar todo el historial
  // ─────────────────────────────────────────────────────────────
  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Limpiar historial',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Se eliminarán todos los registros. Esta acción no se puede deshacer.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(notificationProvider.notifier).clear();
            },
            child: const Text('Limpiar',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ENCABEZADO DE DÍA
// ─────────────────────────────────────────────────────────────
class _DayHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _DayHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ITEM DE ACTIVIDAD
// ─────────────────────────────────────────────────────────────
class _ActivityItem extends StatelessWidget {
  final InternalNotification notification;
  final bool isDark;
  final VoidCallback onTap;
  const _ActivityItem({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  Color get _color {
    switch (notification.type) {
      case NotificationType.taskAssigned:    return AppColors.accentBlue;
      case NotificationType.taskUpdated:     return AppColors.accentBlue;
      case NotificationType.taskOverdue:     return AppColors.statusRed;
      case NotificationType.taskCompleted:   return AppColors.statusGreen;
      case NotificationType.taskAccepted:    return AppColors.statusGreen;
      case NotificationType.taskRejected:    return AppColors.statusRed;
      case NotificationType.taskDeleted:     return AppColors.statusRed;
      case NotificationType.evidenceUploaded:return const Color(0xFF00BCD4);
      case NotificationType.eventCreated:    return const Color(0xFF9C27B0);
      case NotificationType.eventUpdated:    return const Color(0xFF9C27B0);
      case NotificationType.eventDeleted:    return const Color(0xFF9C27B0);
      case NotificationType.eventReminder:   return const Color(0xFF9C27B0);
      case NotificationType.deadline:        return AppColors.statusAmber;
      case NotificationType.general:         return AppColors.grey;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case NotificationType.taskAssigned:    return Icons.assignment_rounded;
      case NotificationType.taskUpdated:     return Icons.edit_rounded;
      case NotificationType.taskOverdue:     return Icons.warning_rounded;
      case NotificationType.taskCompleted:   return Icons.check_circle_rounded;
      case NotificationType.taskAccepted:    return Icons.verified_rounded;
      case NotificationType.taskRejected:    return Icons.cancel_rounded;
      case NotificationType.taskDeleted:     return Icons.delete_rounded;
      case NotificationType.evidenceUploaded:return Icons.camera_alt_rounded;
      case NotificationType.eventCreated:    return Icons.event_rounded;
      case NotificationType.eventUpdated:    return Icons.event_rounded;
      case NotificationType.eventDeleted:    return Icons.event_busy_rounded;
      case NotificationType.eventReminder:   return Icons.alarm_rounded;
      case NotificationType.deadline:        return Icons.alarm_rounded;
      case NotificationType.general:         return Icons.info_rounded;
    }
  }

  bool get _navigable =>
      notification.taskId != null &&
      notification.type != NotificationType.general;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigable ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Icono de tipo ───────────────────────────────
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _color, size: 20),
            ),
            const SizedBox(width: 12),

            // ── Texto ───────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    EduDateUtils.timeLabel(notification.createdAt),
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: isDark ? Colors.white30 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),

            // ── Flecha si es navegable ───────────────────────
            if (_navigable) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.white30 : Colors.black38,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
