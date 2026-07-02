import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════
// PUSH QUEUE SERVICE — EduTrack Family
// Encola notificaciones push en Firestore (`push_queue`).
// La Cloud Function `sendQueuedPush` las entrega vía FCM a los
// dispositivos registrados. Sin claves de API en el cliente.
//
// Transición 2.0: hoy enruta por rol (targetRole); cuando exista
// el registro de dispositivos por usuario pasará a targetUids.
// ═══════════════════════════════════════════════════════════════

class PushQueueService {
  PushQueueService._();
  static final PushQueueService instance = PushQueueService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Encola una push para todos los dispositivos del rol destino.
  Future<void> sendToRole(
    String targetRole, {
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _db.collection('push_queue').add({
        'targetRole': targetRole,
        'title': title,
        'body': body,
        'payload': payload ?? '',
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[PushQueue] Encolada push a rol $targetRole — $title');
    } catch (e) {
      debugPrint('[PushQueue] Error encolando push: $e');
    }
  }

  /// Encola una push dirigida a usuarios concretos (EduTrack 2.0).
  Future<void> sendToUids(
    List<String> targetUids, {
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    if (targetUids.isEmpty) return;
    try {
      await _db.collection('push_queue').add({
        'targetUids': targetUids,
        'title': title,
        'body': body,
        'data': data ?? const <String, String>{},
        'processed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[PushQueue] Encolada push a ${targetUids.length} usuario(s)');
    } catch (e) {
      debugPrint('[PushQueue] Error encolando push: $e');
    }
  }
}
