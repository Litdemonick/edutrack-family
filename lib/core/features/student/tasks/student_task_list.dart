import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/task_priority_card.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT TASK LIST — EduTrack Family
// Tab dedicada de tareas para Yordan: filtros + secciones.
// ═══════════════════════════════════════════════════════════════

class StudentTaskList extends ConsumerStatefulWidget {
  const StudentTaskList({super.key});

  @override
  ConsumerState<StudentTaskList> createState() => _StudentTaskListState();
}

class _StudentTaskListState extends ConsumerState<StudentTaskList> {
  String _filter = 'all'; // all | urgent | pending | completed

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskProvider);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          pinned: true,
          backgroundColor: AppColors.navyBlue,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text(
            'Mis Tareas',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          centerTitle: false,
        ),

        // Filtros 2×2
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _FilterChip(label: 'Todas', value: 'all', current: _filter,
                        onTap: (v) => setState(() => _filter = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Urgentes', value: 'urgent', current: _filter,
                        onTap: (v) => setState(() => _filter = v))),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(child: _FilterChip(label: 'Pendientes', value: 'pending', current: _filter,
                        onTap: (v) => setState(() => _filter = v))),
                    const SizedBox(width: 8),
                    Expanded(child: _FilterChip(label: 'Completadas', value: 'completed', current: _filter,
                        onTap: (v) => setState(() => _filter = v))),
                  ],
                ),
              ],
            ),
          ),
        ),

        tasksAsync.when(
          data: (tasks) {
            final filtered = _applyFilter(tasks);
            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 64),
                  child: EmptyState(
                    emoji: _filter == 'all' ? '🎉' : '🔍',
                    title: _filter == 'all' ? '¡Todo al día!' : 'Sin resultados',
                    subtitle: _filter == 'all'
                        ? 'No tienes tareas pendientes.\n¡Sigue así, Yordan!'
                        : 'No hay tareas en esta categoría.',
                  ),
                ),
              );
            }

            if (_filter != 'all') {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TaskPriorityCard(task: filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            }

            List<T> byDate<T>(Iterable<T> src, DateTime Function(T) d) =>
                src.toList()..sort((a, b) => d(a).compareTo(d(b)));

            final urgent = byDate(tasks.where((t) => t.isUrgent), (t) => t.dueDate);
            final dueToday = byDate(tasks.where((t) => t.isDueToday), (t) => t.dueDate);
            final review = tasks.where((t) => t.isInReview).toList()
              ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));
            final pending = byDate(
              tasks.where((t) => t.isPending && !t.isUrgent && !t.isDueToday),
              (t) => t.dueDate,
            );
            final done = tasks.where((t) => t.isCompleted).toList()
              ..sort((a, b) => (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt));

            final items = <Widget>[
              if (urgent.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.warning_amber_rounded,
                  title: 'Urgentes (${urgent.length})',
                  color: AppColors.statusRed,
                  isDark: isDark,
                ),
                ...urgent.map((t) => TaskPriorityCard(task: t)),
              ],
              if (dueToday.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.today_outlined,
                  title: 'Vencen hoy (${dueToday.length})',
                  color: AppColors.statusAmber,
                  isDark: isDark,
                ),
                ...dueToday.map((t) => TaskPriorityCard(task: t)),
              ],
              if (review.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.hourglass_top_rounded,
                  title: 'En revisión (${review.length})',
                  color: const Color(0xFF7C4DFF),
                  isDark: isDark,
                ),
                ...review.map((t) => TaskPriorityCard(task: t)),
              ],
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.assignment_outlined,
                  title: 'Pendientes (${pending.length})',
                  color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
                  isDark: isDark,
                ),
                ...pending.map((t) => TaskPriorityCard(task: t)),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'Completadas (${done.length})',
                  color: AppColors.statusGreen,
                  isDark: isDark,
                ),
                ...done.map((t) => TaskPriorityCard(task: t)),
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
              title: 'Error al cargar',
              subtitle: e.toString(),
            ),
          ),
        ),
      ],
    );
  }

  List<TaskModel> _applyFilter(List<TaskModel> tasks) {
    switch (_filter) {
      case 'urgent':
        return tasks.where((t) => t.isUrgent && !t.isCompleted).toList();
      case 'pending':
        return tasks.where((t) => t.isPending).toList();
      case 'completed':
        return tasks.where((t) => t.isCompleted).toList();
      default:
        return tasks;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// FILTER CHIP — misma UI que el admin
// ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = value == current;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.accentBlue.withValues(alpha: 0.15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentBlue
                : (isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentBlue
                  : (isDark ? Colors.white24 : AppColors.lightGrey),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : AppColors.grey),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final bool isDark;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
