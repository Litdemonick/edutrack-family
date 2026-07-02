import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT DETAIL SCREEN — EduTrack Family
// Vista completa de un evento del calendario escolar.
// ═══════════════════════════════════════════════════════════════

class EventDetailScreen extends ConsumerWidget {
  final EventModel event;
  final bool isAdmin;

  const EventDetailScreen({super.key, required this.event, this.isAdmin = false});

  Color get _statusColor {
    if (event.isPast) return AppColors.grey;
    if (event.isToday) return AppColors.statusRed;
    if (event.isSoon) return AppColors.statusAmber;
    return AppColors.accentBlue;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = _statusColor;
    final chipsTop = MediaQuery.of(context).padding.top + kToolbarHeight + 10;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con gradiente ─────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  tooltip: 'Editar evento',
                  onPressed: () {
                    context.pop();
                    context.push(AppRoutes.adminEditEventPath(event.id), extra: event);
                  },
                ),
            ],
            backgroundColor: color,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 14),
              title: Text(
                event.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.event_rounded,
                        size: 160,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    // Badges en la zona SUPERIOR — el título animado nunca llega aquí
                    Positioned(
                      left: 20,
                      right: 20,
                      top: chipsTop,
                      child: Row(
                        children: [
                          Text(
                            event.type.emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              event.type.label,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado del evento
                  _StatusBadge(event: event, isDark: isDark),
                  const SizedBox(height: 14),

                  // Información del evento
                  _InfoCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_month_rounded,
                          label: 'Fecha',
                          value: event.isAllDay
                              ? EduDateUtils.fullDateLabel(event.date)
                              : '${EduDateUtils.fullDateLabel(event.date)}  ·  ${EduDateUtils.timeLabel(event.date)}',
                          isDark: isDark,
                          valueColor: color,
                        ),
                        if (event.endDate != null) ...[
                          _Divider(isDark: isDark),
                          _InfoRow(
                            icon: Icons.event_available_rounded,
                            label: 'Fecha de término',
                            value: EduDateUtils.fullDateLabel(event.endDate!),
                            isDark: isDark,
                          ),
                        ],
                        _Divider(isDark: isDark),
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Duración',
                          value: event.isAllDay
                              ? 'Todo el día'
                              : EduDateUtils.timeLabel(event.date),
                          isDark: isDark,
                        ),
                        _Divider(isDark: isDark),
                        _InfoRow(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Estado',
                          value: event.isPast
                              ? 'Evento pasado'
                              : event.isToday
                                  ? '¡Hoy!'
                                  : event.daysLeft == 1
                                      ? 'Mañana'
                                      : 'En ${event.daysLeft} días',
                          isDark: isDark,
                          valueColor: color,
                        ),
                      ],
                    ),
                  ),

                  // Descripción
                  if (event.description != null && event.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descripción',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            event.description!,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              height: 1.55,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Botones de acción (admin) ────────────────
                  if (isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navyBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          context.pop();
                          context.push(AppRoutes.adminEditEventPath(event.id), extra: event);
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: const Text(
                          'Editar evento',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusRed,
                          side: const BorderSide(color: AppColors.statusRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _confirmDelete(context, ref),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text(
                          'Eliminar evento',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Eliminar evento',
      message: '¿Eliminar "${event.title}"? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(eventProvider.notifier).deleteEvent(event.id);
      if (context.mounted) context.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// BADGE DE ESTADO DEL EVENTO
// ─────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final EventModel event;
  final bool isDark;

  const _StatusBadge({required this.event, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isPast = event.isPast;
    final isToday = event.isToday;
    final isSoon = event.isSoon;

    final color = isPast
        ? AppColors.grey
        : isToday
            ? AppColors.statusRed
            : isSoon
                ? AppColors.statusAmber
                : AppColors.accentBlue;

    final label = isPast
        ? 'Evento pasado'
        : isToday
            ? '¡Hoy!'
            : isSoon
                ? 'Próximo'
                : 'Programado';

    final icon = isPast
        ? Icons.history_rounded
        : isToday
            ? Icons.today_rounded
            : isSoon
                ? Icons.upcoming_rounded
                : Icons.event_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNOS
// ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _InfoCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (valueColor ?? AppColors.accentBlue).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: valueColor ?? AppColors.accentBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppColors.grey,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? Colors.white : AppColors.navyBlue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 20, color: isDark ? Colors.white10 : AppColors.lightGrey);
  }
}
