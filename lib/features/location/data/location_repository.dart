import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'location_models.dart';

// ═══════════════════════════════════════════════════════════════
// LOCATION REPOSITORY — EduTrack Family 2.0
// Escrituras del dispositivo del hijo y lecturas del padre.
// La autorización la imponen las reglas: locations/** solo la
// escriben uid==studentId y solo la leen los padres.
// ═══════════════════════════════════════════════════════════════

class LocationRepository {
  LocationRepository._();
  static final LocationRepository instance = LocationRepository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const historyTtl = Duration(hours: 72);

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

  Stream<LocationPoint?> watchCurrent(String studentId) {
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

  Future<List<LocationPoint>> getHistory(String studentId,
      {int limit = 100}) async {
    try {
      final snap = await _db
          .collection(FirestorePaths.locationHistory(studentId))
          .orderBy('ts', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => LocationPoint.fromFirestore(d.data()))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      debugPrint('[Location] historial: $e');
      return const [];
    }
  }

  // ── Zonas ────────────────────────────────────────────────────

  Stream<List<SafeZone>> watchZones(String studentId) {
    return _db
        .collection(FirestorePaths.zones(studentId))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SafeZone.fromFirestore(d.data(), d.id))
            .toList());
  }

  Future<List<SafeZone>> getZones(String studentId) async {
    try {
      final snap =
          await _db.collection(FirestorePaths.zones(studentId)).get();
      return snap.docs
          .map((d) => SafeZone.fromFirestore(d.data(), d.id))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> upsertZone(String studentId, SafeZone zone) async {
    await _db
        .doc(FirestorePaths.zone(studentId, zone.id))
        .set(zone.toFirestore());
  }

  Future<void> deleteZone(String studentId, String zoneId) async {
    await _db.doc(FirestorePaths.zone(studentId, zoneId)).delete();
  }

  // ── Consentimiento ───────────────────────────────────────────

  Future<void> setSharingEnabledByParent(
      String studentId, bool enabled) async {
    await _db.doc(FirestorePaths.student(studentId)).set({
      'locationSharing': {
        'enabledByParent': enabled,
        if (!enabled) 'deviceConfirmed': false,
      },
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// El hijo confirma/retira su consentimiento. Vive en
  /// locations/consent (el hijo puede escribir ahí; en el doc
  /// del estudiante no — reglas).
  Future<void> setDeviceConfirmed(String studentId, bool confirmed) async {
    await _db
        .doc('${FirestorePaths.student(studentId)}/locations/consent')
        .set({
      'deviceConfirmed': confirmed,
      if (confirmed) 'consentedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Estado combinado del consentimiento (padre + dispositivo).
  Stream<({bool enabledByParent, bool deviceConfirmed})> watchConsent(
      String studentId) {
    final studentDoc =
        _db.doc(FirestorePaths.student(studentId)).snapshots();
    final consentDoc = _db
        .doc('${FirestorePaths.student(studentId)}/locations/consent')
        .snapshots();

    return studentDoc.asyncMap((studentSnap) async {
      final sharing = (studentSnap.data()?['locationSharing']
              as Map<String, dynamic>?) ??
          const {};
      final consentSnap = await consentDoc.first;
      return (
        enabledByParent: (sharing['enabledByParent'] ?? false) as bool,
        deviceConfirmed:
            (consentSnap.data()?['deviceConfirmed'] ?? false) as bool,
      );
    });
  }

  Future<bool> isDeviceConfirmed(String studentId) async {
    try {
      final snap = await _db
          .doc('${FirestorePaths.student(studentId)}/locations/consent')
          .get();
      return (snap.data()?['deviceConfirmed'] ?? false) as bool;
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
