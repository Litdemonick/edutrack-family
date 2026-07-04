import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/services/push_queue_service.dart';
import 'package:edutrack_family/features/location/data/location_models.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'package:edutrack_family/firebase_options.dart';

// ═══════════════════════════════════════════════════════════════
// TRACKING SERVICE — dispositivo del hijo (EduTrack Family 2.0)
// Servicio foreground Android con notificación persistente visible
// ("EduTrack está compartiendo tu ubicación 📍") — es a la vez el
// keep-alive técnico ante Doze y el indicador ético/legal.
//
// Cadencia adaptativa: tick cada 60 s; se escribe a Firestore si
// se movió ≥50 m o pasaron ≥5 min desde la última escritura.
// Geocercas: evaluación local (haversine + histéresis 15%).
// Offline: los puntos van al buffer SQLite y se suben al volver.
// ═══════════════════════════════════════════════════════════════

@pragma('vm:entry-point')
void trackingTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_isAndroid) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'edutrack_location',
        channelName: 'Compartir ubicación',
        channelDescription:
            'Indicador visible mientras compartes tu ubicación con tu familia',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // cada 60 s
        autoRunOnBoot: true, // reinicia tras reboot si estaba activo
        allowWakeLock: true,
      ),
    );
  }

  Future<bool> isRunning() async {
    if (!_isAndroid) return false;
    return FlutterForegroundTask.isRunningService;
  }

  /// Arranca el tracking. [studentId] = uid del niño.
  Future<bool> start(String studentId) async {
    if (!_isAndroid) return false;
    await init();

    // Persistir el studentId para el isolate del servicio
    await FlutterForegroundTask.saveData(
        key: 'tracking_student_id', value: studentId);

    final result = await FlutterForegroundTask.startService(
      serviceId: 2001,
      notificationTitle: 'EduTrack está compartiendo tu ubicación 📍',
      notificationText:
          'Tu familia puede ver dónde estás. Puedes apagarlo en la app.',
      callback: trackingTaskCallback,
    );
    return result is ServiceRequestSuccess;
  }

  Future<void> stop() async {
    if (!_isAndroid) return;
    await FlutterForegroundTask.stopService();
  }

  /// Cadena de permisos de ubicación del hijo.
  /// Devuelve null si todo OK, o el mensaje de lo que falta.
  Future<String?> ensurePermissions() async {
    if (!_isAndroid) return 'Disponible solo en Android';

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Activa el permiso de ubicación en Ajustes';
    }
    // Para tracking con app cerrada se necesita "Permitir siempre"
    if (permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.always) {
        return 'Elige "Permitir siempre" en Ajustes → Ubicación';
      }
    }

    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Enciende el GPS del teléfono';
    }

    // Exención de optimización de batería (Doze) para no morir
    final ignoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!ignoring) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Handler que corre en el isolate del servicio foreground
// ─────────────────────────────────────────────────────────────

