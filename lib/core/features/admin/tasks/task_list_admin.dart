import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/shared/widgets/assigned_by_badge.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';

// ═══════════════════════════════════════════════════════════════
// TASK LIST ADMIN — EduTrack Family
// Lista completa de tareas del estudiante activo para gestión del admin.
// ═══════════════════════════════════════════════════════════════

class TaskListAdmin extends ConsumerStatefulWidget {
  const TaskListAdmin({super.key});

  @override
  ConsumerState<TaskListAdmin> createState() => _TaskListAdminState();
}

class _TaskListAdminState extends ConsumerState<TaskListAdmin> {
  String _filter = 'all'; // all | pending | completed | urgent

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tasksAsync = ref.watch(taskProvider);
    final studentName = ref.watch(activeStudentProvider)?.name;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            automaticallyImplyLeading: false,
            pinned: true,
            title: Text(
              studentName != null ? 'Tareas de $studentName' : 'Tareas',
              style: const TextStyle(
                  fontFamily: 'Poppins', fontWeight: FontWeight.w600),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => context.push(AppRoutes.adminCreateTask),
              ),
            ],
          ),

          tasksAsync.when(
            data: (tasks) {
              final totalCount = tasks.length;
              final urgentList = tasks.where((t) => t.isUrgent && !t.isCompleted).toList();
              final dueTodayList = tasks.where((t) => t.isDueToday && !t.isCompleted).toList();
              final pendingList = tasks.where((t) => t.isPending && !t.isUrgent && !t.isDueToday).toList();
              final completedList = tasks.where((t) => t.isCompleted).toList();

              // Secciones visibles según filtro
              final sections = <_TaskSection>[];
              if (_filter == 'all' || _filter == 'urgent') {
                sections.add(_TaskSection(label: 'Urgentes', count: urgentList.length,
                    color: AppColors.statusRed, icon: Icons.warning_amber_rounded, tasks: urgentList));
              }
              if (_filter == 'all' || _filter == 'urgent' || _filter == 'pending') {
                sections.add(_TaskSection(label: 'Vencen hoy', count: dueTodayList.length,
                    color: AppColors.statusAmber, icon: Icons.today_outlined, tasks: dueTodayList));
              }
              if (_filter == 'all' || _filter == 'pending') {
                sections.add(_TaskSection(label: 'Pendientes', count: pendingList.length,
                    color: AppColors.accentBlue, icon: Icons.hourglass_empty_rounded, tasks: pendingList));
              }
              if (_filter == 'all' || _filter == 'completed') {
                sections.add(_TaskSection(label: 'Completadas', count: completedList.length,
                    color: AppColors.statusGreen, icon: Icons.check_circle_outline_rounded, tasks: completedList));
              }

              final hasAnyTask = sections.any((s) => s.tasks.isNotEmpty);

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      // Filtros con conteos
                      Row(
                        children: [
                          Expanded(child: _FilterChip(label: 'Todas ($totalCount)', value: 'all', current: _filter,
                              onTap: (v) => setState(() => _filter = v))),
                          const SizedBox(width: 8),
                          Expanded(child: _FilterChip(label: 'Urgentes (${urgentList.length})', value: 'urgent', current: _filter,
                              onTap: (v) => setState(() => _filter = v))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(child: _FilterChip(label: 'Pendientes (${pendingList.length + dueTodayList.length})', value: 'pending', current: _filter,
                              onTap: (v) => setState(() => _filter = v))),
                          const SizedBox(width: 8),
                          Expanded(child: _FilterChip(label: 'Completadas (${completedList.length})', value: 'completed', current: _filter,
                              onTap: (v) => setState(() => _filter = v))),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Secciones clasificadas
                      if (!hasAnyTask)
                        Padding(
                          padding: const EdgeInsets.only(top: 48),
                          child: EmptyState(
                            emoji: '✅',
                            title: 'Sin tareas',
                            subtitle: 'No hay tareas en esta categoría.',
                          ),
                        )
                      else
                        ...sections.map((section) => _buildSection(section, isDark)),
                    ],
                  ),
                ),
              );
            },
            loading: () => SliverToBoxAdapter(child: LoadingList()),
            error: (e, _) => SliverToBoxAdapter(
              child: EmptyState(emoji: '⚠️', title: AppStrings.errorGeneric, subtitle: e.toString()),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildSection(_TaskSection section, bool isDark) {
    if (section.tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: section.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Icon(section.icon, size: 16, color: section.color),
              const SizedBox(width: 6),
              Text(
                section.label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : section.color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${section.tasks.length}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: section.color,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Tareas de la sección
        ...section.tasks.map((task) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _TaskAdminRow(
            task: task,
            isDark: isDark,
            // Editar/eliminar quedan reservados a quien la creó — el
            // otro padre/tutor o el otro profesor la ve igual, pero
            // no la puede tocar (misma regla que ya aplica el
            // servidor en firestore.rules).
            isCreator: task.assignedBy == null ||
                task.assignedBy == ref.read(authProvider)?.uid,
            onDelete: () => _confirmDelete(context, ref, task),
          ),
        )),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, TaskModel task) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Eliminar tarea',
      message:
          '¿Ocultar "${task.title}" de las listas? La información se conservará para rachas, historial y estadísticas.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(taskProvider.notifier).deleteTask(task.id);
    }
  }
}

class _TaskSection {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final List<TaskModel> tasks;

  const _TaskSection({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.tasks,
  });
}

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

class _TaskAdminRow extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  final bool isCreator;
  final VoidCallback onDelete;

  const _TaskAdminRow({
    required this.task,
    required this.isDark,
    required this.isCreator,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: task.isCompleted, isOverdue: task.isUrgent);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.navyBlue,
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Row(
              children: [
                Flexible(
                  child: Text(
                    '${task.subject} • ${EduDateUtils.shortDateLabel(task.dueDate)}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.grey,
                    ),
                  ),
                ),
                if (task.assignedByRole != null) ...[
                  const SizedBox(width: 6),
                  AssignedByBadge(assignedByRole: task.assignedByRole, compact: true),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TrafficLightBadge(task: task, compact: true),
                const SizedBox(width: 4),
                Icon(Icons.more_vert_rounded,
                    size: 20, color: isDark ? Colors.white38 : AppColors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    final color = AppColors.forDaysLeft(task.daysLeft, isCompleted: task.isCompleted, isOverdue: task.isUrgent);
    final sheetBg = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        // SafeArea con el contexto INTERNO del sheet — siempre correcto
        top: false,
        left: false,
        right: false,
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Info de la tarea
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.navyBlue,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          task.subject,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 13,
                            color: isDark ? Colors.white54 : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Divider(height: 1, color: isDark ? Colors.white10 : AppColors.lightGrey),
              const SizedBox(height: 6),
              _SheetTile(
                icon: Icons.visibility_outlined,
                label: 'Ver detalles',
                color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
                isDark: isDark,
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.taskView, extra: {'task': task, 'isAdmin': true});
                },
              ),
              if (isCreator) ...[
                if (!task.isCompleted)
                  _SheetTile(
                    icon: Icons.edit_outlined,
                    label: 'Editar',
                    color: AppColors.accentBlue,
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(ctx);
                      context.push(AppRoutes.adminEditTaskPath(task.id), extra: task);
                    },
                  ),
                _SheetTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Eliminar',
                  color: AppColors.statusRed,
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(ctx);
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
                          'Solo quien la creó puede editarla o eliminarla.',
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
