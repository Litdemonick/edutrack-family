import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/notification_utils.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/repositories/task_repository.dart';
import 'package:edutrack_family/core/data/local/repositories/event_repository.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/schedule_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/services/sync_service.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATIONS SCREEN — EduTrack Family
// Historial de notificaciones internas. Campana 🔔.
// ═══════════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationProvider.notifier).markAllRead();
        NotificationUtils.cancelSystemNotifications();
      }
    });
  }

  /// Sync manual e inmediato desde la propia campana — por si algo
  /// nuevo ya sincronizó en segundo plano pero todavía no se refleja
  /// aquí, sin depender de otra pantalla.
  Future<void> _manualRefresh() async {
    setState(() => _refreshing = true);
    try {
      await SyncService.instance.fullSync();
      if (!mounted) return;
      ref.read(taskProvider.notifier).loadTasks();
      ref.read(eventProvider.notifier).loadEvents();
      ref.read(scheduleProvider.notifier).load();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si llega una notificación nueva MIENTRAS esta pantalla ya está
    // abierta (el usuario la está mirando en ese momento), se marca
    // como leída sola — antes solo se marcaban las que ya existían al
    // entrar a la pantalla (initState), así que una que llegaba
    // después se quedaba marcada "no leída" aunque el usuario la
    // estuviera viendo en pantalla en ese mismo instante.
    ref.listen<List<InternalNotification>>(notificationProvider, (previous, next) {
      if (next.any((n) => !n.isRead)) {
        ref.read(notificationProvider.notifier).markAllRead();
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notificaciones',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _manualRefresh,
            tooltip: 'Actualizar',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CenteredConstrained(
        maxWidth: 960,
        child: notifications.isEmpty
            ? _EmptyNotifications(isDark: isDark)
            : _NotificationList(notifications: notifications, isDark: isDark),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LISTA DE NOTIFICACIONES
// ─────────────────────────────────────────────────────────────

class _NotificationList extends ConsumerWidget {
  final List<InternalNotification> notifications;
  final bool isDark;

  const _NotificationList(
      {required this.notifications, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ordenar: más reciente primero
    final sorted = [...notifications]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Agrupar por día manteniendo el orden de inserción (LinkedHashMap por defecto en Dart)
    final Map<DateTime, List<InternalNotification>> grouped = {};
    for (final n in sorted) {
      final day = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      grouped.putIfAbsent(day, () => []).add(n);
    }

    // Las claves ya están ordenadas de más reciente a más antigua
    final days = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
      itemCount: days.length,
      itemBuilder: (context, i) {
        final day = days[i];
        final group = grouped[day]!;
        final isToday = i == 0 && _isToday(day);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del grupo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  if (isToday)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.accentBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  Text(
                    _dayLabel(day),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: isToday
                          ? AppColors.accentBlue
                          : (isDark ? Colors.white38 : AppColors.grey),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      color: isDark ? Colors.white10 : AppColors.lightGrey,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${group.length}',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white24 : AppColors.lightGrey,
                    ),
                  ),
                ],
              ),
            ),
            ...group.map((n) => _NotificationTile(n: n, isDark: isDark)),
          ],
        );
      },
    );
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'HOY';
    if (day == yesterday) return 'AYER';

    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${day.day} ${months[day.month].toUpperCase()}.';
  }
}

// ─────────────────────────────────────────────────────────────
// TILE INDIVIDUAL
// ─────────────────────────────────────────────────────────────

class _NotificationTile extends ConsumerWidget {
  final InternalNotification n;
  final bool isDark;

