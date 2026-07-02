import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app_strings.dart';
import 'date_utils.dart';
import '../../data/local/models/notification_model.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION UTILS — EduTrack Family
// Gestiona todas las notificaciones locales:
// - Alarmas de vencimiento de tareas
// - Recordatorios anticipados
// - Alertas de tareas no completadas
// - Vibración + sonido personalizado
//
// Usa el plugin inicializado en main.dart (flutterLocalNotificationsPlugin)
// ═══════════════════════════════════════════════════════════════

// Referencia al plugin global definido en main.dart
// Se importa donde se use este servicio
// ignore: library_prefixes
import '../../../main.dart' as app show flutterLocalNotificationsPlugin;

class NotificationUtils {
  NotificationUtils._();

  // ─────────────────────────────────────────────────────────────
  // IDs DE CANALES DE NOTIFICACIÓN (Android)
  // Cada canal tiene su propia configuración de sonido/vibración
  // ─────────────────────────────────────────────────────────────

  /// Canal principal — tareas próximas a vencer (prioridad alta)
  static const String channelTaskDueId = 'edutrack_task_due';
  static const String channelTaskDueName = 'Tareas por vencer';
  static const String channelTaskDueDesc =
      'Alertas de tareas próximas a vencer';

  /// Canal urgente — tarea vence hoy o ya venció (prioridad máxima)
  static const String channelUrgentId = 'edutrack_urgent';
  static const String channelUrgentName = 'Alertas urgentes';
  static const String channelUrgentDesc =
      'Tareas que vencen hoy o ya vencieron';

  /// Canal de recordatorio — tareas no completadas (prioridad alta)
  static const String channelReminderIdStr = 'edutrack_reminder';
  static const String channelReminderName = 'Recordatorios';
  static const String channelReminderDesc =
      'Recordatorios de tareas pendientes';

  static const String channelEventId = 'edutrack_event';
  static const String channelEventName = 'Eventos del calendario';
  static const String channelEventDesc =
      'Recordatorios y alertas de eventos escolares';

  static const String channelSystemId = 'edutrack_system';
  static const String channelSystemName = 'Sistema EduTrack';
  static const String channelSystemDesc =
      'Avisos de acciones dentro de EduTrack';

  // ─────────────────────────────────────────────────────────────
  // RANGOS DE IDs DE NOTIFICACIÓN
  // Cada tipo usa un rango distinto para no colisionar
  // ─────────────────────────────────────────────────────────────

  /// Base de IDs para alertas de vencimiento (taskId hash + 0)
  static const int _idBaseDue = 1000;

  /// Base de IDs para recordatorios anticipados (taskId hash + 1000)
  static const int _idBaseReminder = 2000;

  /// Base de IDs para alertas urgentes de admin (taskId hash + 3000)
  static const int _idBaseAdmin = 3000;

  // ─────────────────────────────────────────────────────────────
  // PROGRAMAR NOTIFICACIÓN DE VENCIMIENTO DE TAREA
  // Llama esto cuando el admin crea o edita una tarea
  // ─────────────────────────────────────────────────────────────

