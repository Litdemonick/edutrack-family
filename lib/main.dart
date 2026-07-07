import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants/app_routes.dart';
import 'core/constants/utils/notification_utils.dart';
import 'core/data/local/repositories/event_repository.dart';
import 'core/data/local/repositories/task_repository.dart';
import 'core/firebase/platform/firebase_backend.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/app_navigator.dart';
import 'features/safety/seismic_alert_screen.dart';
import 'firebase_options.dart';

// ─────────────────────────────────────────────────────────────
// SHARED PREFERENCES PROVIDER — accesible globalmente
// Se inyecta en ProviderScope con el valor real de main()
// ─────────────────────────────────────────────────────────────
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences no inicializado'),
);

// ─────────────────────────────────────────────────────────────
// PLUGIN GLOBAL DE NOTIFICACIONES
// Debe ser top-level para acceder desde background isolates
// ─────────────────────────────────────────────────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Payload de una notificación local que abrió la app estando
/// completamente cerrada (hoy solo lo usa la alerta sísmica con
/// fullScreenIntent) — se consume una sola vez desde
/// _EduTrackAppState._listenPushTaps() apenas el árbol de widgets
/// está montado (en main() todavía no existe rootNavigatorKey).
String? pendingLaunchNotificationPayload;

// ─────────────────────────────────────────────────────────────
// FCM EN SEGUNDO PLANO — alerta sísmica con pantalla completa
// aunque la app esté matada del todo.
//
// Corre en un isolate nuevo (sin ProviderScope/Navigator), así que
// no puede navegar directamente. En vez de eso, muestra ELLA MISMA
// una notificación local con fullScreenIntent:true — eso es lo que
// hace que Android "tome" la pantalla sola (igual que una llamada
// entrante) cuando el celular está bloqueado, sin que nadie toque
// nada. Si el usuario sí la toca (o Android la lanzó sola), el
// payload queda disponible vía getNotificationAppLaunchDetails() al
// arrancar main() — ver pendingLaunchNotificationPayload arriba.
//
// Solo sismo: es la única alerta que debe poder "tomar" la pantalla
// sin que el usuario toque nada primero (ver el check-in "¿Estás
// bien?", que a propósito NO hace esto: ese ya lo maneja
// WellnessCheckGate mientras la app está viva).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'seismic') return;

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {
    // Ya inicializado en este isolate — puede pasar si Android reusa
    // el motor entre mensajes seguidos.
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  final title = message.notification?.title ?? '🌍 Sismo detectado';
  final body = message.notification?.body ??
      'Ponte en un lugar seguro, mantén la calma y espera instrucciones.';

  await plugin.show(
    id: DateTime.now().millisecondsSinceEpoch % 90000 + 10000,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        NotificationUtils.channelSafetyId,
        NotificationUtils.channelSafetyName,
        channelDescription: NotificationUtils.channelSafetyDesc,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      ),
    ),
    // '|' en vez de ':' (formato de los demás payloads) para no
    // chocar con el parseo genérico 'kind:id' de _handleLocalNotificationTap.
    payload: 'seismic_alert|$title|$body',
  );
}

// ─────────────────────────────────────────────────────────────
// HANDLER DE NOTIFICACIONES EN BACKGROUND
// flutter_local_notifications: cuando la app está cerrada
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Corre en un isolate nuevo y aislado (la app fue matada del todo,
  // no solo puesta en segundo plano) — sin ProviderScope ni Navigator
  // disponibles ahí, no hay forma segura de navegar. El caso real
  // (app en background, no matada) sí navega — ver
  // onDidReceiveNotificationResponse más abajo, que además cubre
  // el 99% de los toques reales porque las notificaciones locales
  // solo se muestran mientras la app ya está corriendo.
  debugPrint(
    '[EduTrack] Notificación en background: ${notificationResponse.payload}',
  );
}

/// Navega según el payload de una notificación local tocada —
/// mismo formato 'task:id' / 'event:id' / 'family:type' que ya usa
/// el manejo de push en app.dart (_handlePushTap).
Future<void> _handleLocalNotificationTap(String? payload) async {
  if (payload == null) return;
  final context = rootNavigatorKey.currentContext;
  if (context == null) return;

  // Alerta sísmica mostrada por _firebaseMessagingBackgroundHandler
  // (fullScreenIntent) — formato 'seismic_alert|title|body', con '|'
  // en vez de ':' para no chocar con el parseo genérico de abajo.
  if (payload.startsWith('seismic_alert|')) {
    final parts = payload.split('|');
    final title = parts.length > 1 ? parts[1] : '🌍 Sismo detectado';
    final body = parts.length > 2 ? parts.sublist(2).join('|') : '';
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SeismicAlertScreen(title: title, body: body),
      ));
    }
    return;
  }

  final parts = payload.split(':');
  if (parts.length != 2) return;
  final kind = parts[0];
  final id = parts[1];

  final container = ProviderScope.containerOf(context, listen: false);
  final user = container.read(authProvider);

  if (kind == 'task') {
    final task = await TaskRepository.instance.getTaskById(id);
    if (task != null && context.mounted) {
      context.push(AppRoutes.taskView, extra: {
        'task': task,
        'isAdmin': user?.isAdmin ?? false,
      });
    }
  } else if (kind == 'event') {
    final event = await EventRepository.instance.getEventById(id);
    if (event != null && context.mounted) {
      context.push(AppRoutes.eventView, extra: {
        'event': event,
        'isAdmin': user?.isAdmin ?? false,
      });
    }
  } else if (kind == 'family') {
    // id acá es en realidad el 'type' (teacher_access_revoked, etc.)
    // — solo los tipos de adulto tienen a dónde navegar.
    if (id.endsWith('_student')) return;
    if (context.mounted) context.push(AppRoutes.family);
  }
}

