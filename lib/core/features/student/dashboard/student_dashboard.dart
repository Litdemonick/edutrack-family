import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/profile_photo_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/today_summary.dart';
import 'package:edutrack_family/core/shared/widgets/animated_bell_icon.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT DASHBOARD — EduTrack Family
// Panel principal de el estudiante: resumen interactivo + lista ordenada.
// Secciones: Urgentes → En revisión → Pendientes → Completadas
// ═══════════════════════════════════════════════════════════════

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final tasksAsync = ref.watch(taskProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return CustomScrollView(
      slivers: [
        // ── AppBar expandible ────────────────────────────────
        SliverAppBar(
          expandedHeight: 160,
          floating: false,
          pinned: true,
          centerTitle: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.navyBlue,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          actions: [
            // Avatar de perfil → abre Ajustes
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
            centerTitle: true,
            titlePadding: const EdgeInsets.only(bottom: 14),
            background: Container(
              decoration: const BoxDecoration(gradient: AppColors.gradientBlue),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 68),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _PulsingDot(),
                      const SizedBox(width: 7),
                      Text(
                        EduDateUtils.greetingByHour(),
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${AppStrings.studentWelcome}, ${user?.displayName.isNotEmpty == true ? user!.displayName : "estudiante"}! ${user?.avatarEmoji ?? "🎒"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            title: const Text(
              'Mis Tareas',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),

        // ── Resumen interactivo ──────────────────────────────
        SliverToBoxAdapter(
          child: tasksAsync.when(
            data: (tasks) => TodaySummary(tasks: tasks),
            loading: () => const SizedBox(height: 80, child: LoadingWidget()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),

        // ── Espacio inferior ─────────────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

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
        child:
            photoPath != null && File(photoPath).existsSync()
                ? Image.file(File(photoPath), fit: BoxFit.cover)
                : const Center(
                  child: Text('🎒', style: TextStyle(fontSize: 16)),
                ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PUNTO AZUL PARPADEANTE — junto al saludo
// ─────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scale = Tween<double>(
      begin: 0.75,
      end: 1.25,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.40,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.accentBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentBlue.withValues(alpha: 0.7),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
