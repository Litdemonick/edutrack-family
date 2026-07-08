import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'main.dart' show pendingLaunchNotificationPayload;
import 'core/constants/app_colors.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/themes/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/connectivity_provider.dart';
import 'core/firebase/firestore_paths.dart';
import 'core/firebase/firestore_service.dart';
import 'core/firebase/platform/firebase_backend.dart';
import 'core/data/local/models/app_user_model.dart' show SessionUser;
import 'core/providers/theme_provider.dart';
import 'core/providers/task_provider.dart';
import 'core/providers/event_provider.dart';
import 'core/providers/schedule_provider.dart';
import 'core/data/local/models/task_model.dart';
import 'core/data/local/models/event_model.dart';
import 'core/data/local/models/notification_model.dart';
import 'core/data/local/models/student_model.dart';
import 'core/data/local/repositories/task_repository.dart';
import 'core/data/local/repositories/event_repository.dart';
import 'core/providers/notification_provider.dart';
import 'core/services/sync_service.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_bus.dart';
import 'core/services/app_navigator.dart';
import 'core/constants/utils/notification_utils.dart';

import 'core/providers/family_provider.dart';
import 'core/data/local/repositories/student_repository.dart';
import 'core/utils/role_copy.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/complete_profile_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/student_code_screen.dart';
import 'features/auth/presentation/biometric_gate_screen.dart';
import 'features/auth/presentation/biometric_setup_screen.dart';
import 'features/family/presentation/family_screen.dart';
import 'features/location/parent/child_map_screen.dart';
import 'features/safety/seismic_alert_screen.dart';
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
import 'core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// ROUTER PROVIDER
// ═══════════════════════════════════════════════════════════════

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(authProvider);
  final biometricUnlocked = ref.watch(biometricUnlockedProvider);
  final biometricAvailable =
      ref.watch(biometricAvailableProvider).valueOrNull ?? false;

  // Sin esto, "desbloqueado con huella/Windows Hello" quedaba en
  // memoria para siempre dentro de la misma ejecución de la app —
  // cerrar sesión (normal o forzado, ej. contraseña cambiada por
  // correo) y volver a entrar con OTRA cuenta o la misma reutilizaba
  // el desbloqueo viejo, saltándose el gate biométrico por completo.
  ref.listen<SessionUser?>(authProvider, (previous, next) {
    if (next == null) {
      ref.read(biometricUnlockedProvider.notifier).state = false;
    }
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
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

      // 4. Configuración OBLIGATORIA de huella/Windows Hello — solo
      // padres/profesores, solo si el dispositivo la soporta, solo
      // una vez. Sin esto, cualquiera con la sesión del dispositivo
      // podría abrir la app sin verificarse.
      if (user.isAdult &&
          biometricAvailable &&
          !notifier.biometricSetupDone) {
        return loc == AppRoutes.biometricSetup
            ? null
            : AppRoutes.biometricSetup;
      }

      // 5. Gate biométrico (si está activado y aún no desbloqueó) —
      // a propósito SIN chequeo de rol: biometricEnabled es un
      // candado de DISPOSITIVO (lo activó el padre/tutor en Ajustes),
      // no de cuenta — si está prendido, protege la app en ese
      // equipo sin importar qué sesión esté cargada, estudiante
      // incluido. Solo la regla 4 (configurar huella por primera vez)
      // es exclusiva de adultos, porque un niño no configura nada.
      if (notifier.biometricEnabled && !biometricUnlocked) {
        return loc == AppRoutes.biometricGate
            ? null
            : AppRoutes.biometricGate;
      }

      final home = user.isStudent ? AppRoutes.student : AppRoutes.admin;

      // 6. Ubicación GPS: solo padre/tutor (profesores nunca, ver
      // firestore.rules locations/** → isGuardian()). Defensa en
      // profundidad: la nav ya oculta este ítem para profesores, pero
      // en builds Windows/Web la URL es editable a mano.
      if (loc == AppRoutes.locationMap && !user.isParent) {
        return home;
      }

      // 7. Con sesión: fuera de las pantallas de auth
      if (publicRoutes.contains(loc) ||
          loc == AppRoutes.verifyEmail ||
          loc == AppRoutes.completeProfile ||
          loc == AppRoutes.biometricGate ||
          loc == AppRoutes.biometricSetup) {
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
        path: AppRoutes.biometricSetup,
        builder: (_, _) => const BiometricSetupScreen(),
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
        path: AppRoutes.family,
        builder: (_, _) => const FamilyScreen(),
      ),
      GoRoute(
        path: AppRoutes.locationMap,
        builder: (_, _) => const ChildMapScreen(),
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

// Tipos de push de cambios en la vinculación de profesores (ver
// workers/edutrack-api/src/index.js: createLinkCode/redeemLinkCode/
// leaveStudent) — no tienen taskId/eventId, así que no usan el
// 'payload' de tareas/eventos, sino 'type' + studentId.
const _kFamilyPushTypesForAdult = {
  'teacher_access_revoked', // el padre regeneró el código: profesor(es) afectados
  'teacher_linked',         // un profesor se vinculó: para los padres/tutores
  'teacher_left',           // un profesor se desvinculó por su cuenta: para los padres/tutores
};
const _kFamilyPushTypesForStudent = {
  'teacher_access_revoked_student',
  'teacher_linked_student',
  'teacher_left_student',
};
final _kFamilyPushTypes = {
  ..._kFamilyPushTypesForAdult,
  ..._kFamilyPushTypesForStudent,
};

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

  /// Empuja lo pendiente (is_dirty) + trae lo nuevo, y solo recarga la
  /// pantalla si de verdad hubo cambios — usado al reconectar (no hay
  /// timer ciego: el stream en tiempo real, con reconexión automática,
  /// es quien detecta cambios mientras hay red; esto solo cubre el
  /// tramo en que no la hubo).
  Future<void> _syncAndReload() async {
    if (ref.read(authProvider) == null) return;
    await SyncService.instance.fullSync();
    if (!mounted) return;
    ref.read(taskProvider.notifier).loadTasks();
    ref.read(eventProvider.notifier).loadEvents();
    ref.read(scheduleProvider.notifier).load();
  }

  Future<void> _startSyncIfLoggedIn() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    // Registrar este dispositivo para push FCM (por uid)
    FcmService.instance.registerDevice(user.uid);
    _listenForegroundPush();
    _listenPushTaps();
    // Windows/Linux no tiene FCM (sin implementación nativa) — la
    // alerta sísmica ahí solo puede llegar mientras la app esté
    // abierta, por polling (decisión explícita: en desktop no se
    // intenta nada con la app cerrada, a diferencia de Android).
    _startDesktopSeismicPolling();

    // Refrescar la lista de estudiantes vinculados (scope del sync)
    final family = ref.read(linkedStudentsProvider.notifier);
    if (user.isStudent) {
      await family.refreshForStudent(user.uid);
    } else {
      await family.refreshForAdult(user.uid);
      // Escucha en vivo: si otro dispositivo agrega/edita/elimina un
      // hijo/a, se refleja solo mientras la app siga abierta.
      family.startWatching(user.uid);
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
      // Solo marcar como "hecha" si de verdad había al menos un
      // estudiante vinculado — initialSync no baja nada si la lista
      // estaba vacía (ej. un profesor que aún no había canjeado
      // ningún código la primera vez que abrió la app). Sin este
      // chequeo, esa descarga inicial quedaba "completada" para
      // siempre en falso, y un estudiante vinculado DESPUÉS nunca
      // recibía su descarga inicial de tareas/eventos — dependía
      // solo del stream en tiempo real, que si arranca justo cuando
      // el estudiante recién se agrega puede alcanzar a perderse el
      // primer snapshot en condiciones de carrera.
      if (ref.read(linkedStudentsProvider).isNotEmpty) {
        await prefs.setBool('is_first_sync_completed', true);
      }
    }

    // 2. Stream en tiempo real: detecta cambios mientras la app está abierta
    _startRealtimeSync();
  }

  /// Suscripciones en tiempo real (stream nativo en Android/iOS, polling
  /// cada 18s en Windows/Linux) — se llama al iniciar sesión Y de nuevo
  /// cada vez que cambia el conjunto de estudiantes vinculados (se agrega
  /// un hijo/a, un profesor gana acceso a uno nuevo, etc.). Sin este
  /// segundo disparo, un estudiante recién vinculado se quedaba sin
  /// sincronización en vivo hasta reabrir la app — startRealtimeSync ya
  /// cancela las suscripciones viejas antes de armar las nuevas
  /// (ver sync_service.dart), así que llamarlo de nuevo es seguro.
  void _startRealtimeSync() {
    SyncService.instance.startRealtimeSync(
      onNewTaskReceived: (task) async {
        final currentUser = ref.read(authProvider);
        AppLog.d('[Notif] onNewTaskReceived: task=${task.id} '
            'assignedBy=${task.assignedBy} currentUser=${currentUser?.uid} '
            'isAdmin=${currentUser?.isAdmin}');
        if (currentUser == null) return;
        // Solo se calla quien la creó (ya lo sabe) — antes se callaba
        // a CUALQUIER admin, asumiendo un solo padre/tutor por familia;
        // con un profesor vinculado además del padre, eso dejaba al
        // que no creó la tarea sin campana ni aviso alguno.
        final isCreator = task.assignedBy != null && task.assignedBy == currentUser.uid;
        if (isCreator) return;

        if (!currentUser.isAdmin) {
          await _smartNotify(
            ref: ref,
            title: '📋 Nueva tarea asignada',
            body: '${RoleCopy.actorLabelForStudent(task.assignedByRole)} '
                'agregó "${task.title}" — ${task.subject}.',
            type: NotificationType.taskAssigned,
            taskId: task.id,
          );
        } else {
          final student =
              await StudentRepository.instance.getById(task.studentId);
          if (student != null) {
            await _smartNotify(
              ref: ref,
              title: '📋 Nueva tarea agregada',
              body: RoleCopy.otherAdultActionText(task.assignedByRole,
                  currentUser.role, student.name, 'agregó una nueva tarea "${task.title}"'),
              type: NotificationType.taskAssigned,
              taskId: task.id,
            );
          }
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

        // ── NOTIFICACIONES AL ADMIN (padre/profesor) ──────────
        if (currentUser.isAdmin) {
          // El otro adulto vinculado (no quien hizo el cambio): como
          // editar/eliminar una tarea ya está restringido a quien la
          // creó (ver firestore.rules), assignedBy siempre identifica
          // a quien acaba de actuar — si soy yo, ya me enteré directo
          // al hacerlo (no duplicar).
          final isOtherAdultAction = newTask.assignedBy != null &&
              newTask.assignedBy != currentUser.uid;
          final deleted = !oldTask.isDeleted && newTask.isDeleted;
          AppLog.d('[Notif] onTaskUpdated (admin): task=${newTask.id} '
              'deleted=$deleted assignedBy=${newTask.assignedBy} '
              'assignedByRole=${newTask.assignedByRole} '
              'currentUser=${currentUser.uid} role=${currentUser.role.name} '
              'isOtherAdultAction=$isOtherAdultAction '
              'oldUpdatedAt=${oldTask.updatedAt} newUpdatedAt=${newTask.updatedAt}');

          if (deleted) {
            if (isOtherAdultAction) {
              final student =
                  await StudentRepository.instance.getById(newTask.studentId);
              if (student != null) {
                await _smartNotify(
                  ref: ref,
                  title: '🗑️ Tarea eliminada',
                  body: RoleCopy.otherAdultActionText(
                      newTask.assignedByRole,
                      currentUser.role,
                      student.name,
                      'eliminó la tarea "${newTask.title}"'),
                  type: NotificationType.taskDeleted,
                  taskId: newTask.id,
                );
              }
            }
          } else if (!oldTask.isInReview && newTask.isInReview) {
            final assignerLabel = RoleCopy.assignedByLabel(newTask.assignedByRole);
            await _smartNotify(
              ref: ref,
              title: '📤 Evidencia recibida',
              body: assignerLabel != null
                  ? '"${newTask.title}" (tarea de $assignerLabel) fue '
                      'enviada a revisión.'
                  : '"${newTask.title}" fue enviada a revisión.',
              type: NotificationType.evidenceUploaded,
              taskId: newTask.id,
            );
          } else if (!oldTask.isCompleted &&
              newTask.isCompleted &&
              !newTask.isInReview) {
            // Tarea marcada como hecha directo, sin pasar por revisión
            // (sin evidencia) — el push remoto ya lo manda
            // markCompleted; esto es solo para que la campana se
            // actualice sola mientras el padre/profesor tiene la app
            // abierta, igual que "Evidencia recibida" arriba.
            await _smartNotify(
              ref: ref,
              title: '✅ Tarea completada',
              body: '"${newTask.title}" fue marcada como completada.',
              type: NotificationType.taskCompleted,
              taskId: newTask.id,
            );
          } else if (oldTask.updatedAt != newTask.updatedAt &&
              isOtherAdultAction) {
            // Edición simple (no de revisión) hecha por el OTRO adulto
            // — a mí (quien la hizo) ya me llegó mi propia campana
            // directo desde updateTask(); esto es solo para el resto.
            final student =
                await StudentRepository.instance.getById(newTask.studentId);
            if (student != null) {
              await _smartNotify(
                ref: ref,
                title: '✏️ Tarea actualizada',
                body: RoleCopy.otherAdultActionText(
                    newTask.assignedByRole,
                    currentUser.role,
                    student.name,
                    'actualizó la tarea "${newTask.title}"'),
                type: NotificationType.taskUpdated,
                taskId: newTask.id,
              );
            }
          }
        }
      },
      onScheduleBlockAdded: (block) async {
        // El push remoto (con targetUids) ya lo manda quien creó el
        // bloque — esto es solo la campana en los OTROS dispositivos.
        // Si assignedBy es mi propio uid, es el eco de mi propio
        // cambio (ya me llegó directo al crear) — no duplicar.
        final currentUser = ref.read(authProvider);
        if (currentUser == null || block.assignedBy == currentUser.uid) return;
        await _smartNotify(
          ref: ref,
          title: '📅 Nueva clase en el horario',
          body: '"${block.subject}" se agregó al horario.',
          type: NotificationType.general,
        );
        ref.read(scheduleProvider.notifier).load();
      },
      onScheduleBlockUpdated: (oldBlock, newBlock) async {
        final currentUser = ref.read(authProvider);
        if (currentUser == null || newBlock.assignedBy == currentUser.uid) return;
        final deleted = !oldBlock.isDeleted && newBlock.isDeleted;
        await _smartNotify(
          ref: ref,
          title: deleted ? '🗑️ Clase eliminada' : '📝 Horario actualizado',
          body: deleted
              ? '"${newBlock.subject}" se quitó del horario.'
              : '"${newBlock.subject}" fue modificada en el horario.',
          type: NotificationType.general,
        );
        ref.read(scheduleProvider.notifier).load();
      },
      onNewEventReceived: (event) async {
        final currentUser = ref.read(authProvider);
        AppLog.d('[Notif] onNewEventReceived: event=${event.id} '
            'assignedBy=${event.assignedBy} currentUser=${currentUser?.uid} '
            'isAdmin=${currentUser?.isAdmin}');
        if (currentUser == null) return;
        final isCreator = event.assignedBy != null && event.assignedBy == currentUser.uid;
        if (isCreator) return;

        if (!currentUser.isAdmin) {
          await _smartNotify(
            ref: ref,
            title: '📅 Nuevo evento',
            body: '${RoleCopy.actorLabelForStudent(event.assignedByRole)} '
                'agregó "${event.title}" al calendario.',
            type: NotificationType.eventCreated,
            eventId: event.id,
          );
        } else {
          final student =
              await StudentRepository.instance.getById(event.studentId);
          if (student != null) {
            await _smartNotify(
              ref: ref,
              title: '📅 Nuevo evento agregado',
              body: RoleCopy.otherAdultActionText(event.assignedByRole,
                  currentUser.role, student.name, 'agregó un nuevo evento "${event.title}"'),
              type: NotificationType.eventCreated,
              eventId: event.id,
            );
          }
        }
      },
      onEventUpdated: (oldEvent, newEvent) async {
        final currentUser = ref.read(authProvider);
        if (currentUser == null) return;
        final isCreator = newEvent.assignedBy != null && newEvent.assignedBy == currentUser.uid;
        AppLog.d('[Notif] onEventUpdated: event=${newEvent.id} '
            'assignedBy=${newEvent.assignedBy} currentUser=${currentUser.uid} '
            'isCreator=$isCreator isAdmin=${currentUser.isAdmin}');
        if (isCreator) return;

        final deleted = !oldEvent.isDeleted && newEvent.isDeleted;
        final action = deleted
            ? 'eliminó el evento "${newEvent.title}"'
            : 'actualizó el evento "${newEvent.title}"';

        if (!currentUser.isAdmin) {
          await _smartNotify(
            ref: ref,
            title: deleted ? '🗑️ Evento eliminado' : '📅 Evento actualizado',
            body: deleted
                ? '${RoleCopy.actorLabelForStudent(newEvent.assignedByRole)} '
                    'eliminó "${newEvent.title}" del calendario.'
                : '${RoleCopy.actorLabelForStudent(newEvent.assignedByRole)} '
                    'modificó "${newEvent.title}".',
            type: deleted ? NotificationType.eventDeleted : NotificationType.eventUpdated,
            eventId: newEvent.id,
          );
        } else {
          final student =
              await StudentRepository.instance.getById(newEvent.studentId);
          if (student != null) {
            await _smartNotify(
              ref: ref,
              title: deleted ? '🗑️ Evento eliminado' : '📅 Evento actualizado',
              body: RoleCopy.otherAdultActionText(newEvent.assignedByRole,
                  currentUser.role, student.name, action),
              type: deleted ? NotificationType.eventDeleted : NotificationType.eventUpdated,
              eventId: newEvent.id,
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

  bool _seismicAlertShowing = false;

  /// Empuja la pantalla completa de alerta sísmica (suena/vibra en
  /// bucle hasta "Entendido") — se llama tanto si el mensaje llega
  /// con la app abierta como al tocar la notificación con la app en
  /// segundo plano/cerrada. Guard contra doble apertura si por
  /// timing ambos caminos coincidieran.
  void _showSeismicAlert(String title, String body) {
    if (_seismicAlertShowing) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    _seismicAlertShowing = true;
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SeismicAlertScreen(title: title, body: body),
        ))
        .then((_) => _seismicAlertShowing = false);
  }

  // ─────────────────────────────────────────────────────────────
  // ALERTA SÍSMICA EN WINDOWS/LINUX — polling, solo mientras la app
  // esté abierta (no hay FCM para desktop, así que a diferencia de
  // Android no hay forma de que llegue con la app cerrada; decisión
  // explícita: en desktop no se intenta nada en ese caso).
  //
  // El Worker escribe students/{id}/seismicAlertsLog/{quakeId} cada
  // vez que le manda push a alguien por un sismo — acá simplemente
  // se lee esa misma bitácora por estudiante vinculado, sin
  // recalcular distancia/magnitud del lado del cliente.
  // ─────────────────────────────────────────────────────────────
  Timer? _desktopSeismicPollTimer;
  final Set<String> _seenSeismicAlertIds = {};
  bool _seismicPollPrimed = false;

  void _startDesktopSeismicPolling() {
    if (!useDesktopRestBackend) return;
    if (_desktopSeismicPollTimer != null) return;
    _desktopSeismicPollTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _pollDesktopSeismicAlerts());
    _pollDesktopSeismicAlerts();
  }

  void _stopDesktopSeismicPolling() {
    _desktopSeismicPollTimer?.cancel();
    _desktopSeismicPollTimer = null;
    _seenSeismicAlertIds.clear();
    _seismicPollPrimed = false;
  }

  Future<void> _pollDesktopSeismicAlerts() async {
    final students = ref.read(linkedStudentsProvider);
    for (final s in students) {
      try {
        final docs = await FirestoreService.instance.getRawCollection(
            FirestorePaths.seismicAlertLogCollection(s.id));
        for (final doc in docs) {
          final id = doc['id'] as String?;
          if (id == null || _seenSeismicAlertIds.contains(id)) continue;
          _seenSeismicAlertIds.add(id);
          // La primera pasada (recién logueado) solo marca lo que ya
          // existía como "visto" — no hay que alertar por sismos
          // viejos que ya se avisaron por push en su momento.
          if (!_seismicPollPrimed) continue;
          _showSeismicAlert(
            (doc['title'] as String?) ?? '🌍 Sismo detectado',
            (doc['body'] as String?) ?? '',
          );
        }
      } catch (e) {
        AppLog.d('[SeismicPoll] error: $e');
      }
    }
    _seismicPollPrimed = true;
  }

  StreamSubscription? _fcmForegroundSub;

  /// Push FCM llegadas con la app abierta: el sistema no las muestra,
  /// así que las mostramos como notificación local. Las urgentes
  /// (sismo, check-in) van por el canal urgente con sonido fuerte.
  void _listenForegroundPush() {
    if (_fcmForegroundSub != null) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    _fcmForegroundSub =
        FcmService.instance.onForegroundMessage.listen((message) async {
      final title = message.notification?.title;
      final body = message.notification?.body;
      if (title == null || body == null) return;

      final type = message.data['type'] as String?;
      // El check-in del hijo lo maneja WellnessCheckGate por Firestore
      // (pantalla + sonido en bucle) — no duplicar esa parte, pero sí
      // dejar registro en su campana de que le llegó el aviso.
      if (type == 'wellness_check') {
        ref.read(notificationProvider.notifier).dispatchFull(
              title: title,
              body: body,
              type: NotificationType.wellnessCheck,
            );
        return;
      }

      // Cambios de vinculación de profesor (padre regeneró código,
      // profesor se vinculó/desvinculó): además de la notificación
      // local, quedan en la campana — a diferencia de sismo/check-in,
      // sí vale la pena poder revisarlas después.
      if (_kFamilyPushTypes.contains(type)) {
        ref.read(notificationProvider.notifier).dispatchFull(
              title: title,
              body: body,
              type: NotificationType.familyUpdate,
              route: _kFamilyPushTypesForAdult.contains(type)
                  ? AppRoutes.family
                  : null,
            );
      }

      // Payload propio (aparte de 'task:id'/'event:id') para que, si el
      // usuario no toca la notificación de inmediato y lo hace después
      // desde la bandeja del sistema, notificationTapBackground (en
      // main.dart) todavía sepa a dónde navegar.
      final localPayload =
          _kFamilyPushTypes.contains(type) ? 'family:$type' : null;

      // Push genérico de tarea/evento (ej. el aviso al OTRO adulto
      // vinculado de _notifyOtherAdults en task/event_provider.dart, o
      // el push directo al estudiante desde create/update/deleteTask):
      // antes solo se mostraba como notificación del sistema, sin
      // quedar nunca en la campana interna. Ahora también se refleja
      // ahí, igual que ya pasa con los cambios de vinculación de
      // profesor arriba.
      final rawPayload = message.data['payload'] as String?;
      String? taskId;
      String? eventId;
      if (rawPayload != null) {
        if (rawPayload.startsWith('task_deleted:')) {
          taskId = rawPayload.substring('task_deleted:'.length);
        } else if (rawPayload.startsWith('task:')) {
          taskId = rawPayload.substring('task:'.length);
        } else if (rawPayload.startsWith('event_deleted:')) {
          eventId = rawPayload.substring('event_deleted:'.length);
        } else if (rawPayload.startsWith('event:')) {
          eventId = rawPayload.substring('event:'.length);
        }
      }
      // Sismo y check-in (respuesta/timeout) también quedan en la
      // campana con su propio tipo — antes se excluían a propósito,
      // pero un aviso de seguridad es justo lo que más vale la pena
      // poder revisar después.
      if (!_kFamilyPushTypes.contains(type)) {
        final safetyType = type == 'seismic'
            ? NotificationType.seismicAlert
            : (type == 'wellness_timeout' || type == 'wellness_response')
                ? NotificationType.wellnessCheck
                : null;
        ref.read(notificationProvider.notifier).dispatchFull(
              title: title,
              body: body,
              type: safetyType ?? NotificationType.general,
              taskId: taskId,
              eventId: eventId,
            );
      }

      final urgent = type == 'seismic' || type == 'wellness_timeout';
      if (urgent) {
        // Canal de seguridad (sonido fuerte fijo) en vez del canal
        // urgente genérico — este último respeta el toggle general
        // de sonido/vibración, que no debería poder silenciar un
        // sismo o un check-in sin respuesta.
        await NotificationUtils.showSafetyAlert(
          title: title,
          body: body,
          requireConfirm: type == 'seismic',
          payload: localPayload,
        );
        // Sismo: además de la notificación del sistema, pantalla
        // completa con sonido/vibración EN BUCLE hasta "Entendido" —
        // un sismo real no debe poder pasar con un solo beep. Se
        // muestra a cualquier rol (padre/tutor, profesor, estudiante).
        if (type == 'seismic') _showSeismicAlert(title, body);
      } else {
        // Mismo taskId/eventId → mismo ID de notificación (ver
        // _deterministicId) — si el eco de Firestore ya mostró la
        // suya para este mismo cambio, esta la reemplaza en vez de
        // sumarse (no duplica); y si el eco no llegó a tiempo, esta
        // igual se ve (no se pierde el aviso).
        await NotificationUtils.showSystemNotification(
          title: title,
          body: body,
          payload: localPayload,
          taskId: taskId,
          eventId: eventId,
          notifType: NotificationType.general,
        );
      }
    });
  }

  StreamSubscription? _fcmTapSub;

  /// El usuario tocó una notificación push — la app puede estar
  /// abriéndose desde cero (terminated), reanudando (background), o
  /// ya abierta. En los 3 casos hay que navegar a lo que corresponda.
  void _listenPushTaps() {
    if (_fcmTapSub != null) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    _fcmTapSub =
        FcmService.instance.onNotificationTap.listen(_handlePushTap);
    FcmService.instance.initialMessage.then((message) {
      if (message != null) _handlePushTap(message);
    });

    // Alerta sísmica que abrió la app estando completamente cerrada
    // (fullScreenIntent, ver _firebaseMessagingBackgroundHandler en
    // main.dart) — consumido una sola vez, ahora que el árbol de
    // widgets ya está montado.
    final launchPayload = pendingLaunchNotificationPayload;
    pendingLaunchNotificationPayload = null;
    if (launchPayload != null && launchPayload.startsWith('seismic_alert|')) {
      final parts = launchPayload.split('|');
      final title = parts.length > 1 ? parts[1] : '🌍 Sismo detectado';
      final body = parts.length > 2 ? parts.sublist(2).join('|') : '';
      _showSeismicAlert(title, body);
    }
  }

  String? _lastHandledPushMessageId;

  Future<void> _handlePushTap(RemoteMessage message) async {
    // getInitialMessage() y onMessageOpenedApp pueden disparar los
    // DOS para el mismo toque en frío (app estaba totalmente
    // cerrada) — sin este guard, quedaba una entrada duplicada en
    // la campana y se navegaba dos veces.
    if (message.messageId != null &&
        message.messageId == _lastHandledPushMessageId) {
      return;
    }
    _lastHandledPushMessageId = message.messageId;

    final data = message.data;
    final title = message.notification?.title;
    final body = message.notification?.body;
    final type = data['type'] as String?;

    // Si llegó mientras la app estaba cerrada/en background, nunca
    // pasó por _listenForegroundPush — se agrega a la campana recién
    // ahora, al tocarla.
    if (type != null &&
        _kFamilyPushTypes.contains(type) &&
        title != null &&
        body != null) {
      ref.read(notificationProvider.notifier).dispatchFull(
            title: title,
            body: body,
            type: NotificationType.familyUpdate,
            route:
                _kFamilyPushTypesForAdult.contains(type) ? AppRoutes.family : null,
          );
    }

    // Igual que arriba pero para sismo/check-in: si la app estaba
    // cerrada/en background, _listenForegroundPush nunca corrió, así
    // que hay que dejarlo en la campana y (para sismo) abrir la
    // pantalla en bucle recién ahora, al tocar la notificación.
    if (title != null &&
        body != null &&
        (type == 'seismic' ||
            type == 'wellness_timeout' ||
            type == 'wellness_response')) {
      ref.read(notificationProvider.notifier).dispatchFull(
            title: title,
            body: body,
            type: type == 'seismic'
                ? NotificationType.seismicAlert
                : NotificationType.wellnessCheck,
          );
      if (type == 'seismic') _showSeismicAlert(title, body);
    }

    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final payload = data['payload'] as String?;
    if (payload != null) {
      final parts = payload.split(':');
      if (parts.length == 2) {
        final kind = parts[0];
        final id = parts[1];
        final user = ref.read(authProvider);
        if (kind == 'task') {
          final task = await TaskRepository.instance.getTaskById(id);
          if (task != null && context.mounted) {
            context.push(AppRoutes.taskView, extra: {
              'task': task,
              'isAdmin': user?.isAdmin ?? false,
            });
          }
          return;
        } else if (kind == 'event') {
          final event = await EventRepository.instance.getEventById(id);
          if (event != null && context.mounted) {
            context.push(AppRoutes.eventView, extra: {
              'event': event,
              'isAdmin': user?.isAdmin ?? false,
            });
          }
          return;
        }
        // task_deleted/event_deleted: nada a donde navegar.
        return;
      }
    }

    if (type != null &&
        _kFamilyPushTypesForAdult.contains(type) &&
        context.mounted) {
      context.push(AppRoutes.family);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bgTimer?.cancel();
    _fcmForegroundSub?.cancel();
    _fcmTapSub?.cancel();
    _desktopSeismicPollTimer?.cancel();
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
        SyncService.instance.resetPullState();
        FcmService.instance.unregisterDevice();
        _stopDesktopSeismicPolling();
        // La campana es por dispositivo (SharedPreferences), no por
        // uid — sin esto, cambiar de cuenta en el mismo dispositivo
        // dejaba ver el historial de la sesión anterior mezclado con
        // la nueva.
        ref.read(notificationProvider.notifier).clear();
      }
    });

    // Sin timer ciego: el stream en tiempo real (con reconexión
    // automática) es quien detecta cambios mientras hay red. Esto
    // solo cubre el tramo sin conexión — al volver a estar online,
    // empuja lo pendiente y trae lo que se perdió mientras tanto.
    ref.listen<bool>(connectivityProvider, (previous, next) {
      if (previous == false && next == true) {
        _syncAndReload();
      }
    });

    // Si se agrega/quita un estudiante vinculado (hijo nuevo, profesor
    // que gana/pierde acceso a otro) mientras la app sigue abierta,
    // rearmar las suscripciones en tiempo real para que ese estudiante
    // quede sincronizándose también — antes solo pasaba al reabrir la
    // app o volver del segundo plano.
    ref.listen<List<StudentProfile>>(linkedStudentsProvider, (previous, next) {
      // previous == null es la primera carga (ya cubierta por
      // _startSyncIfLoggedIn) — solo interesa un cambio real después.
      if (previous == null || ref.read(authProvider) == null) return;
      final oldIds = previous.map((s) => s.id).toSet();
      final newIds = next.map((s) => s.id).toSet();
      if (oldIds.length != newIds.length || !oldIds.containsAll(newIds)) {
        _startRealtimeSync();
      }
    });

    // Respaldo por polling para Windows/Linux (sin FCM): detecta
    // cambios de vinculación de profesor comparando la lista anterior
    // vs la nueva de linkedStudentsProvider (ya se actualiza sola por
    // el polling de escritorio, cada ~15-20s). Solo campana, sin
    // notificación local del sistema — en Android/iOS esto ya llega
    // por push+campana vía _listenForegroundPush/_handlePushTap, así
    // que aquí solo corre en las plataformas donde FCM no existe,
    // para no duplicar la entrada en la campana.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      ref.listen<List<StudentProfile>>(linkedStudentsProvider,
          (previous, next) {
        if (previous == null) return;
        final user = ref.read(authProvider);
        if (user == null) return;

        if (user.isParent) {
          for (final newStudent in next) {
            StudentProfile? oldStudent;
            for (final s in previous) {
              if (s.id == newStudent.id) {
                oldStudent = s;
                break;
              }
            }
            if (oldStudent == null) continue;
            final oldTeachers = oldStudent.teacherIds.toSet();
            final newTeachers = newStudent.teacherIds.toSet();
            if (newTeachers.difference(oldTeachers).isNotEmpty) {
              ref.read(notificationProvider.notifier).dispatchFull(
                    title: 'Nuevo profesor vinculado',
                    body: '${newStudent.name} tiene un nuevo profesor con acceso.',
                    type: NotificationType.familyUpdate,
                    route: AppRoutes.family,
                  );
            }
            if (oldTeachers.difference(newTeachers).isNotEmpty) {
              ref.read(notificationProvider.notifier).dispatchFull(
                    title: 'Profesor removido',
                    body: 'Un profesor ya no tiene acceso a ${newStudent.name}.',
                    type: NotificationType.familyUpdate,
                    route: AppRoutes.family,
                  );
            }
          }
        } else if (user.isTeacher) {
          final oldIds = previous.map((s) => s.id).toSet();
          final newIds = next.map((s) => s.id).toSet();
          if (oldIds.difference(newIds).isNotEmpty) {
            ref.read(notificationProvider.notifier).dispatchFull(
                  title: 'Acceso removido',
                  body: 'Ya no tienes acceso a un estudiante.',
                  type: NotificationType.familyUpdate,
                  route: AppRoutes.family,
                );
          }
        }
      });
    }

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);

    // Transparente: Android 15+ (edge-to-edge obligatorio) IGNORA
    // cualquier color sólido que se le pida a la barra de estado —
    // solo respeta transparente. Lo que de verdad se ve detrás lo
    // resuelve el Container del builder de más abajo, no esto.
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
      // SafeArea global (los 4 lados): en horizontal, la barra de
      // navegación del sistema puede estar a la IZQUIERDA o DERECHA
      // en vez de abajo (según el celular/modo de navegación) — sin
      // esto cada pantalla debía acordarse de evitarla por su cuenta,
      // y muchas no lo hacían. Anidar SafeArea es seguro: el padding
      // que ya consume este se reporta en cero a los descendientes,
      // así que los SafeArea puntuales que ya existen en pantallas
      // individuales no duplican espacio.
      //
      // Container por FUERA del SafeArea (no adentro): pinta el color
      // de fondo hasta el borde físico real de la pantalla, detrás de
      // la barra de estado/gestos transparente — si el color estuviera
      // solo adentro del SafeArea, esa franja quedaría sin pintar y se
      // vería el fondo nativo de Android (negro) en vez del de la app.
      builder: (context, child) => Container(
        color: isDark ? const Color(0xFF12121E) : AppColors.background,
        child: SafeArea(child: child ?? const SizedBox()),
      ),
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
  String? eventId,
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
    eventId: eventId,
    payload: taskId != null
        ? 'task:$taskId'
        : (eventId != null ? 'event:$eventId' : null),
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
    // Delay mínimo (para que el splash no sea en sí un parpadeo) +
    // espera a que la sesión termine de restaurarse de verdad, en vez
    // de asumir tras un tiempo fijo que "sin usuario todavía" ya es
    // definitivo — en Windows (restauración por red) eso mandaba a
    // /login para, un instante después, ser redirigido al panel: un
    // parpadeo visible de la pantalla de login. Techo de seguridad de
    // 6s por si la restauración nunca resuelve (sin red, error, etc.)
    // para no dejar el splash trabado para siempre.
    final minDelay = Future.delayed(const Duration(milliseconds: 1200));
    final authReady = () async {
      final deadline = DateTime.now().add(const Duration(seconds: 6));
      while (mounted &&
          !ref.read(authProvider.notifier).hasResolvedOnce &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }();
    await Future.wait([minDelay, authReady]);
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
