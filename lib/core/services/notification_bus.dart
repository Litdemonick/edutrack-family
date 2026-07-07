import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/models/notification_model.dart';
import '../data/local/repositories/student_repository.dart';
import '../providers/notification_provider.dart';
import '../constants/utils/notification_utils.dart';
import '../services/app_lifecycle_service.dart';
import '../services/push_queue_service.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION BUS — EduTrack Family
// Helper centralizado que dispara SIEMPRE dos capas a la vez:
//   1️⃣ Notificación interna (campana 🔔 dentro de la app)
//   2️⃣ Notificación del sistema (push local + FCM si app cerrada)
//
// Regla de oro: nunca llames solo una capa. Usa siempre este Bus.
// ═══════════════════════════════════════════════════════════════

enum NotificationChannel {
  /// Acciones normales: crear, editar, eliminar (sin vibración)
  system,

  /// Vencimientos y eventos urgentes (vibración fuerte, fullScreenIntent)
  urgent,

  /// Recordatorios de eventos (vibración normal, fullScreenIntent)
  event,
}

class NotificationBus {
  NotificationBus._();

  /// uids de los adultos vinculados al estudiante (padres + profesores).
  /// Para notificar al propio estudiante usa `[studentId]` (uid == id).
  static Future<List<String>> guardianTargets(String studentId) async {
    if (studentId.isEmpty) return const [];
    final student = await StudentRepository.instance.getById(studentId);
    if (student == null) return const [];
    return [...student.parentIds, ...student.teacherIds];
  }

  /// Push (sin tocar la campana local de este dispositivo — eso ya lo
  /// hizo el dispatch/dispatchFromProvider normal, que cubre al
  /// estudiante + la campana propia del actor) a los adultos
  /// vinculados a [studentId] que NO sean [actorUid]. Avisa al OTRO
  /// adulto (padre si actuó el profesor, o viceversa) aunque tenga la
  /// app cerrada/en segundo plano — con la app abierta, el eco de
  /// Firestore en tiempo real (onTaskUpdated/onEventUpdated en
  /// app.dart) completa la campana/notificación local con el mismo
  /// mensaje.
  static Future<void> pushToOtherGuardians({
    required String studentId,
    required String actorUid,
    required String title,
    required String body,
    String? payload,
  }) async {
    final guardians = await guardianTargets(studentId);
    final others = guardians.where((uid) => uid != actorUid).toList();
    if (others.isEmpty) return;
    await PushQueueService.instance.sendToUids(
      others,
      title: title,
      body: body,
      data: payload != null ? {'payload': payload} : null,
    );
  }

  /// Dispara ambas capas simultáneamente:
  /// - Notificación interna (historial campana 🔔)
  /// - Push del sistema (local si app abierta, FCM si cerrada)
  ///
  /// [ref]           Riverpod ref para acceder a notificationProvider
  /// [title]         Título de la notificación
  /// [body]          Cuerpo del mensaje
  /// [internalType]  Tipo para el historial interno
  /// [channel]       Canal de sistema (determina vibración y prioridad)
  /// [requireConfirm] true = vibración continua hasta confirmar (ongoing)
  /// [taskId]        ID de tarea (para navegar al tocar)
  /// [eventId]       ID de evento (para navegar al tocar)
  /// [payload]       Payload para push del sistema ('task:id' | 'event:id')
  /// [targetUids]    FCM a usuarios concretos (uids; null = sin push remoto)
  /// [actorTitle]/[actorBody] texto alternativo SOLO para la campana +
  ///   notificación local de este mismo dispositivo (el actor) — si no
  ///   se pasan, se usa [title]/[body] igual que antes. Existe porque
  ///   [title]/[body] están redactados para el DESTINATARIO (ej. "tu
  ///   padre/tutor agregó..."), y ese mismo texto sonaba raro en la
  ///   propia campana de quien acaba de hacer la acción.
  /// Para usar en widgets (ConsumerWidget / ConsumerStatefulWidget)
  static Future<void> dispatch({
    required WidgetRef ref,
    required String title,
    required String body,
    required NotificationType internalType,
    NotificationChannel channel = NotificationChannel.system,
    bool requireConfirm = false,
    String? taskId,
    String? eventId,
    String? payload,
    List<String>? targetUids,
    String? actorTitle,
    String? actorBody,
  }) async {
    await _dispatch(
      read: ref.read,
      title: title,
      body: body,
      internalType: internalType,
      channel: channel,
      requireConfirm: requireConfirm,
      taskId: taskId,
      eventId: eventId,
      payload: payload,
      targetUids: targetUids,
      actorTitle: actorTitle,
      actorBody: actorBody,
    );
  }

