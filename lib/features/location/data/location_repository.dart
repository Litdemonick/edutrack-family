import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/firebase/platform/firebase_backend.dart';
import 'package:edutrack_family/core/firebase/rest/polling_stream.dart';
import 'location_models.dart';

// ═══════════════════════════════════════════════════════════════
// LOCATION REPOSITORY — EduTrack Family 2.0
// Escrituras de posición/evento de zona: siempre del dispositivo
// del hijo (Android, dentro del isolate foreground de
// child/tracking_service.dart) — nunca corren en escritorio, se
// dejan sobre cloud_firestore directo sin cambios.
//
// Lecturas y acciones del padre (ver current/zonas/consentimiento)
// sí deben funcionar en Windows/Linux → pasan por
// FirestoreService.instance (gateway neutral de plataforma) y,
// para los streams en vivo, usan polling en desktop (no hay
// streaming nativo simple sobre REST) en vez de .snapshots().
// ═══════════════════════════════════════════════════════════════

class LocationRepository {
  LocationRepository._();
  static final LocationRepository instance = LocationRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final _gateway = FirestoreService.instance;

  static const historyTtl = Duration(hours: 72);
  // Zonas: cambian poco, no hace falta que sea rápido.
  static const _pollInterval = Duration(seconds: 45);
  // Posición actual y consentimiento: el padre/tutor los mira en
  // vivo mientras espera una respuesta (¿ya aceptó el hijo? ¿dónde
  // está ahora?) — 45s ahí se sentía "trabado, no pasa nada". Un
  // poll bastante más frecuente en escritorio (Android usa
  // .snapshots() nativo, tiempo real real sin este límite).
  static const _livePollInterval = Duration(seconds: 5);

  // ── Escrituras (dispositivo del hijo) ────────────────────────

  Future<void> writePosition(String studentId, LocationPoint point) async {
    final batch = _db.batch();
    batch.set(
      _db.doc(FirestorePaths.locationCurrent(studentId)),
      point.toFirestore(),
    );
    batch.set(
      _db.collection(FirestorePaths.locationHistory(studentId)).doc(),
      point.toFirestore(
        expireAt: DateTime.now().add(historyTtl),
      ),
    );
    await batch.commit();
  }

  Future<void> writeZoneEvent({
    required String studentId,
    required String zoneId,
    required String zoneName,
    required String type, // 'enter' | 'exit'
    required DateTime ts,
  }) async {
    await _db
        .collection(FirestorePaths.zoneEvents(studentId))
        .doc(const Uuid().v4())
        .set({
      'zoneId': zoneId,
      'zoneName': zoneName,
      'type': type,
      'ts': ts.toIso8601String(),
    });
  }

  // ── Lecturas (padre) ─────────────────────────────────────────

  Future<LocationPoint?> _getCurrent(String studentId) async {
    final data = await _gateway.getRawDoc(FirestorePaths.locationCurrent(studentId));
    if (data == null) return null;
    try {
      return LocationPoint.fromFirestore(data);
    } catch (e) {
      debugPrint('[Location] current malformado: $e');
      return null;
    }
  }

