import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../firebase/firestore_paths.dart';
import 'api_client.dart';

// ═══════════════════════════════════════════════════════════════
// FCM SERVICE — EduTrack Family 2.0
// Registra el token del dispositivo en users/{uid}/devices/{installId}
// para que la Cloud Function sendQueuedPush entregue push por uid.
// Las push con bloque `notification` llegan aunque la app esté
// cerrada/matada (las muestra el sistema Android).
// Solo Android/iOS — no-op en desktop/web.
// ═══════════════════════════════════════════════════════════════

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _kInstallId = 'fcm_install_id';

  StreamSubscription<String>? _tokenSub;
  String? _registeredUid;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Id estable de esta instalación (persiste en prefs).
  Future<String> _installId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kInstallId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kInstallId, id);
    }
    return id;
  }

  /// Llamar al iniciar sesión: pide permiso, registra token y
  /// escucha rotaciones de token.
  Future<void> registerDevice(String uid) async {
    if (!_isMobile) return;
    try {
      _registeredUid = uid;
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _saveToken(uid, token);

      _tokenSub?.cancel();
      _tokenSub = messaging.onTokenRefresh.listen((newToken) {
        final currentUid = _registeredUid;
        if (currentUid != null) _saveToken(currentUid, newToken);
      });

      debugPrint('[FCM] Dispositivo registrado para $uid');
    } catch (e) {
      debugPrint('[FCM] registerDevice: $e');
    }
  }

  /// Pasa por el Worker (no escribe directo por SDK) porque reclamar
  /// esta instalación para [uid] puede requerir borrar el registro de
  /// OTRO uid que la tenía antes (mismo dispositivo, cuenta distinta
  /// — ver /register-device) — las reglas de Firestore no dejan que
  /// un usuario borre el documento de otro, solo el Worker con el
  /// service account puede.
  Future<void> _saveToken(String uid, String token) async {
    final installId = await _installId();
    try {
      await ApiClient.instance.call('/register-device', {
        'installId': installId,
        'token': token,
        'platform': defaultTargetPlatform.name,
      });
    } catch (e) {
      debugPrint('[FCM] register-device falló: $e');
    }
  }

  /// Llamar al cerrar sesión: elimina el registro del dispositivo.
  Future<void> unregisterDevice() async {
    if (!_isMobile) return;
    final uid = _registeredUid;
    _registeredUid = null;
    _tokenSub?.cancel();
    _tokenSub = null;
    if (uid == null) return;
    try {
      final installId = await _installId();
      await FirebaseFirestore.instance
          .doc(FirestorePaths.userDevice(uid, installId))
          .delete();
      await FirebaseMessaging.instance.deleteToken();
      debugPrint('[FCM] Dispositivo des-registrado');
    } catch (e) {
      debugPrint('[FCM] unregisterDevice: $e');
    }
  }

  /// Mensajes con la app en primer plano (el sistema no los muestra):
  /// el llamador decide si mostrar una notificación local.
  Stream<RemoteMessage> get onForegroundMessage =>
      FirebaseMessaging.onMessage;

  /// El usuario tocó una notificación (app en background → abierta).
  Stream<RemoteMessage> get onNotificationTap =>
      FirebaseMessaging.onMessageOpenedApp;

  /// Notificación que abrió la app desde cero (estado terminated).
  Future<RemoteMessage?> get initialMessage =>
      FirebaseMessaging.instance.getInitialMessage();
}
