import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/stats_provider.dart';

// ═══════════════════════════════════════════════════════════════
// ACHIEVEMENTS CARD — EduTrack Family
// Tarjeta de "Logros" compartida entre la vista del propio
// estudiante (Mi Progreso) y la del padre/tutor/profesor (Ver
// logros, dentro de Estadísticas) — misma fuente de verdad
// (TaskStats), para que ambos vean exactamente lo mismo.
// ═══════════════════════════════════════════════════════════════

class Achievement {
  final String emoji;
  final String title;
  final String desc;
  final int current;
  final int target;

  /// Texto ya formateado del progreso (ej. "7/10 completadas",
  /// "65%/80% aprobado") — cada logro arma el suyo porque las
  /// unidades no son todas iguales (tareas, días, porcentaje).
  final String progressLabel;

  const Achievement({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.current,
    required this.target,
    required this.progressLabel,
  });

  bool get unlocked => current >= target;
  double get progress =>
      target == 0 ? 1.0 : (current / target).clamp(0.0, 1.0);
}

List<Achievement> buildAchievements(TaskStats stats) {
  final pct = (stats.completionRate * 100).round();
  return [
    Achievement(
      emoji: '🥉',
      title: 'Primera tarea',
      desc: 'Completaste tu primera tarea',
      current: stats.completed,
      target: 1,
      progressLabel: '${stats.completed}/1 completada',
    ),
    Achievement(
      emoji: '🥈',
      title: '5 completadas',
      desc: 'Completaste 5 tareas',
      current: stats.completed,
      target: 5,
      progressLabel: '${stats.completed}/5 completadas',
    ),
    Achievement(
      emoji: '🥇',
      title: '10 completadas',
      desc: 'Completaste 10 tareas',
      current: stats.completed,
      target: 10,
      progressLabel: '${stats.completed}/10 completadas',
    ),
    Achievement(
      emoji: '🏆',
      title: '25 completadas',
      desc: 'Leyenda del aula',
      current: stats.completed,
      target: 25,
      progressLabel: '${stats.completed}/25 completadas',
    ),
    Achievement(
      emoji: '🔥',
      title: 'Racha de 3',
      desc: '3 días seguidos con tareas',
      current: stats.streak,
      target: 3,
      progressLabel: '${stats.streak}/3 días seguidos',
    ),
    Achievement(
      emoji: '⚡',
      title: 'Semana completa',
      desc: '7 días seguidos con tareas',
      current: stats.streak,
      target: 7,
      progressLabel: '${stats.streak}/7 días seguidos',
    ),
    Achievement(
      emoji: '⭐',
      title: '80% aprobado',
      desc: 'Tasa de completado ≥ 80%',
      current: pct,
      target: 80,
      progressLabel: '$pct%/80%',
    ),
    Achievement(
      emoji: '💎',
      title: 'Perfecto',
      desc: '100% de tareas completadas',
      current: stats.total > 0 ? pct : 0,
      target: 100,
      progressLabel: stats.total > 0 ? '$pct%/100%' : '0/100%',
    ),
  ];
}

class AchievementsCard extends StatelessWidget {
  final TaskStats stats;
  final bool isDark;
  const AchievementsCard({super.key, required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final achievements = buildAchievements(stats);
    final unlocked = achievements.where((a) => a.unlocked).length;
    final nextLocked = achievements.where((a) => !a.unlocked).firstOrNull;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Logros',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
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
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
            children: achievements
                .asMap()
                .entries
                .map((e) => _AchievementChip(
                      achievement: e.value,
                      isDark: isDark,
                      index: e.key,
                    ))
                .toList(),
          ),
          if (nextLocked != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(nextLocked.emoji,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Próximo: ${nextLocked.title}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                        ),
                      ),
                      Text(
                        nextLocked.progressLabel,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: nextLocked.progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accentBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AchievementChip extends StatefulWidget {
  final Achievement achievement;
  final bool isDark;
  final int index;
  const _AchievementChip({
    required this.achievement,
    required this.isDark,
    required this.index,
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
      message: locked
          ? '${widget.achievement.desc} · ${widget.achievement.progressLabel}'
          : widget.achievement.desc,
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
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : AppColors.offWhite)
                : AppColors.accentBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: locked
                  ? (widget.isDark ? Colors.white10 : AppColors.lightGrey)
                  : AppColors.accentBlue.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                locked ? '🔒' : widget.achievement.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(width: 6),
              Text(
                widget.achievement.title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? (widget.isDark ? Colors.white24 : Colors.black45)
                      : (widget.isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
