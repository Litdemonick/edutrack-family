import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/profile_photo_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';
import 'package:edutrack_family/core/shared/widgets/animated_bell_icon.dart';
import 'package:edutrack_family/core/features/admin/dashboard/widgets/stats_card.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';
import 'package:edutrack_family/features/family/presentation/widgets/student_selector.dart';

// ═══════════════════════════════════════════════════════════════
// ADMIN DASHBOARD — EduTrack Family
// Panel de control: estadísticas interactivas + estado del estudiante activo.
// ═══════════════════════════════════════════════════════════════

class AdminDashboard extends ConsumerWidget {
  final VoidCallback? onNavigateToReview;
  const AdminDashboard({super.key, this.onNavigateToReview});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider);
    final tasksAsync = ref.watch(taskProvider);
    final unread = ref.watch(unreadNotificationCountProvider);
    final studentName = ref.watch(activeStudentProvider)?.name ??
        RoleCopy.dashboardFallbackName(user?.role ?? UserRole.parent);

    return CustomScrollView(
      slivers: [
        // ── Header sin solapamiento de texto ──────────────────
        SliverAppBar(
          expandedHeight: 148,
          floating: false,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.navyBlue,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            // Selector de hijo/estudiante activo (multi-hijo 2.0)
            const StudentSelector(),
            const SizedBox(width: 6),
            // Avatar de perfil
            if (user != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.settings),
                  child: _ProfileAvatar(userId: user.id),
                ),
              ),
            AnimatedBellIcon(
              unread: unread,
              onTap: () => context.push(AppRoutes.notifications),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            // Title solo en la barra colapsada; background no llega hasta aquí
            titlePadding: const EdgeInsetsDirectional.fromSTEB(20, 0, 0, 14),
            title: const Text(
              'Panel de Control',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            // Background: saludo al tope para que no se pise con el title
            background: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.gradientNavy,
              ),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 68),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentBlue
                                  .withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        EduDateUtils.greetingByHour(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        user?.displayName ?? 'Admin',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        user?.avatarEmoji ?? '👩',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Contenido ─────────────────────────────────────────
        tasksAsync.when(
          data: (tasks) => _buildContent(context, tasks, isDark, studentName),
          loading: () => SliverToBoxAdapter(child: LoadingList()),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error: $e',
                  style: const TextStyle(fontFamily: 'Nunito')),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CONTENIDO DEL DASHBOARD
  // ─────────────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    List<TaskModel> tasks,
    bool isDark,
    String studentName,
  ) {
    final total = tasks.length;
    final completedList =
        tasks.where((t) => t.isCompleted).toList()
          ..sort((a, b) =>
              (b.completedAt ?? b.updatedAt)
                  .compareTo(a.completedAt ?? a.updatedAt));
    final urgentList =
        tasks.where((t) => t.isUrgent && !t.isCompleted).toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final reviewList = tasks.where((t) => t.isInReview).toList()
      ..sort((a, b) => (b.completedAt ?? b.updatedAt)
          .compareTo(a.completedAt ?? a.updatedAt));

    final dueTodayList = tasks.where((t) => t.isDueToday && !t.isCompleted).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final completed = completedList.length;
    final urgent = urgentList.length;
    final review = reviewList.length;
    final withEvidence = tasks.where((t) => t.hasEvidence).length;

    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 14),

        // ── Banner de revisión pendiente ─────────────────────
        if (review > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _ReviewBanner(
              count: review,
              isDark: isDark,
              onTap: onNavigateToReview ?? () {},
              studentName: studentName,
            ),
          ),

        // ── Contenido estilo estudiante: fecha + progreso + chips ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fecha
              Text(
                EduDateUtils.fullDateLabel(DateTime.now()),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: isDark ? Colors.white54 : AppColors.grey,
                ),
              ),
              const SizedBox(height: 10),

              // Progreso
              _ProgressCard(
                completed: completed,
                total: total,
                withEvidence: withEvidence,
                isDark: isDark,
                studentName: studentName,
              ),
              const SizedBox(height: 12),

              // Tarjetas de estadística — siempre son exactamente 4, así
              // que un crossAxisCount fijo (no maxCrossAxisExtent) las
              // hace estirarse para llenar TODO el ancho disponible en
              // vez de dejar columnas vacías en ventanas anchas (el
              // grid calculaba más columnas de las que hay tarjetas).
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.isCompact ? 2 : 4,
                  mainAxisExtent: 108,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                children: [
                  StatsCard(
                    label: 'Total',
                    value: total,
                    icon: Icons.assignment_outlined,
                    color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
                    isDark: isDark,
                    onTap: () => _showDetailSheet(
                      context,
                      label: 'Todas las tareas',
                      icon: Icons.assignment_outlined,
                      color: isDark ? AppColors.skyBlue : AppColors.navyBlue,
                      tasks: [...tasks]..sort(
                          (a, b) => a.dueDate.compareTo(b.dueDate)),
                      isDark: isDark,
                    ),
                  ),
                  StatsCard(
                    label: 'Completadas',
                    value: completed,
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusGreen,
                    isDark: isDark,
                    onTap: () => _showDetailSheet(
                      context,
                      label: 'Completadas',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusGreen,
                      tasks: completedList,
                      isDark: isDark,
                    ),
                  ),
                  StatsCard(
                    label: 'Vencen hoy',
                    value: dueTodayList.length,
                    icon: Icons.today_outlined,
                    color: AppColors.statusAmber,
                    isDark: isDark,
                    onTap: () => _showDetailSheet(
                      context,
                      label: 'Vencen hoy',
                      icon: Icons.today_outlined,
                      color: AppColors.statusAmber,
                      tasks: dueTodayList,
                      isDark: isDark,
                    ),
                  ),
                  StatsCard(
                    label: 'Urgentes',
                    value: urgent,
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.statusRed,
                    isDark: isDark,
                    onTap: () => _showDetailSheet(
                      context,
                      label: 'Urgentes',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.statusRed,
                      tasks: urgentList,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Estado vacío total ───────────────────────────────
        if (total == 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
            child: _EmptyState(isDark: isDark, studentName: studentName),
          ),

        const SizedBox(height: 32),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM SHEET DE DETALLE — al tocar un contador
  // ─────────────────────────────────────────────────────────────

  void _showDetailSheet(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required List<TaskModel> tasks,
    required bool isDark,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: tasks.isEmpty ? 0.35 : 0.88,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => _TaskDetailSheet(
          label: label,
          icon: icon,
          color: color,
          tasks: tasks,
          isDark: isDark,
          scrollController: scrollCtrl,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — listado detallado de tareas por categoría
// ─────────────────────────────────────────────────────────────

class _TaskDetailSheet extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final List<TaskModel> tasks;
  final bool isDark;
  final ScrollController scrollController;

  const _TaskDetailSheet({
    required this.label,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.isDark,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFBDBDBD),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            color: isDark ? Colors.white12 : AppColors.lightGrey,
          ),

          // Lista de tareas
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_rounded,
                            size: 48,
                            color: isDark
                                ? Colors.white24
                                : AppColors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'Sin tareas en esta categoría',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 14,
                            color: isDark ? Colors.white38 : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8, horizontal: 16),
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: isDark ? Colors.white10 : AppColors.lightGrey,
                    ),
                    itemBuilder: (ctx, i) =>
                        _DetailTaskRow(task: tasks[i], isDark: isDark),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FILA DE TAREA en el detalle del bottom sheet
// ─────────────────────────────────────────────────────────────

class _DetailTaskRow extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const _DetailTaskRow({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDaysLeft(
      task.daysLeft,
      isCompleted: task.isCompleted,
      isOverdue: task.isUrgent,
    );

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.taskView, extra: {'task': task, 'isAdmin': true});
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Indicador de color semáforo
            Container(
              width: 3,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
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
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        task.subject,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                      Text(
                        '  ·  ',
                        style: TextStyle(
                          color: isDark ? Colors.white24 : AppColors.lightGrey,
                        ),
                      ),
                      Text(
                        EduDateUtils.shortDateLabel(task.dueDate),
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            TrafficLightBadge(task: task),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: isDark ? Colors.white24 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA DE PROGRESO — gradiente + indicador circular
// ─────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int withEvidence;
  final bool isDark;
  final String studentName;

  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.withEvidence,
    required this.isDark,
    required this.studentName,
  });

  // Habla de studentName (el hijo/a o estudiante), no de "t\u00fa" \u2014 quien
  // ve este panel es el padre/tutor o profesor, nunca quien hace las
  // tareas. "t\u00fa puedes" ten\u00eda sentido en el panel del propio
  // estudiante (student/dashboard/widgets/today_summary.dart), no ac\u00e1.
  String _motivationalText(double progress) {
    if (progress == 1.0) return '\u00a1$studentName complet\u00f3 todo! \u{1F389}';
    if (progress >= 0.75) return '\u00a1$studentName ya casi termina! \u2728';
    if (progress >= 0.5) return '\u00a1$studentName va por m\u00e1s de la mitad! \u{1F525}';
    if (progress >= 0.25) return '$studentName va por buen camino';
    if (progress > 0) return '\u00a1Buen comienzo de $studentName! \u{1F4AA}';
    return '\u00a1\u00c1nimo, $studentName puede lograrlo! \u{1F4AA}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final pct = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D2347), Color(0xFF1A5098)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A5098).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progreso de $studentName',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontFamily: 'Poppins'),
                    children: [
                      TextSpan(
                        text: '$completed ',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '/ $total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'tareas completadas',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _motivationalText(progress),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (withEvidence > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_camera_outlined,
                                size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$withEvidence',
                              style: const TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 7,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              SizedBox(
                width: 82,
                height: 82,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    'listo',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BANNER DE REVISIÓN PENDIENTE
// ─────────────────────────────────────────────────────────────

class _ReviewBanner extends StatelessWidget {
  final int count;
  final bool isDark;
  final VoidCallback onTap;
  final String studentName;

  const _ReviewBanner({
    required this.count,
    required this.isDark,
    required this.onTap,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C4DFF).withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 18,
                color: Color(0xFF7C4DFF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 1
                        ? '1 tarea esperando revisión'
                        : '$count tareas esperando revisión',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7C4DFF),
                    ),
                  ),
                  Text(
                    '$studentName ${count == 1 ? "envió una tarea" : "envió tareas"} para que revises',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: const Color(0xFF7C4DFF).withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Color(0xFF7C4DFF),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AVATAR DE PERFIL — mini círculo en la AppBar
// ─────────────────────────────────────────────────────────────

class _ProfileAvatar extends ConsumerWidget {
  final String userId;
  const _ProfileAvatar({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoPath = ref.watch(profilePhotoProvider(userId));
    return Container(
      width: 34,
      height: 34,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.15),
        border: Border.all(color: Colors.white38, width: 1.5),
      ),
      child: ClipOval(
        child: photoPath != null && File(photoPath).existsSync()
            ? Image.file(File(photoPath), fit: BoxFit.cover)
            : const Center(
                child: Text('👩‍💼', style: TextStyle(fontSize: 16)),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ESTADO VACÍO — sin tareas registradas
// ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isDark;
  final String studentName;

  const _EmptyState({required this.isDark, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.lightGrey,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 44,
              color: isDark ? Colors.white38 : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Sin tareas aún',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppColors.navyBlue,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea la primera tarea para $studentName\ny aparecerá aquí para hacerle seguimiento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              color: isDark ? Colors.white38 : AppColors.grey,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push(AppRoutes.adminCreateTask),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Crear tarea'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navyBlue,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