  /// Para usar en StateNotifier / providers (usan Ref, no WidgetRef)
  static Future<void> dispatchFromProvider({
    required Ref ref,
    required String title,
    required String body,
    required NotificationType internalType,
    NotificationChannel channel = NotificationChannel.system,
    bool requireConfirm = false,
    String? taskId,
    String? eventId,
    String? payload,
    List<String>? targetUids,
    String? actorTitle,
    String? actorBody,
  }) async {
    await _dispatch(
      read: ref.read,
      title: title,
      body: body,
      internalType: internalType,
      channel: channel,
      requireConfirm: requireConfirm,
      taskId: taskId,
      eventId: eventId,
      payload: payload,
      targetUids: targetUids,
      actorTitle: actorTitle,
      actorBody: actorBody,
    );
  }

  // Implementación compartida
  static Future<void> _dispatch({
    required T Function<T>(ProviderListenable<T>) read,
    required String title,
    required String body,
    required NotificationType internalType,
    required NotificationChannel channel,
    required bool requireConfirm,
    String? taskId,
    String? eventId,
    String? payload,
    List<String>? targetUids,
    String? actorTitle,
    String? actorBody,
  }) async {
    // Texto para ESTE dispositivo (campana + notificación local si
    // está en foreground) — el push remoto (capa 3, más abajo) sigue
    // usando title/body tal cual, redactados para el destinatario.
    final localTitle = actorTitle ?? title;
    final localBody = actorBody ?? body;

    debugPrint('[Notif] _dispatch → campana: "$localTitle" / "$localBody" '
        '(taskId=$taskId eventId=$eventId targetUids=$targetUids)');

    // ── 1️⃣ Notificación interna (campana dentro de la app) ────
    read(notificationProvider.notifier).dispatchFull(
      title: localTitle,
      body: localBody,
      type: internalType,
      taskId: taskId,
      eventId: eventId,
    );

    // ── 2️⃣ Notificación del sistema (solo en foreground) ─────
    // Si la app está en background, FCM ya mostrará la notificación.
    // Si mostramos ambas, se duplican en la bandeja del teléfono.
    if (AppLifecycleService.instance.isInForeground) {
      if (channel == NotificationChannel.urgent) {
        await NotificationUtils.showUrgentNotification(
          title: localTitle,
          body: localBody,
          requireConfirm: requireConfirm,
          payload: payload,
          taskId: taskId,
          eventId: eventId,
          notifType: internalType,
        );
      } else if (channel == NotificationChannel.event) {
        await NotificationUtils.showEventNotification(
          title: localTitle,
          body: localBody,
          requireConfirm: requireConfirm,
          payload: payload,
          taskId: taskId,
          eventId: eventId,
          notifType: internalType,
        );
      } else {
        await NotificationUtils.showSystemNotification(
          title: localTitle,
          body: localBody,
          payload: payload,
          taskId: taskId,
          eventId: eventId,
          notifType: internalType,
        );
      }
    }

    // ── 3️⃣ FCM a los dispositivos de los usuarios destino ─────
    if (targetUids != null && targetUids.isNotEmpty) {
      await PushQueueService.instance.sendToUids(
        targetUids,
        title: title,
        body: body,
        data: payload != null ? {'payload': payload} : null,
      );
    }
  }
}
