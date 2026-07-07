import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/providers/stats_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/achievements_card.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';

// ═══════════════════════════════════════════════════════════════
// ADMIN STATS SCREEN — EduTrack Family
// Panel analítico animado del rendimiento del estudiante activo.
// ═══════════════════════════════════════════════════════════════

class AdminStatsScreen extends ConsumerStatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  ConsumerState<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends ConsumerState<AdminStatsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Envuelve cada sección con fade + slide escalonados
  Widget _entry(int index, Widget child) {
    final start = (index * 0.10).clamp(0.0, 0.6);
    final end = (start + 0.45).clamp(0.0, 1.0);
    final fade = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      ),
    );
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = ref.watch(taskStatsProvider);
    final role = ref.watch(authProvider)?.role ?? UserRole.parent;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            automaticallyImplyLeading: false,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            backgroundColor: AppColors.navyBlue,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
              // FittedBox: el slot del título de FlexibleSpaceBar es
              // muy ajustado (fijo a la altura colapsada del AppBar,
              // sin importar expandedHeight) — dos líneas de texto ahí
              // desbordaban por unos pocos px en Windows y en celular
              // con escala de fuente del sistema >1.0. Con esto el
              // texto se encoge lo justo para entrar siempre, sin
              // overflow en ningún lado.
              title: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estadísticas',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Rendimiento de ${ref.watch(activeStudentProvider)?.name ?? RoleCopy.dashboardFallbackName(role)}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0A1E3D), Color(0xFF1A3C6E)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 14,
                    child: Text(
                      '📊',
                      style: TextStyle(
                        fontSize: 56,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 80,
                    bottom: 18,
                    child: Text(
                      '📈',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────
          // Sin hijo vinculado no hay nada que calcular — mostrar un
          // mensaje claro en vez de un spinner que nunca se resuelve.
          if (ref.watch(activeStudentProvider) == null)
            SliverFillRemaining(
              child: EmptyState(
                emoji: role == UserRole.teacher ? '🏫' : '👨‍👩‍👧',
                title: RoleCopy.noStudentsTitle(role),
                subtitle: RoleCopy.noStudentsSubtitle(role),
                actionLabel: RoleCopy.noStudentsActionLabel(role),
                onAction: () => context.push(AppRoutes.family),
              ),
            )
          else if (stats == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Resumen de 4 tarjetas ──────────────────
                  _entry(0, _SummaryRow(stats: stats, isDark: isDark)),
                  const SizedBox(height: 16),

                  // ── Tasa de completado ─────────────────────
                  _entry(1, _CompletionRateCard(stats: stats, isDark: isDark)),
                  const SizedBox(height: 16),

                  // ── Tendencia semanal ──────────────────────
                  _entry(2, _WeekTrendCard(stats: stats, isDark: isDark)),
                  const SizedBox(height: 16),

                  // ── Actividad: últimos 7 días ──────────────
                  _entry(
                    3,
                    _BarChartCard(
                      title: 'Actividad — últimos 7 días',
                      subtitle: 'Tareas completadas por día',
                      data: stats.last7Days,
                      max: stats.max7Days,
                      labelBuilder:
                          (d) => AppStrings.weekDaysShort[d.date.weekday - 1],
                      isDark: isDark,
                      color: AppColors.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Actividad: últimas 4 semanas ───────────
                  _entry(
                    4,
                    _BarChartCard(
                      title: 'Tendencia mensual',
                      subtitle: 'Completadas por semana',
                      data: stats.last4Weeks,
                      max: stats.max4Weeks,
                      labelBuilder:
                          (d) => 'S${stats.last4Weeks.indexOf(d) + 1}',
                      isDark: isDark,
                      color: const Color(0xFF7C4DFF),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Por materia ────────────────────────────
                  if (stats.bySubject.isNotEmpty) ...[
                    _entry(5, _SubjectCard(stats: stats, isDark: isDark)),
                    const SizedBox(height: 16),
                  ],

                  // ── Logros del estudiante ──────────────────
                  _entry(6, AchievementsCard(stats: stats, isDark: isDark)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESUMEN — 4 tarjetas en grid 2×2, contador animado
// ─────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _SummaryRow({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Siempre son exactamente 4 tarjetas — crossAxisCount fijo en vez
    // de maxCrossAxisExtent para que llenen todo el ancho disponible
    // en vez de dejar columnas vacías en ventanas anchas.
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: context.isCompact ? 2 : 4,
        // Antes 76 — el número + la etiqueta no entraban en esa
        // altura fija (overflow de 8px en Windows y también posible
        // en celular con texto más grande/escala de fuente del
        // sistema); con más margen entra cómodo en cualquier lado.
        mainAxisExtent: 92,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      children: [
        _MetricCard(
          label: 'Total',
          value: stats.total,
          icon: Icons.assignment_rounded,
          color: AppColors.accentBlue,
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Completadas',
          value: stats.completed,
          icon: Icons.check_circle_rounded,
          color: AppColors.statusGreen,
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Pendientes',
          value: stats.pending,
          icon: Icons.hourglass_empty_rounded,
          color: AppColors.statusAmber,
          isDark: isDark,
        ),
        _MetricCard(
          label: 'Vencidas',
          value: stats.overdue,
          icon: Icons.warning_rounded,
          color: AppColors.statusRed,
          isDark: isDark,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isDark;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final fluent = context.isMedium || context.isExpanded;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(fluent ? 8 : 16),
        border:
            fluent
                ? Border.all(color: isDark ? Colors.white12 : Colors.black12)
                : null,
        boxShadow:
            fluent
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: value.toDouble()),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOut,
                  builder:
                      (_, v, _) => Text(
                        '${v.round()}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.navyBlue,
                        ),
                      ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TASA DE COMPLETADO + A TIEMPO VS TARDE — círculo animado
// ─────────────────────────────────────────────────────────────
class _CompletionRateCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _CompletionRateCard({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = stats.completedOnTime + stats.completedLate;

    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Tasa de completado', isDark: isDark),
          const SizedBox(height: 20),
          Row(
            children: [
              // Círculo de progreso animado
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: stats.completionRate),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, value, _) {
                  final pct = (value * 100).round();
                  return SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 96,
                          height: 96,
                          child: CircularProgressIndicator(
                            value: value,
                            strokeWidth: 8,
                            backgroundColor: (isDark
                                    ? Colors.white
                                    : AppColors.lightGrey)
                                .withValues(alpha: 0.20),
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.statusGreen,
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$pct%',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color:
                                    isDark ? Colors.white : AppColors.navyBlue,
                              ),
                            ),
                            Text(
                              'completado',
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 9,
                                color: isDark ? Colors.white38 : AppColors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LegendRow(
                      color: AppColors.statusGreen,
                      label: 'A tiempo',
                      value: stats.completedOnTime,
                      pct: total == 0 ? 0 : stats.completedOnTime / total,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _LegendRow(
                      color: AppColors.statusRed,
                      label: 'Tarde',
                      value: stats.completedLate,
                      pct: total == 0 ? 0 : stats.completedLate / total,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _LegendRow(
                      color: const Color(0xFF7C4DFF),
                      label: 'En revisión',
                      value: stats.inReview,
                      pct: stats.total == 0 ? 0 : stats.inReview / stats.total,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final double pct;
  final bool isDark;
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.pct,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: isDark ? Colors.white54 : AppColors.grey,
                ),
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.navyBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: pct),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder:
              (_, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: v,
                  minHeight: 4,
                  backgroundColor: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA TENDENCIA SEMANAL — contadores animados
// ─────────────────────────────────────────────────────────────
class _WeekTrendCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _WeekTrendCard({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final trend = stats.weekTrend;
    final up = stats.isImprovingWeek;
    final trendColor = up ? AppColors.statusGreen : AppColors.statusRed;
    final trendLabel =
        trend == 0
            ? 'igual que la semana pasada'
            : up
            ? '+${(trend * 100).round()}% respecto a la semana pasada'
            : '${(trend * 100).round()}% respecto a la semana pasada';

    return _Card(
      isDark: isDark,
      child: Row(
        children: [
          Expanded(
            child: _TrendStat(
              label: 'Esta semana',
              value: stats.thisWeekCompleted,
              sub: 'tareas completadas',
              isDark: isDark,
              color: AppColors.accentBlue,
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.08,
            ),
          ),
          Expanded(
            child: _TrendStat(
              label: 'Semana pasada',
              value: stats.lastWeekCompleted,
              sub: 'tareas completadas',
              isDark: isDark,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
          ),
          Container(
            width: 1,
            height: 60,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.08,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Icon(
                  up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: trendColor,
                  size: 28,
                ),
                const SizedBox(height: 4),
                Text(
                  trendLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 10,
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendStat extends StatelessWidget {
  final String label;
  final int value;
  final String sub;
  final bool isDark;
  final Color color;
  const _TrendStat({
    required this.label,
    required this.value,
    required this.sub,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 11,
            color: isDark ? Colors.white38 : AppColors.grey,
          ),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: value.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder:
              (_, v, _) => Text(
                '${v.round()}',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
        ),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            color: isDark ? Colors.white24 : AppColors.lightGrey,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GRÁFICA DE BARRAS (reutilizable) — barras animadas desde 0
// ─────────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<DayStat> data;
  final int max;
  final String Function(DayStat) labelBuilder;
  final bool isDark;
  final Color color;

  const _BarChartCard({
    required this.title,
    required this.subtitle,
    required this.data,
    required this.max,
    required this.labelBuilder,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title, isDark: isDark),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            // 72 (barra máx.) + 2 + 6 (spacers) + hasta 2 textos de
            // ~13px (el número arriba de la barra + el label) — 100
            // se quedaba corto en Windows/Linux cuando el día/semana
            // tenía tareas completadas (con el número visible).
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (i) {
                final d = data[i];
                final ratio = max == 0 ? 0.0 : d.count / max;
                final targetH = (ratio * 72).clamp(4.0, 72.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.count > 0)
                          Text(
                            '${d.count}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        const SizedBox(height: 2),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: targetH),
                          duration: Duration(milliseconds: 600 + i * 70),
                          curve: Curves.easeOutCubic,
                          builder:
                              (_, h, _) => Container(
                                height: h,
                                decoration: BoxDecoration(
                                  color:
                                      d.count > 0
                                          ? color
                                          : (isDark
                                              ? Colors.white10
                                              : AppColors.offWhite),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labelBuilder(d),
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white38 : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// POR MATERIA — barras animadas
// ─────────────────────────────────────────────────────────────
class _SubjectCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _SubjectCard({required this.stats, required this.isDark});

  static const _colors = [
    AppColors.accentBlue,
    Color(0xFF4CAF50),
    Color(0xFFFF6B35),
    Color(0xFF9C27B0),
    Color(0xFF00BCD4),
    Color(0xFFFF4081),
  ];

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('Rendimiento por materia', isDark: isDark),
          const SizedBox(height: 16),
          ...stats.bySubject.take(6).toList().asMap().entries.map((e) {
            final idx = e.key;
            final s = e.value;
            final col = _colors[idx % _colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.subject,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                      ),
                      Text(
                        '${s.completed}/${s.total}',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: s.rate),
                        duration: Duration(milliseconds: 700 + idx * 80),
                        curve: Curves.easeOutCubic,
                        builder:
                            (_, v, _) => Text(
                              '${(v * 100).round()}%',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: col,
                              ),
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: s.rate),
                    duration: Duration(milliseconds: 800 + idx * 80),
                    curve: Curves.easeOutCubic,
                    builder:
                        (_, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: v,
                            minHeight: 6,
                            backgroundColor: col.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation(col),
                          ),
                        ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPONENTES INTERNOS
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Ventana ancha (Windows/Linux en la práctica) → borde fino en
    // vez de sombra, estilo Fluent; teléfono se queda con el look
    // Material de siempre.
    final fluent = context.isMedium || context.isExpanded;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(fluent ? 8 : 16),
        border:
            fluent
                ? Border.all(color: isDark ? Colors.white12 : Colors.black12)
                : null,
        boxShadow:
            fluent
                ? null
                : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
      ),
      child: child,
    );
  }
}

class _CardTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _CardTitle(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : AppColors.navyBlue,
      ),
    );
  }
}
