import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/themes/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/task_provider.dart';
import 'core/providers/event_provider.dart';
import 'core/data/local/models/task_model.dart';
import 'core/data/local/models/event_model.dart';
import 'core/data/local/models/notification_model.dart';
import 'core/services/sync_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/notification_bus.dart';

import 'core/providers/family_provider.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/complete_profile_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/student_code_screen.dart';
import 'features/auth/presentation/biometric_gate_screen.dart';
import 'core/features/permissions/permission_gate_screen.dart';
import 'core/features/student/student_home.dart';
import 'core/features/student/tasks/task_detail_screen.dart';
import 'core/features/student/tasks/task_view_screen.dart';
import 'core/features/student/tasks/complete_task_screen.dart';
import 'core/features/admin/admin_home.dart';
import 'core/features/admin/tasks/create_task_screen.dart';
import 'core/features/admin/tasks/edit_task_screen.dart';
import 'core/features/admin/events/create_event_screen.dart';
import 'core/features/admin/events/edit_event_screen.dart';
import 'core/features/admin/events/event_detail_screen.dart';
import 'core/features/settings/settings_screen.dart';
import 'core/features/notifications/notifications_screen.dart';

// ═══════════════════════════════════════════════════════════════
// ROUTER PROVIDER
// ═══════════════════════════════════════════════════════════════

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authProvider);
  final biometricUnlocked = ref.watch(biometricUnlockedProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,

    redirect: (context, state) {
      final loc = state.matchedLocation;
      final notifier = ref.read(authProvider.notifier);

      // Rutas públicas (sin sesión)
      const publicRoutes = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
        AppRoutes.studentCode,
        AppRoutes.splash,
        AppRoutes.permissions,
      };

      // 1. Perfil incompleto (Google primer login): gate de rol+edad
      if (user == null && notifier.needsProfileCompletion) {
        return loc == AppRoutes.completeProfile
            ? null
            : AppRoutes.completeProfile;
      }

      // 2. Sin sesión → solo rutas públicas
      if (user == null) {
        return publicRoutes.contains(loc) ? null : AppRoutes.login;
      }

      // 3. Adulto con email sin verificar (solo cuentas email/password)
      if (user.isAdult && !user.emailVerified && user.hasPasswordProvider) {
        return loc == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
      }

      // 4. Gate biométrico (si está activado y aún no desbloqueó)
      if (notifier.biometricEnabled && !biometricUnlocked) {
        return loc == AppRoutes.biometricGate
            ? null
            : AppRoutes.biometricGate;
      }

      // 5. Con sesión: fuera de las pantallas de auth
      final home = user.isStudent ? AppRoutes.student : AppRoutes.admin;
      if (publicRoutes.contains(loc) ||
          loc == AppRoutes.verifyEmail ||
          loc == AppRoutes.completeProfile ||
          loc == AppRoutes.biometricGate) {
        return home;
      }
      return null;
    },

    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, _) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.completeProfile,
        builder: (_, _) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.studentCode,
        builder: (_, _) => const StudentCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.biometricGate,
        builder: (_, _) => const BiometricGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.student,
        builder: (_, _) => const StudentHome(),
        routes: [
          GoRoute(
            path: 'task/:taskId',
            builder: (_, state) => TaskDetailScreen(task: state.extra as TaskModel),
            routes: [
              GoRoute(
                path: 'complete',
                builder: (_, state) => CompleteTaskScreen(task: state.extra as TaskModel),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.permissions,
        builder: (_, _) => const PermissionGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.taskView,
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>;
          return TaskViewScreen(
            task: args['task'] as TaskModel,
            isAdmin: args['isAdmin'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.eventView,
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>;
          return EventDetailScreen(
            event: args['event'] as EventModel,
            isAdmin: args['isAdmin'] as bool? ?? false,
          );
        },
      ),

      GoRoute(
        path: AppRoutes.admin,
        builder: (_, _) => const AdminHome(),
        routes: [
          GoRoute(
            path: 'tasks/new',
            builder: (_, _) => const CreateTaskScreen(),
          ),
          GoRoute(
            path: 'tasks/:taskId/edit',
            builder: (_, state) => EditTaskScreen(
              task: state.extra as TaskModel,
            ),
          ),
          GoRoute(
            path: 'events/new',
            builder: (_, _) => const CreateEventScreen(),
          ),
          GoRoute(
            path: 'events/:eventId/edit',
            builder: (_, state) => EditEventScreen(event: state.extra as EventModel),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text(
              'Página no encontrada',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Volver al inicio'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ═══════════════════════════════════════════════════════════════
// APP PRINCIPAL — con auto-cierre de sesión en background
// ═══════════════════════════════════════════════════════════════

class EduTrackApp extends ConsumerStatefulWidget {
  const EduTrackApp({super.key});

  @override
  ConsumerState<EduTrackApp> createState() => _EduTrackAppState();
}

class _EduTrackAppState extends ConsumerState<EduTrackApp>
    with WidgetsBindingObserver {
  Timer? _bgTimer;
  static const _bgTimeout = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSyncIfLoggedIn();
    });
  }

  Future<void> _startSyncIfLoggedIn() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    // Refrescar la lista de estudiantes vinculados (scope del sync)
    final family = ref.read(linkedStudentsProvider.notifier);
    if (user.isStudent) {
      await family.refreshForStudent(user.uid);
    } else {
      await family.refreshForAdult(user.uid);
    }

    // SharedPreferences ya fue inicializado en main() antes de runApp
    final prefs = await SharedPreferences.getInstance();
    final isFirstSyncDone = prefs.getBool('is_first_sync_completed') ?? false;

    // Guardar el momento exacto antes de cualquier sync
    await prefs.setString('app_first_opened_at', DateTime.now().toIso8601String());

    // 1. Solo descarga inicial si nunca se ha completado (evita re-descarga al reconectar)
    if (!isFirstSyncDone) {
      await SyncService.instance.initialSync(
        onTasksUpdated: () => ref.read(taskProvider.notifier).loadTasks(),
        onEventsUpdated: () => ref.read(eventProvider.notifier).loadEvents(),
      );
      await prefs.setBool('is_first_sync_completed', true);
    }

    // 2. Stream en tiempo real: detecta cambios mientras la app está abierta
    SyncService.instance.startRealtimeSync(
      onNewTaskReceived: (task) async {
        final currentUser = ref.read(authProvider);
        // Nueva tarea solo notifica al Estudiante (el Admin ya la creó)
        if (currentUser != null && !currentUser.isAdmin) {
          await _smartNotify(
            ref: ref,
            title: '📋 Nueva tarea asignada',
            body: '"${task.title}" — ${task.subject}.',
            type: NotificationType.taskAssigned,
            taskId: task.id,
          );
        }
      },
      onTaskUpdated: (oldTask, newTask) async {
        final currentUser = ref.read(authProvider);
        if (currentUser == null) return;

        // ── NOTIFICACIONES AL ESTUDIANTE ──────────────────────
        if (!currentUser.isAdmin) {
          if (oldTask.isInReview && newTask.isPending) {
            final reason = newTask.completionNote ?? 'Revisa los detalles.';
            await _smartNotify(
              ref: ref,
              title: 'Tarea rechazada ❌',
              body: '"${newTask.title}": $reason',
              type: NotificationType.taskRejected,
              taskId: newTask.id,
              isUrgent: true,
            );
          } else if (oldTask.isInReview && newTask.isCompleted) {
            await _smartNotify(
              ref: ref,
              title: '¡Tarea aprobada! ✅',
              body: '"${newTask.title}" fue aprobada por el admin.',
              type: NotificationType.taskCompleted,
              taskId: newTask.id,
            );
          } else if (!oldTask.isInReview && !newTask.isInReview &&
                     oldTask.updatedAt != newTask.updatedAt) {
            await _smartNotify(
              ref: ref,
              title: '📝 Tarea actualizada',
              body: '"${newTask.title}" fue modificada por el admin.',
              type: NotificationType.taskUpdated,
              taskId: newTask.id,
            );
          }
        }

        // ── NOTIFICACIONES AL ADMIN ───────────────────────────
        if (currentUser.isAdmin) {
          if (!oldTask.isInReview && newTask.isInReview) {
            await _smartNotify(
              ref: ref,
              title: '📤 Evidencia recibida',
              body: '"${newTask.title}" fue enviada a revisión.',
              type: NotificationType.evidenceUploaded,
              taskId: newTask.id,
            );
          }
        }
      },
      onTasksUpdated: () {
        ref.read(taskProvider.notifier).loadTasks();
      },
      onEventsUpdated: () {
        ref.read(eventProvider.notifier).loadEvents();
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AppLifecycleService.instance.setBackground();
      // Tras 3 min en background se re-bloquea el gate biométrico
      // (v2: reemplaza al auto-logout de la v1 — la sesión Firebase
      // persiste; solo se exige huella al volver)
      // NO se detiene el sync — el stream sigue activo para no perder cambios
      _bgTimer?.cancel();
      _bgTimer = Timer(_bgTimeout, () {
        if (ref.read(authProvider) != null &&
            ref.read(authProvider.notifier).biometricEnabled) {
          ref.read(biometricUnlockedProvider.notifier).state = false;
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      AppLifecycleService.instance.setForeground();
      _bgTimer?.cancel();
      _bgTimer = null;
      // Si el stream murió mientras estaba en background, lo reiniciamos
      _startSyncIfLoggedIn();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next != null) {
        _startSyncIfLoggedIn();
      } else {
        SyncService.instance.stopRealtimeSync();
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));

    return MaterialApp.router(
      title: 'EduTrack Family',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scrollBehavior: const _SmoothScrollBehavior(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: const Locale('es', 'PA'),
      supportedLocales: const [
        Locale('es', 'PA'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// HELPER — Notificación inteligente por rol y estado del app
// Foreground → campana interna | Background/cerrada → push
// ═══════════════════════════════════════════════════════════════

Future<void> _smartNotify({
  required WidgetRef ref,
  required String title,
  required String body,
  required NotificationType type,
  String? taskId,
  bool isUrgent = false,
}) async {
  await NotificationBus.dispatch(
    ref: ref,
    title: title,
    body: body,
    internalType: type,
    channel: isUrgent ? NotificationChannel.urgent : NotificationChannel.system,
    requireConfirm: isUrgent && !AppLifecycleService.instance.isInForeground,
    taskId: taskId,
    payload: taskId != null ? 'task:$taskId' : null,
  );
}

// ═══════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═══════════════════════════════════════════════════════════════

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _animController.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    // Verificar permisos críticos antes de continuar
    if (await _needsCriticalPermissions()) {
      if (mounted) context.go(AppRoutes.permissions);
      return;
    }

    if (!mounted) return;
    final user = ref.read(authProvider);
    if (user == null) {
      context.go(AppRoutes.login);
    } else if (user.isAdmin) {
      context.go(AppRoutes.admin);
    } else {
      context.go(AppRoutes.student);
    }
  }

  Future<bool> _needsCriticalPermissions() async {
    try {
      final notif = await Permission.notification.isGranted;
      if (!notif) return true;
      if (Platform.isAndroid) {
        final alarm = await Permission.scheduleExactAlarm.isGranted;
        if (!alarm) return true;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo + texto: fade + elastic scale
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: const Center(
                        child: Text('📚', style: TextStyle(fontSize: 52)),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text('EduTrack', style: AppTheme.splashTitle),
                    const Text('Family', style: AppTheme.splashSubtitle),
                    const SizedBox(height: 12),
                    const Text(
                      'Organiza. Aprende. Logra.',
                      style: AppTheme.splashTagline,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Spinner independiente: su propio controller con repeat()
            // garantiza que siempre gire, sin depender de _animController.
            const _SpinningLoader(),
          ],
        ),
      ),
    );
  }
}

class _SmoothScrollBehavior extends MaterialScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPINNER INDEPENDIENTE — su propio controller con repeat()
// No depende de animaciones externas: siempre gira.
// ─────────────────────────────────────────────────────────────
class _SpinningLoader extends StatefulWidget {
  const _SpinningLoader();

  @override
  State<_SpinningLoader> createState() => _SpinningLoaderState();
}

class _SpinningLoaderState extends State<_SpinningLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: SizedBox(
        width: 26,
        height: 26,
        child: CustomPaint(painter: _ArcPainter()),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    // Arco de 270° — deja un hueco que hace visible la rotación
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -1.5708, // empieza desde arriba (−π/2)
      4.7124,  // 270°
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => false;
}