  /// Ubicación en vivo. En escritorio no hay GPS que reportar — solo
  /// se lee, por polling.
  Stream<LocationPoint?> watchCurrent(String studentId) {
    if (useDesktopRestBackend) {
      return PollingDocStream<LocationPoint?>(
        fetch: () => _getCurrent(studentId),
        interval: _livePollInterval,
      ).watch();
    }
    return _db
        .doc(FirestorePaths.locationCurrent(studentId))
        .snapshots()
        .map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      try {
        return LocationPoint.fromFirestore(data);
      } catch (e) {
        debugPrint('[Location] current malformado: $e');
        return null;
      }
    });
  }

  /// [before]: para paginar hacia atrás, pasar el `ts` del punto más
  /// antiguo ya cargado — trae la siguiente página de puntos previos.
  ///
  /// Usa el gateway neutral de plataforma (no cloud_firestore
  /// directo) — sin esto, tronaba en Windows/Linux con "No Firebase
  /// App '[DEFAULT]' has been created", ya que ahí nunca se llama
  /// Firebase.initializeApp() (backend REST en su lugar). El
  /// gateway genérico no soporta orderBy/where/limit del lado del
  /// servidor, así que se filtra y ordena acá.
  Future<List<LocationPoint>> getHistory(
    String studentId, {
    int limit = 100,
    DateTime? before,
  }) async {
    try {
      final raw = await _gateway
          .getRawCollection(FirestorePaths.locationHistory(studentId));
      var points = raw.map(LocationPoint.fromFirestore).toList()
        ..sort((a, b) => b.ts.compareTo(a.ts));
      if (before != null) {
        points = points.where((p) => p.ts.isBefore(before)).toList();
      }
      return points.take(limit).toList().reversed.toList();
    } catch (e) {
      debugPrint('[Location] historial: $e');
      return const [];
    }
  }

  // ── Zonas ────────────────────────────────────────────────────
  // Crear/editar/borrar zonas es una acción del padre — debe
  // funcionar en escritorio, por eso pasa por el gateway (no
  // cloud_firestore directo).

  Stream<List<SafeZone>> watchZones(String studentId) {
    if (useDesktopRestBackend) {
      return PollingStream<SafeZone>(
        fetchAll: () => getZones(studentId),
        interval: _pollInterval,
      ).watch();
    }
    return _db
        .collection(FirestorePaths.zones(studentId))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SafeZone.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<List<SafeZone>> getZones(String studentId) async {
    try {
      final data = await _gateway.getRawCollection(FirestorePaths.zones(studentId));
      return data.map((m) => SafeZone.fromFirestore(m, m['id'] as String)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertZone(String studentId, SafeZone zone) async {
    await _gateway.setRawDoc(FirestorePaths.zone(studentId, zone.id), zone.toFirestore());
  }

  Future<void> deleteZone(String studentId, String zoneId) async {
    await _gateway.deleteRawDoc(FirestorePaths.zone(studentId, zoneId));
  }

  // ── Consentimiento ───────────────────────────────────────────

  Future<void> setSharingEnabledByParent(
      String studentId, bool enabled) async {
    await _gateway.setRawDoc(FirestorePaths.student(studentId), {
      'locationSharing': {
        'enabledByParent': enabled,
        if (!enabled) 'deviceConfirmed': false,
      },
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// El hijo confirma/retira su consentimiento. Vive en
  /// locations/consent (el hijo puede escribir ahí; en el doc
  /// del estudiante no — reglas). Esto solo corre en el dispositivo
  /// del hijo (Android) en la práctica, pero pasar por el gateway
  /// no cuesta nada y evita un caso especial más.
  Future<void> setDeviceConfirmed(String studentId, bool confirmed) async {
    await _gateway.setRawDoc('${FirestorePaths.student(studentId)}/locations/consent', {
      'deviceConfirmed': confirmed,
      if (confirmed) 'consentedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Guarda (o limpia, con null) el motivo por el que el rastreo no
  /// puede arrancar en el celular del hijo (falta un permiso, GPS
  /// apagado, etc.) — sin esto, ni el padre/tutor ni el propio hijo
  /// tenían forma de saber, mirando la app, POR QUÉ no llegaba
  /// ninguna posición: el padre veía "Compartiendo ubicación" en
  /// verde igual, sin ninguna pista de que en realidad estaba
  /// bloqueado esperando un permiso.
  Future<void> setPermissionError(String studentId, String? error) async {
    await _gateway.setRawDoc('${FirestorePaths.student(studentId)}/locations/consent', {
      'permissionError': error,
    });
  }

  /// Estado combinado del consentimiento (padre + dispositivo).
  Stream<({bool enabledByParent, bool deviceConfirmed, String? permissionError})>
      watchConsent(String studentId) {
    if (useDesktopRestBackend) {
      return PollingDocStream<
          ({bool enabledByParent, bool deviceConfirmed, String? permissionError})>(
        fetch: () => _fetchConsent(studentId),
        interval: _livePollInterval,
      ).watch();
    }
    // Dos streams combinados a mano (sin rxdart) — antes se escuchaba
    // SOLO students/{id} y se leía locations/consent una única vez
    // por cada emisión de ese doc. Como aceptar en el celular del
    // hijo escribe en locations/consent (un doc APARTE, ver
    // setDeviceConfirmed), ese cambio nunca disparaba una nueva
    // emisión — el switch de "Compartir ubicación" en Ajustes se
    // quedaba mostrando el valor viejo (apagado) para siempre, aunque
    // el hijo ya hubiera aceptado, hasta que el padre volviera a
    // tocar algo del doc del estudiante.
    late final StreamController<
        ({bool enabledByParent, bool deviceConfirmed, String? permissionError})>
        controller;
    var lastSharing = false;
    var lastConfirmed = false;
    String? lastError;
    final subs = <StreamSubscription>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add((
          enabledByParent: lastSharing,
          deviceConfirmed: lastConfirmed,
          permissionError: lastError,
        ));
      }
    }

    controller = StreamController.broadcast(
      onListen: () {
        subs.add(_db
            .doc(FirestorePaths.student(studentId))
            .snapshots()
            .listen((snap) {
          final sharing =
              (snap.data()?['locationSharing'] as Map<String, dynamic>?) ??
                  const {};
          lastSharing = (sharing['enabledByParent'] ?? false) as bool;
          emit();
        }));
        subs.add(_db
            .doc('${FirestorePaths.student(studentId)}/locations/consent')
            .snapshots()
            .listen((snap) {
          lastConfirmed = (snap.data()?['deviceConfirmed'] ?? false) as bool;
          lastError = snap.data()?['permissionError'] as String?;
          emit();
        }));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<({bool enabledByParent, bool deviceConfirmed, String? permissionError})>
      _fetchConsent(String studentId) async {
    final studentData = await _gateway.getRawDoc(FirestorePaths.student(studentId));
    final sharing = (studentData?['locationSharing'] as Map<String, dynamic>?) ?? const {};
    final consentData =
        await _gateway.getRawDoc('${FirestorePaths.student(studentId)}/locations/consent');
    return (
      enabledByParent: (sharing['enabledByParent'] ?? false) as bool,
      deviceConfirmed: (consentData?['deviceConfirmed'] ?? false) as bool,
      permissionError: consentData?['permissionError'] as String?,
    );
  }

  Future<bool> isDeviceConfirmed(String studentId) async {
    try {
      final data =
          await _gateway.getRawDoc('${FirestorePaths.student(studentId)}/locations/consent');
      return (data?['deviceConfirmed'] ?? false) as bool;
    } catch (_) {
      return false;
    }
  }

  // ── Utilidades ───────────────────────────────────────────────

  /// Distancia haversine en metros.
  static double distanceMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180.0;
}
