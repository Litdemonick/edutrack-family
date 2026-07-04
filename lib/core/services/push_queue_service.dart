import 'package:flutter/foundation.dart';

import 'api_client.dart';

// ═══════════════════════════════════════════════════════════════
// PUSH QUEUE SERVICE — EduTrack Family 2.0
// Envía push llamando directo al backend (Cloudflare Worker,
// ruta /send-push), que hace el fan-out por FCM HTTP v1.
//
// Antes escribía un doc en Firestore (push_queue) y una Cloud
// Function lo recogía; ahora la llamada es directa y síncrona.
// ═══════════════════════════════════════════════════════════════

class PushQueueService {
  PushQueueService._();
  static final PushQueueService instance = PushQueueService._();

  /// Envía una push a los dispositivos de usuarios concretos.
  Future<void> sendToUids(
    List<String> targetUids, {
    required String title,
    required String body,
    Map<String, String>? data,
    String? channelId,
  }) async {
    if (targetUids.isEmpty) return;
    try {
      await ApiClient.instance.call('/send-push', {
        'targetUids': targetUids,
        'title': title,
        'body': body,
        'data': data ?? const <String, String>{},
        if (channelId != null) 'channelId': channelId,
      });
      debugPrint('[PushQueue] Push enviada a ${targetUids.length} usuario(s)');
    } catch (e) {
      debugPrint('[PushQueue] Error enviando push: $e');
    }
  }
}