  const _NotificationTile({required this.n, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg =
        isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final color = _typeColor(n.type);

    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.statusRed.withValues(alpha: 0.85),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) =>
          ref.read(notificationProvider.notifier).delete(n.id),
      child: GestureDetector(
        onTap: () async {
          ref.read(notificationProvider.notifier).markRead(n.id);
          if (n.taskId != null) {
            final task = await TaskRepository.instance.getTaskById(n.taskId!);
            if (task != null && context.mounted) {
              final user = ref.read(authProvider);
              context.push(AppRoutes.taskView, extra: {
                'task': task,
                'isAdmin': user?.isAdmin ?? false,
              });
            }
          } else if (n.eventId != null) {
            final event = await EventRepository.instance.getEventById(n.eventId!);
            if (event != null && context.mounted) {
              final user = ref.read(authProvider);
              context.push(AppRoutes.eventView, extra: {
                'event': event,
                'isAdmin': user?.isAdmin ?? false,
              });
            }
          } else if (n.route != null && context.mounted) {
            context.push(n.route!);
          }
        },
        child: Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: n.isRead
                ? null
                : Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 1,
                  ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Barra lateral de color
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: n.isRead
                        ? Colors.transparent
                        : color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // Icono
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(
                          alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _typeIcon(n.type),
                      size: 18,
                      color: color,
                    ),
                  ),
                ),
                // Contenido
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(4, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.title,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: n.isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.navyBlue,
                                ),
                              ),
                            ),
                            if (!n.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n.body,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : AppColors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _timeLabel(n.createdAt),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: isDark
                                ? Colors.white30
                                : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _typeColor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return AppColors.accentBlue;
      case NotificationType.taskCompleted:
        return AppColors.statusGreen;
      case NotificationType.taskRejected:
        return AppColors.statusRed;
      case NotificationType.taskAccepted:
        return AppColors.statusGreen;
      case NotificationType.taskDeleted:
        return AppColors.statusRed;
      case NotificationType.evidenceUploaded:
        return const Color(0xFF00BCD4);
      case NotificationType.deadline:
        return AppColors.statusAmber;
      case NotificationType.taskUpdated:
        return AppColors.accentBlue;
      case NotificationType.taskOverdue:
        return AppColors.statusRed;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventDeleted:
      case NotificationType.eventReminder:
        return const Color(0xFF9C27B0);
      case NotificationType.familyUpdate:
        return const Color(0xFF3F51B5);
      case NotificationType.seismicAlert:
        return const Color(0xFF7A0C0C);
      case NotificationType.wellnessCheck:
        return const Color(0xFFFF7A45);
      case NotificationType.general:
        return AppColors.grey;
    }
  }

  IconData _typeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Icons.assignment_rounded;
      case NotificationType.taskCompleted:
        return Icons.check_circle_rounded;
      case NotificationType.taskRejected:
        return Icons.cancel_rounded;
      case NotificationType.taskAccepted:
        return Icons.verified_rounded;
      case NotificationType.taskDeleted:
        return Icons.delete_rounded;
      case NotificationType.taskUpdated:
        return Icons.edit_rounded;
      case NotificationType.taskOverdue:
        return Icons.warning_rounded;
      case NotificationType.eventCreated:
      case NotificationType.eventUpdated:
      case NotificationType.eventDeleted:
        return Icons.event_rounded;
      case NotificationType.eventReminder:
        return Icons.alarm_rounded;
      case NotificationType.evidenceUploaded:
        return Icons.photo_library_rounded;
      case NotificationType.deadline:
        return Icons.alarm_rounded;
      case NotificationType.familyUpdate:
        return Icons.link_rounded;
      case NotificationType.seismicAlert:
        return Icons.public_rounded;
      case NotificationType.wellnessCheck:
        return Icons.favorite_rounded;
      case NotificationType.general:
        return Icons.notifications_rounded;
    }
  }

  String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }
}

// ─────────────────────────────────────────────────────────────
// ESTADO VACÍO
// ─────────────────────────────────────────────────────────────

class _EmptyNotifications extends StatelessWidget {
  final bool isDark;
  const _EmptyNotifications({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin notificaciones',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aquí verás los avisos de tareas\ny actividades importantes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