  /// Programa todas las notificaciones para una tarea según su categoría.
  /// [taskId] ID único de la tarea (UUID)
  /// [taskTitle] Nombre de la tarea
  /// [dueDate] Fecha de entrega
  /// [category] Categoría (tarea, examen, parcial, etc.)
  static Future<void> scheduleTaskNotifications({
    required String taskId,
    required String taskTitle,
    required DateTime dueDate,
    required String category,
  }) async {
    await cancelTaskNotifications(taskId);

    final notifDates = EduDateUtils.notificationScheduleFor(dueDate, category);
    final sound = await _soundEnabled();
    final vibration = await _vibrationEnabled();
    final vibNormal = await _vibrationNormalFromPrefs();

    for (int i = 0; i < notifDates.length; i++) {
      final notifDate = notifDates[i];
      final daysLeft = EduDateUtils.daysUntil(dueDate);
      final isUrgent = daysLeft <= 0;
      final notifId = _taskNotifId(taskId, i);

      final title =
          isUrgent ? AppStrings.notifTaskOverdue : AppStrings.notifTaskDue;

      final body = AppStrings.notifTaskDueBody(
        taskTitle,
        EduDateUtils.daysUntil(dueDate),
      );

      await _scheduleNotification(
        id: notifId,
        title: title,
        body: body,
        scheduledDate: notifDate,
        channelId: isUrgent ? channelUrgentId : channelTaskDueId,
        channelName: isUrgent ? channelUrgentName : channelTaskDueName,
        channelDesc: isUrgent ? channelUrgentDesc : channelTaskDueDesc,
        importance: isUrgent ? Importance.max : Importance.high,
        priority: isUrgent ? Priority.max : Priority.high,
        playSound: sound,
        enableVibration: vibration,
        vibrationPattern: isUrgent ? _vibrationUrgent : vibNormal,
        payload: 'task:$taskId',
        fullScreenIntent: isUrgent,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIÓN DE SISTEMA INMEDIATA — uso general (público)
  // Dispara una push inmediata sin programar. Úsalo para avisos
  // de tarea asignada, completada, rechazada, etc.
  // ─────────────────────────────────────────────────────────────

  /// Muestra una notificación del sistema inmediatamente.
  /// [isUrgent] usa canal urgente (max priority + full screen intent).
  /// Notificación inmediata de sistema (aviso, corrección, nueva tarea, etc.).
  /// Según especificación: SOLO SONIDO, sin vibración.
  static Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    bool isUrgent = false,
    String? taskId,
    NotificationType? notifType,
  }) async {
    final id    = _deterministicId(taskId, eventId: null, notifType: notifType)
        ?? DateTime.now().millisecondsSinceEpoch % 90000 + 10000;
    final sound = await _soundEnabled();
    await _showImmediateNotification(
      id: id,
      title: title,
      body: body,
      channelId: isUrgent ? channelUrgentId : channelSystemId,
      channelName: isUrgent ? channelUrgentName : channelSystemName,
      channelDesc: isUrgent ? channelUrgentDesc : channelSystemDesc,
      importance: isUrgent ? Importance.max : Importance.high,
      priority: isUrgent ? Priority.max : Priority.high,
      playSound: sound,
      enableVibration: false,      // Solo sonido, sin vibración
      vibrationPattern: _patternForName('medium'),
      payload: payload,
      fullScreenIntent: isUrgent,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIÓN URGENTE — vencimiento o alerta crítica
  // Vibración fuerte, fullScreenIntent, ongoing si requireConfirm
  // ─────────────────────────────────────────────────────────────

  static Future<void> showUrgentNotification({
    required String title,
    required String body,
    bool requireConfirm = false,
    String? payload,
    String? taskId,
    NotificationType? notifType,
  }) async {
    final id = _deterministicId(taskId, eventId: null, notifType: notifType)
        ?? DateTime.now().millisecondsSinceEpoch % 90000 + 10000;
    final sound = await _soundEnabled();

    await _showImmediateNotification(
      id: id,
      title: title,
      body: body,
      channelId: channelUrgentId,
      channelName: channelUrgentName,
      channelDesc: channelUrgentDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound,
      enableVibration: true,
      vibrationPattern: _vibrationUrgent,
      payload: payload,
      ongoing: requireConfirm,
      autoCancel: !requireConfirm,
      fullScreenIntent: true,
    );
  }

  static Future<void> showEventNotification({
    required String title,
    required String body,
    bool requireConfirm = false,
    String? payload,
    String? taskId,
    String? eventId,
    NotificationType? notifType,
  }) async {
    final id = _deterministicId(taskId, eventId: eventId, notifType: notifType)
        ?? DateTime.now().millisecondsSinceEpoch % 90000 + 10000;
    final sound = await _soundEnabled();
    final vibration = await _vibrationEnabled();
    final vibNormal = await _vibrationNormalFromPrefs();

    await _showImmediateNotification(
      id: id,
      title: title,
      body: body,
      channelId: channelEventId,
      channelName: channelEventName,
      channelDesc: channelEventDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound,
      enableVibration: vibration,
      vibrationPattern: vibNormal,
      payload: payload,
      ongoing: requireConfirm,
      autoCancel: !requireConfirm,
      fullScreenIntent: requireConfirm,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIÓN DE ACCIÓN — crear/editar/eliminar (solo sonido)
  // ─────────────────────────────────────────────────────────────

  static Future<void> showActionNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showSystemNotification(
      title: title,
      body: body,
      isUrgent: false,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PROGRAMAR RECORDATORIO DE EVENTO
  // ─────────────────────────────────────────────────────────────

  static Future<void> scheduleEventReminder({
    required String eventId,
    required String eventTitle,
    required DateTime eventDate,
    required int minutesBefore,
  }) async {
    // Cancelar recordatorio anterior si existía
    await cancelById(_eventReminderId(eventId));

    final reminderDate = eventDate.subtract(Duration(minutes: minutesBefore));
    if (reminderDate.isBefore(DateTime.now())) return; // ya pasó

    final sound = await _soundEnabled();
    final vibration = await _vibrationEnabled();
    final vibNormal = await _vibrationNormalFromPrefs();

    final body = minutesBefore < 60
        ? '"$eventTitle" comienza en $minutesBefore minutos'
        : minutesBefore == 60
            ? '"$eventTitle" comienza en 1 hora'
            : '"$eventTitle" comienza mañana';

    await _scheduleNotification(
      id: _eventReminderId(eventId),
      title: '🔔 Recordatorio de evento',
      body: body,
      scheduledDate: reminderDate,
      channelId: channelEventId,
      channelName: channelEventName,
      channelDesc: channelEventDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound,
      enableVibration: vibration,
      vibrationPattern: vibNormal,
      payload: 'event:$eventId',
      fullScreenIntent: true,
    );
  }

  /// Cancela el recordatorio de un evento
  static Future<void> cancelEventReminder(String eventId) async {
    await cancelById(_eventReminderId(eventId));
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIÓN INMEDIATA — admin alerta que Yordan no hizo tarea
  // Se dispara cuando el admin ve que Yordan no completó una tarea
  // que está próxima a vencer
  // ─────────────────────────────────────────────────────────────

  /// Muestra inmediatamente una notificación al admin/Yordan
  /// indicando que la tarea no está completada.
  static Future<void> showTaskNotDoneAlert({
    required String taskId,
    required String taskTitle,
  }) async {
    final notifId = _adminNotifId(taskId);
    final sound = await _soundEnabled();
    final vibration = await _vibrationEnabled();

    await _showImmediateNotification(
      id: notifId,
      title: AppStrings.notifTaskNotDone,
      body: AppStrings.notifTaskNotDoneBody(taskTitle),
      channelId: channelUrgentId,
      channelName: channelUrgentName,
      channelDesc: channelUrgentDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: sound,
      enableVibration: vibration,
      vibrationPattern: _vibrationUrgent,
      payload: 'task_alert:$taskId',
      ongoing: false,
      autoCancel: true,
      fullScreenIntent: true,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIÓN DE RECORDATORIO GENERAL
  // ─────────────────────────────────────────────────────────────

  /// Programa un recordatorio personalizado.
  /// [id] ID único de la notificación
  /// [title] Título
  /// [body] Cuerpo del mensaje
  /// [scheduledDate] Cuándo mostrarla
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final sound = await _soundEnabled();
    final vibration = await _vibrationEnabled();
    final vibNormal = await _vibrationNormalFromPrefs();
    await _scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: channelReminderIdStr,
      channelName: channelReminderName,
      channelDesc: channelReminderDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
      vibrationPattern: vibNormal,
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // RECREAR CANALES ANDROID (sonido / vibración / tono)
  // Necesario en Android 8+ porque el canal controla el sonido;
  // hay que eliminarlo y recrearlo para aplicar cambios.
  // ─────────────────────────────────────────────────────────────

  static Future<void> recreateChannels({
    String? soundUri,
    bool playSound = true,
    bool enableVibration = true,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final plugin = app.flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    // Determina el sonido del canal:
    // - playSound=false       → null = canal silencioso
    // - soundUri personalizado → UriAndroidNotificationSound
    // - sin URI               → null = sonido del sistema por defecto
    AndroidNotificationSound? sound;
    if (playSound) {
      sound = soundUri == null
          ? null
          : UriAndroidNotificationSound(soundUri);
    }

    final vibNormal = enableVibration ? await _vibrationNormalFromPrefs() : null;
    final vibUrgent = enableVibration ? _vibrationUrgent : null;

    // Elimina los canales existentes para poder cambiar el sonido
    for (final id in [
      channelTaskDueId,
      channelUrgentId,
      channelReminderIdStr,
      channelEventId,
      channelSystemId,
    ]) {
      await plugin.deleteNotificationChannel(channelId: id);
    }

    await plugin.createNotificationChannel(AndroidNotificationChannel(
      channelTaskDueId, channelTaskDueName,
      description: channelTaskDueDesc,
      importance: Importance.high,
      sound: sound,
      enableVibration: enableVibration,
      vibrationPattern: vibNormal,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
    ));

    await plugin.createNotificationChannel(AndroidNotificationChannel(
      channelUrgentId, channelUrgentName,
      description: channelUrgentDesc,
      importance: Importance.max,
      sound: sound,
      enableVibration: enableVibration,
      vibrationPattern: vibUrgent,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFFF44336),
    ));

    await plugin.createNotificationChannel(AndroidNotificationChannel(
      channelReminderIdStr, channelReminderName,
      description: channelReminderDesc,
      importance: Importance.high,
      sound: sound,
      enableVibration: enableVibration,
      vibrationPattern: vibNormal,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
    ));

    await plugin.createNotificationChannel(AndroidNotificationChannel(
      channelEventId, channelEventName,
      description: channelEventDesc,
      importance: Importance.max,
      sound: sound,
      enableVibration: enableVibration,
      vibrationPattern: vibNormal,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFF9C27B0),
    ));

    await plugin.createNotificationChannel(AndroidNotificationChannel(
      channelSystemId, channelSystemName,
      description: channelSystemDesc,
      importance: Importance.high,
      sound: sound,
      enableVibration: false,
      showBadge: true,
      enableLights: true,
      ledColor: const Color(0xFF2196F3),
    ));
  }

  // ─────────────────────────────────────────────────────────────
  // CANCELAR NOTIFICACIONES
  // ─────────────────────────────────────────────────────────────

  /// Cancela todas las notificaciones programadas de una tarea.
  /// Llama esto cuando la tarea se completa o se elimina.
  static Future<void> cancelTaskNotifications(String taskId) async {
    // Cancelar hasta 5 notificaciones por tarea (3 anticipadas + 2 extra)
    for (int i = 0; i < 5; i++) {
      await app.flutterLocalNotificationsPlugin.cancel(id: _taskNotifId(taskId, i));
    }
    // Cancelar también la alerta de admin
    await app.flutterLocalNotificationsPlugin.cancel(id: _adminNotifId(taskId));
  }

  /// Cancela una notificación por su ID.
  static Future<void> cancelById(int id) async {
    await app.flutterLocalNotificationsPlugin.cancel(id: id);
  }

  /// Cancela TODAS las notificaciones programadas.
  /// Úsalo con cuidado — solo al cerrar sesión o limpiar todo.
  static Future<void> cancelAll() async {
    await app.flutterLocalNotificationsPlugin.cancelAll();
  }

  /// Cancela las notificaciones del sistema mostradas en la bandeja (IDs 5000–5999).
  /// No afecta recordatorios programados de tareas ni eventos.
  static Future<void> cancelSystemNotifications() async {
    for (int id = 5000; id < 6000; id++) {
      await app.flutterLocalNotificationsPlugin.cancel(id: id);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CONSULTAR NOTIFICACIONES PENDIENTES
  // ─────────────────────────────────────────────────────────────

  /// Retorna la lista de notificaciones pendientes (programadas).
  static Future<List<PendingNotificationRequest>> getPending() async {
    return await app.flutterLocalNotificationsPlugin
        .pendingNotificationRequests();
  }

  /// Retorna true si hay notificaciones pendientes para [taskId].
  static Future<bool> hasPendingForTask(String taskId) async {
    final pending = await getPending();
    return pending.any((n) => n.payload != null && n.payload!.contains(taskId));
  }

  // ─────────────────────────────────────────────────────────────
  // IMPLEMENTACIONES PRIVADAS
  // ─────────────────────────────────────────────────────────────

  /// Programa una notificación para una fecha/hora específica.
  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
    required bool playSound,
    required bool enableVibration,
    required Int64List vibrationPattern,
    String? payload,
    bool fullScreenIntent = false,
  }) async {
    // Convertir DateTime local a TZDateTime con zona América/Panamá
    final tz.TZDateTime tzScheduled = tz.TZDateTime.from(
      scheduledDate,
      tz.getLocation('America/Panama'),
    );

    // Si la fecha ya pasó, no programar
    if (tzScheduled.isBefore(tz.TZDateTime.now(tz.local))) return;

    final AndroidNotificationDetails
    androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: importance,
      priority: priority,
      playSound: playSound,
      enableVibration: enableVibration,
      vibrationPattern: vibrationPattern,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFF0F2744), // navyBlue
      enableLights: true,
      ledColor: const Color(0xFF2196F3), // accentBlue
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: BigTextStyleInformation(body),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      fullScreenIntent: fullScreenIntent,
      sound: null,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await app.flutterLocalNotificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzScheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  /// Muestra una notificación inmediatamente (sin programar).
  static Future<void> _showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDesc,
    required Importance importance,
    required Priority priority,
    required bool playSound,
    required bool enableVibration,
    required Int64List vibrationPattern,
    String? payload,
    bool ongoing = false,
    bool autoCancel = true,
    bool fullScreenIntent = false,
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: importance,
          priority: priority,
          playSound: playSound,
          enableVibration: enableVibration,
          vibrationPattern: vibrationPattern,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF0F2744),
          enableLights: true,
          ledColor: const Color(0xFFF44336), // rojo para urgente
          ledOnMs: 500,
          ledOffMs: 200,
          styleInformation: BigTextStyleInformation(body),
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          fullScreenIntent: fullScreenIntent,
          ongoing: ongoing,
          autoCancel: autoCancel,
          sound: null,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.critical,
    );

    await app.flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // PATRONES DE VIBRACIÓN
  // Int64List: [espera_ms, vibra_ms, espera_ms, vibra_ms, ...]
  // ─────────────────────────────────────────────────────────────

  static const _keyVibrationPattern = 'notif_vibration_pattern';

  static Int64List _patternForName(String name) {
    switch (name) {
      case 'short': return Int64List.fromList([0, 150, 100, 150]);
      case 'long':  return Int64List.fromList([0, 600, 200, 600, 150, 600]);
      default:      return Int64List.fromList([0, 300, 150, 300]); // medium
    }
  }

  static Future<Int64List> _vibrationNormalFromPrefs() async {
    final p = await SharedPreferences.getInstance();
    return _patternForName(p.getString(_keyVibrationPattern) ?? 'medium');
  }

  /// Vibración urgente: siempre fuerte (3 pulsos largos), fija
  static final Int64List _vibrationUrgent = Int64List.fromList([
    0, 500, 200, 500, 200, 500,
  ]);

  // ─────────────────────────────────────────────────────────────
  // PREFERENCIAS DE SONIDO / VIBRACIÓN
  // ─────────────────────────────────────────────────────────────

  static const _keySound = 'notif_sound';
  static const _keyVibration = 'notif_vibration';

  static Future<bool> _soundEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keySound) ?? true;
  }

  static Future<bool> _vibrationEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keyVibration) ?? true;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE ID
  // ─────────────────────────────────────────────────────────────

  /// Genera un ID determinístico para notificaciones del sistema.
  /// Mismo [taskId] + mismo [notifType] → mismo ID → flutter_local_notifications
  /// reemplaza en vez de duplicar. Retorna null si no hay identificador útil.
  static int? _deterministicId(String? taskId, {String? eventId, NotificationType? notifType}) {
    final key = taskId ?? eventId;
    if (key == null) return null;
    return 5000 + (key.hashCode.abs() % 900) + (notifType?.index ?? 0);
  }

  /// Genera un ID de notificación único para una tarea y un índice.
  static int _taskNotifId(String taskId, int index) {
    return _idBaseDue + (taskId.hashCode.abs() % 800) + index;
  }

  /// Genera un ID de notificación de alerta admin para una tarea.
  static int _adminNotifId(String taskId) {
    return _idBaseAdmin + (taskId.hashCode.abs() % 800);
  }

  /// Genera un ID de recordatorio de evento.
  static int _eventReminderId(String eventId) {
    return 4000 + (eventId.hashCode.abs() % 800);
  }

  /// Genera un ID de recordatorio para una tarea.
  static int reminderIdForTask(String taskId) {
    return _idBaseReminder + (taskId.hashCode.abs() % 800);
  }
}
