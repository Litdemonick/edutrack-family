import 'dart:io' show Platform;
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/utils/notification_utils.dart';
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

// ─────────────────────────────────────────────────────────────
// HANDLER DE NOTIFICACIONES EN BACKGROUND
// flutter_local_notifications: cuando la app está cerrada
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint(
    '[EduTrack] Notificación en background: ${notificationResponse.payload}',
  );
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

  // ── Orientación: solo portrait (vertical) ──────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
// ─────────────────────────────────────────────────────────────
Future<void> _initFirebase() async {
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
    debugPrint('[EduTrack] Firebase inicializado correctamente ✓');
  } catch (e) {
    debugPrint('[EduTrack] Firebase no disponible, modo offline: $e');
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