// ─────────────────────────────────────────────────────────────
// MAIN
// ─────────────────────────────────────────────────────────────
Future<void> main() async {
  // Asegurar que Flutter esté listo antes de usar plugins nativos
  WidgetsFlutterBinding.ensureInitialized();

  // Habilita re-muestreo de gestos para pantallas de 90/120 Hz
  GestureBinding.instance.resamplingEnabled = true;

  // ── Manejador global de errores de Flutter ─────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[EduTrack] Error de Flutter: ${details.exception}');
  };

  // ── Manejador de errores asíncronos no capturados ──────────
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[EduTrack] Error no capturado: $error\n$stack');
    return true; // Marcado como manejado, la app no crashea
  };

  // ── Orientación: libre (v2 responsiva: teléfono, tablet, desktop)
  // Los layouts se adaptan por breakpoints (core/responsive/).

  // ── SQLite en Windows/Linux ─────────────────────────────────
  // sqflite (el paquete normal) solo tiene canal de plataforma en
  // Android/iOS. Sin esto, cualquier openDatabase() en escritorio
  // revienta con "Bad state: databaseFactory not initialized".
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Tamaño mínimo de ventana (Windows/Linux) ───────────────
  // Sin esto la ventana se puede encoger hasta romper el layout;
  // 1000x700 la mantiene firmemente en el rango "medium" de
  // core/responsive/breakpoints.dart (600-1023) en vez de caer
  // al layout "compact" (pensado para teléfono).
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(minimumSize: Size(1000, 700)),
      () async {
        await windowManager.setMinimumSize(const Size(1000, 700));
        await windowManager.show();
      },
    );
  }

  // ── Color de la barra de estado del sistema ────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F2744),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Inicializar Firebase ───────────────────────────────────
  // Si Firebase no está configurado todavía, envuelve en try/catch
  // para que la app no crashee en desarrollo
  await _initFirebase();

  // ── Inicializar Zonas Horarias ─────────────────────────────
  // Necesario para programar notificaciones con hora correcta (Panamá UTC-5)
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Panama'));

  // ── Inicializar Notificaciones Locales ────────────────────────
  await _initNotifications();

  // ── ¿La app arrancó porque tocaron una notificación? ───────
  // Cubre el caso de la alerta sísmica con fullScreenIntent: si
  // Android lanzó la app sola (o el usuario la tocó) estando
  // completamente cerrada, acá no existe rootNavigatorKey todavía —
  // se guarda para que _EduTrackAppState la consuma en cuanto el
  // árbol de widgets esté montado.
  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp ?? false) {
    pendingLaunchNotificationPayload =
        launchDetails?.notificationResponse?.payload;
  }

  // ── Cargar SharedPreferences ──────────────────────────────
  // Lo inicializamos aquí para pasarlo al ProviderScope
  final sharedPreferences = await SharedPreferences.getInstance();

  // ── Ejecutar la App ───────────────────────────────────────
  runApp(
    ProviderScope(
      // Inyectar SharedPreferences al árbol de providers de Riverpod
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const EduTrackApp(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// INICIALIZACIÓN DE FIREBASE
// firebase_core/auth/firestore no tienen implementación nativa en
// Windows/Linux — ahí no se llama Firebase.initializeApp() en
// absoluto; Auth/Firestore/Storage resuelven a implementaciones
// REST (ver core/firebase/rest/ y core/firebase/platform/
// firebase_backend.dart), que no necesitan el SDK nativo inicializado.
// ─────────────────────────────────────────────────────────────
Future<void> _initFirebase() async {
  if (useDesktopRestBackend) {
    debugPrint('[EduTrack] Windows/Linux: usando backend REST (sin SDK nativo) ✓');
    return;
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Auth anónima para que las reglas de Firestore permitan acceso
    // sin exponer la DB a cualquier usuario externo (if true).
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    // Solo Android/iOS: firebase_messaging no tiene implementación en
    // Windows/Linux (por eso el guard useDesktopRestBackend arriba ya
    // corta antes de llegar aquí en desktop, pero se deja explícito).
    if (Platform.isAndroid || Platform.isIOS) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);
    }
    debugPrint('[EduTrack] Firebase inicializado correctamente ✓');
  } catch (e) {
    debugPrint('[EduTrack] Firebase no disponible: $e');
  }
}

// ─────────────────────────────────────────────────────────────
// INICIALIZACIÓN DE NOTIFICACIONES LOCALES
// ─────────────────────────────────────────────────────────────
Future<void> _initNotifications() async {
  // Configuración para Android
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  // Configuración para iOS
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    requestCriticalPermission: false, // requiere entitlement especial de Apple
  );

  // Configuración para Windows (solo se usa en desarrollo de escritorio;
  // la app no soporta oficialmente Windows, ver CLAUDE.md)
  final WindowsInitializationSettings? windowsSettings =
      (!kIsWeb && Platform.isWindows)
          ? const WindowsInitializationSettings(
              appName: 'EduTrack Family',
              appUserModelId: 'com.edutrack.family.EduTrackFamily',
              guid: '3f9e6d9a-6b1a-4b1e-9a2b-8f2e1c9d4a2f',
            )
          : null;

  final InitializationSettings initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
    windows: windowsSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    // Callback cuando el usuario toca una notificación con app en primer plano
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('[EduTrack] Notificación tocada: ${response.payload}');
      _handleLocalNotificationTap(response.payload);
    },
    // Callback para notificaciones tocadas en background
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );

  // Solicitar permisos en Android 13+ (API 33)
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
    await androidPlugin.requestExactAlarmsPermission();
  }

  await NotificationUtils.recreateChannels();

  debugPrint('[EduTrack] Notificaciones locales inicializadas ✓');
}

