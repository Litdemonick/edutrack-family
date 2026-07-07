import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT EVENT LIST — EduTrack Family
// Vista de eventos escolares para el estudiante. Solo lectura.
// ═══════════════════════════════════════════════════════════════

class StudentEventList extends ConsumerWidget {
  const StudentEventList({super.key});

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
                      subtitle:
                          'Cuando tu padre/tutor o profesor agregue un evento escolar, aparecerá aquí.',
                    ),
                  ),
                );
              }

              final upcoming = events.where((e) => !e.isPast).toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              final past = events.where((e) => e.isPast).toList()
                ..sort((a, b) => b.date.compareTo(a.date));

              final items = <Widget>[];

              if (upcoming.isNotEmpty) {
                items.add(_SectionHeader(
                  title: 'Próximos',
                  count: upcoming.length,
                  isDark: isDark,
                  color: AppColors.accentBlue,
                ));
                // Hero card for the next imminent event
                items.add(_HeroEventCard(event: upcoming.first, isDark: isDark));
                // Remaining upcoming as compact cards
                for (int i = 1; i < upcoming.length; i++) {
                  items.add(_EventCard(event: upcoming[i], isDark: isDark));
                }
              }

              if (past.isNotEmpty) {
                items.add(const SizedBox(height: 4));
                items.add(_SectionHeader(
                  title: 'Pasados',
                  count: past.length,
                  isDark: isDark,
                  color: AppColors.grey,
                ));
                for (final e in past) {
                  items.add(_EventCard(event: e, isDark: isDark, isPast: true));
                }
              }

              items.add(const SizedBox(height: 24));

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => items[i],
                  childCount: items.length,
                ),
              );
            },
            loading: () => SliverToBoxAdapter(child: LoadingList()),
            error: (e, _) => SliverToBoxAdapter(
              child: EmptyState(
                emoji: '⚠️',
                title: AppStrings.errorGeneric,
                subtitle: e.toString(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO CARD — próximo evento más inmediato, destacado
// ─────────────────────────────────────────────────────────────
class _HeroEventCard extends StatelessWidget {
  final EventModel event;
  final bool isDark;

  const _HeroEventCard({required this.event, required this.isDark});

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
        extra: {'event': event, 'isAdmin': false},
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        height: 168,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color,
              color.withValues(alpha: 0.68),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Emoji watermark
            Positioned(
              right: -8,
              bottom: -12,
              child: Text(
                event.type.emoji,
                style: TextStyle(
                  fontSize: 108,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top row: emoji + type + countdown
                  Row(
                    children: [
                      Text(event.type.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
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
                            horizontal: 12, vertical: 5),
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

                  // Bottom: title + date
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          shadows: [
                            Shadow(blurRadius: 6, color: Colors.black26)
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: Colors.white70),
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
            // Tap ripple overlay
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  splashColor: Colors.white.withValues(alpha: 0.12),
                  onTap: () => context.push(
                    AppRoutes.eventView,
                    extra: {'event': event, 'isAdmin': false},
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EVENT CARD — tarjeta compacta con countdown chip
// ─────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final EventModel event;
  final bool isDark;
  final bool isPast;

  const _EventCard({
    required this.event,
    required this.isDark,
    this.isPast = false,
  });

  Color get _color {
    if (isPast) return AppColors.grey;
    if (event.isToday) return AppColors.statusRed;
    if (event.isSoon) return AppColors.statusAmber;
    return AppColors.accentBlue;
  }

  String get _chip {
    if (isPast) {
      final days = DateTime.now().difference(event.date).inDays;
      if (days <= 0) return 'Hoy';
      if (days == 1) return 'Ayer';
      return 'Hace $days d';
    }
    if (event.isToday) return '¡Hoy!';
    if (event.daysLeft == 1) return 'Mañana';
    return 'En ${event.daysLeft} d';
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
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
          splashColor: color.withValues(alpha: 0.10),
          onTap: () => context.push(
            AppRoutes.eventView,
            extra: {'event': event, 'isAdmin': false},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Emoji icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isPast ? 0.07 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Opacity(
                      opacity: isPast ? 0.55 : 1.0,
                      child: Text(event.type.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isPast
                              ? (isDark ? Colors.white38 : AppColors.grey)
                              : (isDark ? Colors.white : AppColors.navyBlue),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.isAllDay
                            ? '${event.type.label} · ${EduDateUtils.shortDateLabel(event.date)}'
                            : '${event.type.label} · ${EduDateUtils.shortDateLabel(event.date)}  ${EduDateUtils.timeLabel(event.date)}',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                // Countdown chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _chip,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),

                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: isDark ? Colors.white24 : AppColors.lightGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECTION HEADER con contador de badge
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
              color: isDark ? Colors.white54 : AppColors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
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
