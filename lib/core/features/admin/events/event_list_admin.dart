import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/shared/widgets/assigned_by_badge.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT LIST ADMIN — EduTrack Family
// Lista de eventos del calendario escolar para el admin.
// ═══════════════════════════════════════════════════════════════

class EventListAdmin extends ConsumerWidget {
  const EventListAdmin({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eventsAsync = ref.watch(eventProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            title: const Text(
              'Eventos Escolares',
              style: TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => context.push(AppRoutes.adminCreateEvent),
              ),
            ],
          ),

          eventsAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 64),
                    child: EmptyState(
                      emoji: '📅',
                      title: 'Sin eventos',
                      subtitle: 'Agrega eventos del calendario escolar.',
                    ),
                  ),
                );
              }

              final upcoming = events.where((e) => !e.isPast).toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              final past = events.where((e) => e.isPast).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              final items = <Widget>[
                if (upcoming.isNotEmpty) ...[
                  // Hero highlight for the next upcoming event
                  _UpcomingHeroCard(event: upcoming.first, isDark: isDark),
                  _SectionHeader(
                      title: 'Próximos',
                      count: upcoming.length,
                      isDark: isDark),
                  ...upcoming.map((e) => _EventRow(
                        event: e,
                        isDark: isDark,
                        isCreator: e.assignedBy == null ||
                            e.assignedBy == ref.read(authProvider)?.uid,
                        onDelete: () => _delete(context, ref, e),
                      )),
                ],
                if (past.isNotEmpty) ...[
                  _SectionHeader(
                      title: 'Pasados',
                      count: past.length,
                      isDark: isDark),
                  ...past.map((e) => _EventRow(
                        event: e,
                        isDark: isDark,
                        isCreator: e.assignedBy == null ||
                            e.assignedBy == ref.read(authProvider)?.uid,
                        onDelete: () => _delete(context, ref, e),
                      )),
                ],
                const SizedBox(height: 24),
              ];
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => items[i],
                  childCount: items.length,
                  addRepaintBoundaries: true,
                  addAutomaticKeepAlives: false,
                ),
              );
            },
            loading: () => SliverToBoxAdapter(child: LoadingList()),
            error: (e, _) => SliverToBoxAdapter(
              child: EmptyState(
                  emoji: '⚠️',
                  title: AppStrings.errorGeneric,
                  subtitle: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, EventModel event) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Eliminar evento',
      message: '¿Eliminar "${event.title}"?',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (ok) await ref.read(eventProvider.notifier).deleteEvent(event.id);
  }
}

// ─────────────────────────────────────────────────────────────
// UPCOMING HERO CARD — tarjeta destacada del próximo evento
// ─────────────────────────────────────────────────────────────
class _UpcomingHeroCard extends StatelessWidget {
  final EventModel event;
  final bool isDark;

  const _UpcomingHeroCard({required this.event, required this.isDark});

  Color get _color {
    if (event.isToday) return AppColors.statusRed;
    if (event.isSoon) return AppColors.statusAmber;
    return AppColors.accentBlue;
  }

  String get _countdown {
    if (event.isToday) return '¡Hoy!';
    if (event.daysLeft == 1) return 'Mañana';
    return 'En ${event.daysLeft} días';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return GestureDetector(
      onTap: () => context.push(
        AppRoutes.eventView,
        extra: {'event': event, 'isAdmin': true},
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        height: 148,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withValues(alpha: 0.65)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -12,
              child: Text(
                event.type.emoji,
                style: TextStyle(
                  fontSize: 100,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(event.type.emoji,
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          event.type.label,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _countdown,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black26)
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.white70),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              event.isAllDay
                                  ? EduDateUtils.fullDateLabel(event.date)
                                  : '${EduDateUtils.fullDateLabel(event.date)}  ·  ${EduDateUtils.timeLabel(event.date)}',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark ? Colors.white54 : AppColors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : AppColors.grey)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final EventModel event;
  final bool isDark;
  final bool isCreator;
  final VoidCallback onDelete;

  const _EventRow({
    required this.event,
    required this.isDark,
    required this.isCreator,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = event.isPast
        ? AppColors.grey
        : event.isSoon
            ? AppColors.statusAmber
            : AppColors.accentBlue;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showActionSheet(context),
          splashColor: color.withValues(alpha: 0.10),
          highlightColor: color.withValues(alpha: 0.06),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(event.type.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(
              event.title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    event.isAllDay
                        ? '${event.type.label} • ${EduDateUtils.shortDateLabel(event.date)}'
                        : '${event.type.label} • ${EduDateUtils.shortDateLabel(event.date)}  ${EduDateUtils.timeLabel(event.date)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.grey,
                    ),
                  ),
                ),
                if (event.assignedByRole != null) ...[
                  const SizedBox(width: 6),
                  AssignedByBadge(
                      assignedByRole: event.assignedByRole, compact: true),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!event.isPast)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      event.isToday
                          ? '¡Hoy!'
                          : event.daysLeft == 1
                              ? 'Mañana'
                              : 'En ${event.daysLeft}d',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                Icon(Icons.more_vert_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : AppColors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final color = event.isPast
        ? AppColors.grey
        : event.isSoon
            ? AppColors.statusAmber
            : AppColors.accentBlue;
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
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(event.type.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
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
                        event.type.label,
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
            _SheetTile(
              icon: Icons.visibility_outlined,
              label: 'Ver detalles',
              color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                context.push(AppRoutes.eventView, extra: {'event': event, 'isAdmin': true});
              },
            ),
            if (isCreator) ...[
              _SheetTile(
                icon: Icons.edit_rounded,
                label: 'Modificar',
                color: AppColors.statusAmber,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppRoutes.adminEditEventPath(event.id), extra: event);
                },
              ),
              _SheetTile(
                icon: Icons.delete_outline_rounded,
                label: 'Eliminar',
                color: AppColors.statusRed,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(context);
                  onDelete();
                },
              ),
            ] else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 16, color: isDark ? Colors.white54 : AppColors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Solo quien lo creó puede modificarlo o eliminarlo.',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: isDark ? Colors.white54 : AppColors.grey,
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
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : AppColors.navyBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