class _TrackingTaskHandler extends TaskHandler {
  String? _studentId;
  LocationPoint? _lastWritten;
  final Map<String, bool> _insideZone = {};
  List<SafeZone> _zones = const [];
  DateTime _zonesLoadedAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const _minDistanceM = 50.0;
  static const _maxSilence = Duration(minutes: 5);
  static const _zoneRefresh = Duration(minutes: 10);

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // El isolate del servicio necesita su propio Firebase
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // ya inicializado
    }
    _studentId =
        await FlutterForegroundTask.getData<String>(key: 'tracking_student_id');
    debugPrint('[Tracking] Servicio iniciado para $_studentId');
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    final sid = _studentId;
    if (sid == null) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 30),
        ),
      );

      final point = LocationPoint(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracy: pos.accuracy,
        speed: pos.speed,
        ts: DateTime.now(),
      );

      // Cadencia adaptativa: escribir si se movió o pasó mucho tiempo
      final last = _lastWritten;
      final moved = last == null ||
          LocationRepository.distanceMeters(
                  last.lat, last.lng, point.lat, point.lng) >=
              _minDistanceM;
      final silent =
          last == null || point.ts.difference(last.ts) >= _maxSilence;

      if (moved || silent) {
        try {
          await LocationRepository.instance.writePosition(sid, point);
          _lastWritten = point;
          await _flushBuffer(sid);
        } catch (_) {
          // Offline: al buffer local (se sube al reconectar)
          await _bufferPoint(sid, point);
        }
      }

      await _evaluateZones(sid, point);
    } catch (e) {
      debugPrint('[Tracking] tick error: $e');
    }
  }

  // ── Geocercas (evaluación local con histéresis) ─────────────

  Future<void> _evaluateZones(String sid, LocationPoint point) async {
    // Refrescar zonas cada 10 min
    if (DateTime.now().difference(_zonesLoadedAt) > _zoneRefresh) {
      _zones = await LocationRepository.instance.getZones(sid);
      _zonesLoadedAt = DateTime.now();
    }

    for (final zone in _zones) {
      final dist = LocationRepository.distanceMeters(
          zone.lat, zone.lng, point.lat, point.lng);
      final wasInside = _insideZone[zone.id] ?? (dist <= zone.radiusM);

      // Histéresis: salir requiere radio+15% para no "parpadear"
      final isInside =
          wasInside ? dist <= zone.radiusM * 1.15 : dist <= zone.radiusM;

      if (isInside != wasInside) {
        _insideZone[zone.id] = isInside;
        final type = isInside ? 'enter' : 'exit';
        try {
          await LocationRepository.instance.writeZoneEvent(
            studentId: sid,
            zoneId: zone.id,
            zoneName: zone.name,
            type: type,
            ts: point.ts,
          );
          // Push directo a los padres (vía el backend en Cloudflare)
          final parents = await _parentIds(sid);
          if (parents.isNotEmpty) {
            await PushQueueService.instance.sendToUids(
              parents,
              channelId: 'edutrack_urgent',
              title: isInside
                  ? '📍 Llegó a ${zone.name}'
                  : '📍 Salió de ${zone.name}',
              body: isInside
                  ? 'Tu hijo/a entró a la zona "${zone.name}".'
                  : 'Tu hijo/a salió de la zona "${zone.name}".',
            );
          }
        } catch (e) {
          debugPrint('[Tracking] zoneEvent offline: $e');
        }
      } else {
        _insideZone[zone.id] = isInside;
      }
    }
  }

  Future<List<String>> _parentIds(String sid) async {
    try {
      final snap =
          await FirebaseFirestore.instance.doc('students/$sid').get();
      final parents = (snap.data()?['parentIds'] as List?)?.cast<String>();
      return parents ?? const [];
    } catch (_) {
      return const [];
    }
  }

  // ── Buffer offline ───────────────────────────────────────────

  Future<void> _bufferPoint(String sid, LocationPoint p) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(DatabaseHelper.tableLocationBuffer, {
        'student_id': sid,
        'lat': p.lat,
        'lng': p.lng,
        'accuracy': p.accuracy,
        'speed': p.speed,
        'ts': p.ts.toIso8601String(),
      });
      // Limitar el buffer a 200 puntos
      await db.execute(
        'DELETE FROM ${DatabaseHelper.tableLocationBuffer} WHERE id NOT IN '
        '(SELECT id FROM ${DatabaseHelper.tableLocationBuffer} '
        'ORDER BY id DESC LIMIT 200)',
      );
    } catch (e) {
      debugPrint('[Tracking] buffer: $e');
    }
  }

  Future<void> _flushBuffer(String sid) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(DatabaseHelper.tableLocationBuffer,
          where: 'student_id = ?', whereArgs: [sid], orderBy: 'id ASC');
      if (rows.isEmpty) return;

      for (final row in rows) {
        final point = LocationPoint(
          lat: row['lat'] as double,
          lng: row['lng'] as double,
          accuracy: row['accuracy'] as double?,
          speed: row['speed'] as double?,
          ts: DateTime.parse(row['ts'] as String),
        );
        await LocationRepository.instance.writePosition(sid, point);
      }
      await db.delete(DatabaseHelper.tableLocationBuffer,
          where: 'student_id = ?', whereArgs: [sid]);
      debugPrint('[Tracking] buffer subido (${rows.length} puntos)');
    } catch (_) {}
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    debugPrint('[Tracking] Servicio detenido');
  }
}
