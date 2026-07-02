import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/providers/stats_provider.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT STATS SCREEN — EduTrack Family
// Vista motivacional animada del progreso personal de Yordan.
// ═══════════════════════════════════════════════════════════════

class StudentStatsScreen extends ConsumerStatefulWidget {
  const StudentStatsScreen({super.key});

  @override
  ConsumerState<StudentStatsScreen> createState() => _StudentStatsScreenState();
}

class _StudentStatsScreenState extends ConsumerState<StudentStatsScreen>
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
    final end   = (start + 0.45).clamp(0.0, 1.0);
    final fade  = CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    ));
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats  = ref.watch(taskStatsProvider);

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
            backgroundColor: const Color(0xFF1A3C6E),
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 14),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mi Progreso',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '¡Sigue así, Yordan!',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0D2347), Color(0xFF1A5098)],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Text('🏆',
                      style: TextStyle(
                        fontSize: 60,
                        color: Colors.white.withValues(alpha: 0.12),
                      )),
                  ),
                  Positioned(
                    right: 72,
                    bottom: 20,
                    child: Text('⭐',
                      style: TextStyle(
                        fontSize: 30,
                        color: Colors.white.withValues(alpha: 0.08),
                      )),
                  ),
                ],
              ),
            ),
          ),

          if (stats == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Gran indicador de progreso ─────────────
                  _entry(0, _BigProgressCard(stats: stats, isDark: isDark)),
                  const SizedBox(height: 14),

                  // ── Racha + stats rápidos ──────────────────
                  _entry(1, _QuickStatsRow(stats: stats, isDark: isDark)),
                  const SizedBox(height: 14),

                  // ── Actividad últimos 7 días ───────────────
                  _entry(2, _WeekActivityCard(stats: stats, isDark: isDark)),
                  const SizedBox(height: 14),

                  // ── Por materia ────────────────────────────
                  if (stats.bySubject.isNotEmpty) ...[
                    _entry(3, _SubjectProgressCard(stats: stats, isDark: isDark)),
                    const SizedBox(height: 14),
                  ],

                  // ── Logros desbloqueados ───────────────────
                  _entry(4, _AchievementsCard(stats: stats, isDark: isDark)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GRAN INDICADOR DE PROGRESO — anillo animado
// ─────────────────────────────────────────────────────────────
class _BigProgressCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _BigProgressCard({required this.stats, required this.isDark});

  String get _message {
    final pct = stats.completionRate;
    if (stats.total == 0) return '¡Aún no hay tareas asignadas!';
    if (pct >= 1.0)  return '¡Increíble! ¡Todo completado! 🎉';
    if (pct >= 0.80) return '¡Casi perfecto! Sigue así 💪';
    if (pct >= 0.60) return '¡Buen ritmo! No pares ahora 🚀';
    if (pct >= 0.40) return 'Vas por buen camino, ¡tú puedes! ⚡';
    if (pct >= 0.20) return 'Cada tarea cuenta, ¡adelante! 📚';
    return '¡Empieza hoy y llega lejos! 🌟';
  }

  Color get _ringColor {
    final pct = stats.completionRate;
    if (pct >= 0.80) return AppColors.statusGreen;
    if (pct >= 0.50) return AppColors.statusAmber;
    return AppColors.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Anillo animado de 0 → completionRate
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: stats.completionRate),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOutCubic,
            builder: (_, value, _) {
              final pct = (value * 100).round();
              return SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: value,
                          color: _ringColor,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$pct%',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                        Text(
                          'completado',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
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
          const SizedBox(height: 16),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _ringColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${stats.completed} de ${stats.total} tareas completadas',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// CustomPainter para el anillo de progreso
class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect, 0, math.pi * 2, false,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress <= 0) return;

    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// STATS RÁPIDOS: racha + pendientes + en revisión (contador animado)
// ─────────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _QuickStatsRow({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickCard(
          emoji: '🔥',
          value: stats.streak,
          label: stats.streak == 1 ? 'día seguido' : 'días seguidos',
          color: const Color(0xFFFF6B35),
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _QuickCard(
          emoji: '⏳',
          value: stats.pending,
          label: 'pendientes',
          color: AppColors.statusAmber,
          isDark: isDark,
        ),
        const SizedBox(width: 10),
        _QuickCard(
          emoji: '👁️',
          value: stats.inReview,
          label: 'en revisión',
          color: const Color(0xFF7C4DFF),
          isDark: isDark,
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String emoji;
  final int value;
  final String label;
  final Color color;
  final bool isDark;
  const _QuickCard({
    required this.emoji, required this.value,
    required this.label, required this.color, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _Card(
        isDark: isDark,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 6),
            // Número que cuenta de 0 al valor real
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: value.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, _) => Text(
                '${v.round()}',
                style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 10,
                color: isDark ? Colors.white38 : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ACTIVIDAD ÚLTIMOS 7 DÍAS — barras animadas desde 0
// ─────────────────────────────────────────────────────────────
class _WeekActivityCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _WeekActivityCard({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final maxVal = stats.max7Days;
    final totalThisWeek = stats.last7Days.fold(0, (s, d) => s + d.count);
    final today = DateTime(
      DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Actividad semanal',
                      style: TextStyle(
                        fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      )),
                    Text('Últimos 7 días',
                      style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.grey,
                      )),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.statusGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalThisWeek completadas',
                  style: const TextStyle(
                    fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.statusGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(stats.last7Days.length, (i) {
                final d = stats.last7Days[i];
                final isToday = d.date == today;
                final ratio = maxVal == 0 ? 0.0 : d.count / maxVal;
                final targetH = (ratio * 64).clamp(4.0, 64.0);
                final barColor = d.count > 0
                    ? (isToday ? AppColors.statusGreen : AppColors.accentBlue)
                    : (isDark ? Colors.white10 : AppColors.offWhite);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d.count > 0)
                          Text('${d.count}',
                            style: TextStyle(
                              fontFamily: 'Poppins', fontSize: 9,
                              fontWeight: FontWeight.w700, color: barColor,
                            )),
                        const SizedBox(height: 2),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: targetH),
                          duration: Duration(milliseconds: 600 + i * 60),
                          curve: Curves.easeOutCubic,
                          builder: (_, h, _) => Container(
                            height: h,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppStrings.weekDaysShort[d.date.weekday - 1],
                          style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 9,
                            fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                            color: isToday
                                ? AppColors.statusGreen
                                : (isDark ? Colors.white38 : AppColors.grey),
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
// PROGRESO POR MATERIA — barras animadas
// ─────────────────────────────────────────────────────────────
class _SubjectProgressCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _SubjectProgressCard({required this.stats, required this.isDark});

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
          Text('Mis materias',
            style: TextStyle(
              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.navyBlue,
            )),
          const SizedBox(height: 16),
          ...stats.bySubject.take(6).toList().asMap().entries.map((e) {
            final s   = e.value;
            final col = _colors[e.key % _colors.length];
            final emoji = s.rate >= 1.0 ? '✅' : s.rate >= 0.5 ? '📖' : '📝';
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.subject,
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          )),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: s.rate),
                        duration: Duration(milliseconds: 700 + e.key * 80),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, _) => Text(
                          '${(v * 100).round()}%',
                          style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 13,
                            fontWeight: FontWeight.w700, color: col,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Barra animada de 0 → rate
                  LayoutBuilder(
                    builder: (_, constraints) {
                      return Stack(
                        children: [
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: col.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: s.rate.clamp(0.0, 1.0)),
                            duration: Duration(milliseconds: 800 + e.key * 80),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, _) => Container(
                              height: 8,
                              width: constraints.maxWidth * v,
                              decoration: BoxDecoration(
                                color: col,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${s.completed} completadas · ${s.pending} pendientes',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 10,
                      color: isDark ? Colors.white30 : AppColors.grey,
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
// LOGROS DESBLOQUEADOS — pulse en los desbloqueados
// ─────────────────────────────────────────────────────────────
class _AchievementsCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const _AchievementsCard({required this.stats, required this.isDark});

  List<_Achievement> get _all => [
    _Achievement(
      emoji: '🥉', title: 'Primera tarea',
      desc: 'Completaste tu primera tarea',
      unlocked: stats.completed >= 1,
    ),
    _Achievement(
      emoji: '🥈', title: '5 completadas',
      desc: 'Completaste 5 tareas',
      unlocked: stats.completed >= 5,
    ),
    _Achievement(
      emoji: '🥇', title: '10 completadas',
      desc: 'Completaste 10 tareas',
      unlocked: stats.completed >= 10,
    ),
    _Achievement(
      emoji: '🏆', title: '25 completadas',
      desc: 'Leyenda del aula',
      unlocked: stats.completed >= 25,
    ),
    _Achievement(
      emoji: '🔥', title: 'Racha de 3',
      desc: '3 días seguidos con tareas',
      unlocked: stats.streak >= 3,
    ),
    _Achievement(
      emoji: '⚡', title: 'Semana completa',
      desc: '7 días seguidos con tareas',
      unlocked: stats.streak >= 7,
    ),
    _Achievement(
      emoji: '⭐', title: '80% aprobado',
      desc: 'Tasa de completado ≥ 80%',
      unlocked: stats.completionRate >= 0.80,
    ),
    _Achievement(
      emoji: '💎', title: 'Perfecto',
      desc: '100% de tareas completadas',
      unlocked: stats.completionRate >= 1.0 && stats.total > 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final achievements = _all;
    final unlocked = achievements.where((a) => a.unlocked).length;

    return _Card(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Logros',
                  style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  )),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unlocked/${achievements.length}',
                  style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: achievements.asMap().entries.map((e) =>
              _AchievementChip(
                achievement: e.value,
                isDark: isDark,
                index: e.key,
              ),
            ).toList(),
          ),
        ],
      ),
    );
  }
}

class _Achievement {
  final String emoji;
  final String title;
  final String desc;
  final bool unlocked;
  const _Achievement({
    required this.emoji, required this.title,
    required this.desc, required this.unlocked,
  });
}

class _AchievementChip extends StatefulWidget {
  final _Achievement achievement;
  final bool isDark;
  final int index;
  const _AchievementChip({
    required this.achievement, required this.isDark, required this.index,
  });

  @override
  State<_AchievementChip> createState() => _AchievementChipState();
}

class _AchievementChipState extends State<_AchievementChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    if (widget.achievement.unlocked) {
      // Pulso de entrada escalonado para los logros desbloqueados
      Future.delayed(Duration(milliseconds: 800 + widget.index * 80), () {
        if (mounted) _pulse.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = !widget.achievement.unlocked;
    return Tooltip(
      message: widget.achievement.desc,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: widget.achievement.unlocked ? _scale.value : 1.0,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: locked
                ? (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.offWhite)
                : AppColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: locked
                  ? (isDark ? Colors.white10 : AppColors.lightGrey)
                  : AppColors.accentBlue.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(locked ? '🔒' : widget.achievement.emoji,
                style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                widget.achievement.title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? (isDark ? Colors.white24 : Colors.black45)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get isDark => widget.isDark;
}

// ─────────────────────────────────────────────────────────────
// COMPONENTES INTERNOS
// ─────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets? padding;
  const _Card({required this.child, required this.isDark, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 8, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
