import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════
// RINGTONE SERVICE — EduTrack Family
// Wrapper de MethodChannel para el selector de tonos del sistema,
// previsualización de sonido y vibración nativa (Android).
// ═══════════════════════════════════════════════════════════════

class RingtoneService {
  RingtoneService._();
  static final RingtoneService instance = RingtoneService._();

  static const _chRingtone = MethodChannel('com.edutrack/ringtone');
  static const _chVibrate  = MethodChannel('com.edutrack/vibrate');
  static const _chAlarm    = MethodChannel('com.edutrack/alarm');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ─────────────────────────────────────────────────────────────
  // SELECTOR DE TONO DEL SISTEMA
  // Devuelve {uri, name} o null si el usuario canceló.
  // ─────────────────────────────────────────────────────────────

  Future<({String? uri, String name})?> pickRingtone({String? currentUri}) async {
    if (!_isAndroid) return null;
    try {
      final raw = await _chRingtone.invokeMethod<Map<Object?, Object?>>(
        'pick',
        {'currentUri': currentUri},
      );
      if (raw == null) return null;
      return (
        uri: raw['uri'] as String?,
        name: (raw['name'] as String?) ?? 'Predeterminado',
      );
    } on PlatformException catch (e) {
      debugPrint('[RingtoneService] pick error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PREVISUALIZACIÓN DE SONIDO
  // ─────────────────────────────────────────────────────────────

  Future<void> play({String? uri}) async {
    if (!_isAndroid) return;
    try {
      await _chRingtone.invokeMethod<void>('play', {'uri': uri});
    } on PlatformException catch (e) {
      debugPrint('[RingtoneService] play error: $e');
    }
  }

  Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _chRingtone.invokeMethod<void>('stop');
    } on PlatformException {
      // ignore
    }
  }

  // ─────────────────────────────────────────────────────────────
  // NOMBRE DEL TONO
  // ─────────────────────────────────────────────────────────────

  Future<String> getName({String? uri}) async {
    if (!_isAndroid) return 'Predeterminado';
    try {
      final name = await _chRingtone.invokeMethod<String>('getName', {'uri': uri});
      return name ?? 'Predeterminado';
    } on PlatformException {
      return 'Predeterminado';
    }
  }

  // ─────────────────────────────────────────────────────────────
  // VIBRACIÓN NATIVA (patrón: dos pulsos)
  // ─────────────────────────────────────────────────────────────

  // pattern: 'short' | 'medium' | 'long'
  Future<void> vibrate({String pattern = 'medium'}) async {
    if (!_isAndroid) return;
    try {
      await _chVibrate.invokeMethod<void>('vibrate', {'pattern': pattern});
    } on PlatformException catch (e) {
      debugPrint('[RingtoneService] vibrate error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ALARMA EN BUCLE — check-in "¿Estás bien?"
  // A diferencia de play() (suena una sola vez, para previsualizar
  // el tono elegido), esto repite el sonido de alarma sin parar
  // hasta llamar a stopAlarmLoop() — usa el mismo canal de volumen
  // que un despertador (suena aunque el celular esté en silencio).
  // ─────────────────────────────────────────────────────────────

  // sound: nombre del raw resource sin extensión — 'alert_sound'
  // (check-in "¿Estás bien?", default) o 'alerta_sismica' (sismo,
  // sonido propio distinto para no confundir ambas alertas).
  Future<void> startAlarmLoop({String sound = 'alert_sound'}) async {
    if (!_isAndroid) return;
    try {
      await _chAlarm.invokeMethod<void>('loop', {'sound': sound});
    } on PlatformException catch (e) {
      debugPrint('[RingtoneService] startAlarmLoop error: $e');
    }
  }

  Future<void> stopAlarmLoop() async {
    if (!_isAndroid) return;
    try {
      await _chAlarm.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('[RingtoneService] stopAlarmLoop error: $e');
    }
  }
}
