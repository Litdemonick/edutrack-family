import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/local/models/event_model.dart';
import '../data/local/models/schedule_block_model.dart';
import '../data/local/models/student_model.dart';
import '../data/local/models/task_model.dart';
import 'firestore_gateway.dart';
import 'firestore_paths.dart';
import 'platform/firebase_backend.dart';
import 'rest/rest_firestore_gateway.dart';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE SERVICE — EduTrack Family 2.0
// Implementación NATIVA de FirestoreGateway (Android/iOS/macOS/Web).
// Acceso a Firestore SIEMPRE scoped por estudiante:
// students/{studentId}/tasks|events|scheduleBlocks
// Las rutas salen de FirestorePaths (única fuente de verdad).
//
// En Windows/Linux, `.instance` resuelve a RestFirestoreGateway (REST
// directo, ver core/firebase/rest/) — ver
// core/firebase/platform/firebase_backend.dart. Ningún llamador
// (family_repository.dart, sync_service.dart, etc.) distingue cuál es
// cuál: ambas implementan FirestoreGateway con la misma firma.
// ═══════════════════════════════════════════════════════════════

class FirestoreService implements FirestoreGateway {
  FirestoreService._();
  static final FirestoreGateway instance =
      useDesktopRestBackend ? RestFirestoreGateway() : FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // ESTUDIANTES
  // ─────────────────────────────────────────────────────────────

  @override
  Future<void> upsertStudent(StudentProfile student) async {
    await _db
        .doc(FirestorePaths.student(student.id))
        .set(student.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<StudentProfile?> getStudent(String studentId) async {
    final snap = await _db.doc(FirestorePaths.student(studentId)).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return StudentProfile.fromFirestore(data, snap.id);
  }

  /// Estudiantes vinculados a este adulto (como padre o profesor).
  @override
  Future<List<StudentProfile>> getLinkedStudents(String uid) async {
    final results = <String, StudentProfile>{};
    var hadError = false;
    for (final field in ['parentIds', 'teacherIds']) {
      try {
        final snap = await _db
            .collection(FirestorePaths.students)
            .where(field, arrayContains: uid)
            .get();
        for (final doc in snap.docs) {
          results[doc.id] = StudentProfile.fromFirestore(doc.data(), doc.id);
        }
      } catch (e) {
        debugPrint('[Firestore] Error listando estudiantes ($field): $e');
        hadError = true;
      }
    }
    // Ambiguo si hubo error Y quedó vacío (¿de verdad no tiene ninguno
    // vinculado, o fue un error de red?) — el caller (refreshForAdult)
    // decide no pisar el cache local ante esta excepción, en vez de
    // asumir "cero estudiantes" y perder el cache por un fallo transitorio.
    if (hadError && results.isEmpty) {
      throw Exception('No se pudo verificar la lista de estudiantes vinculados.');
    }
    return results.values.toList();
  }

  /// Stream en tiempo real del doc del estudiante (consentimiento GPS, etc.)
  @override
  Stream<StudentProfile?> watchStudent(String studentId) {
    return _db.doc(FirestorePaths.student(studentId)).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return StudentProfile.fromFirestore(data, snap.id);
    });
  }

  /// Lista en vivo de estudiantes vinculados — dos queries en paralelo
  /// (parentIds/teacherIds), fusionadas en cada actualización de
  /// cualquiera de las dos. Cada snapshot trae el conjunto COMPLETO
  /// vigente de esa query (no un diff), así que recalcular la unión
  /// completa en cada emisión refleja correctamente altas, ediciones
  /// Y eliminaciones (un doc borrado deja de aparecer en su snapshot).
  @override
  Stream<List<StudentProfile>> watchLinkedStudents(String uid) {
    late final StreamController<List<StudentProfile>> controller;
    var parentDocs = <String, StudentProfile>{};
    var teacherDocs = <String, StudentProfile>{};
    final subs = <StreamSubscription>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add({...parentDocs, ...teacherDocs}.values.toList());
      }
    }

    controller = StreamController<List<StudentProfile>>.broadcast(
      onListen: () {
        subs.add(_db
            .collection(FirestorePaths.students)
            .where('parentIds', arrayContains: uid)
            .snapshots()
            .listen((snap) {
          parentDocs = {
            for (final d in snap.docs) d.id: StudentProfile.fromFirestore(d.data(), d.id),
          };
          emit();
        }, onError: (e) => debugPrint('[Firestore] watchLinkedStudents parentIds: $e')));

        subs.add(_db
            .collection(FirestorePaths.students)
            .where('teacherIds', arrayContains: uid)
            .snapshots()
            .listen((snap) {
          teacherDocs = {
            for (final d in snap.docs) d.id: StudentProfile.fromFirestore(d.data(), d.id),
          };
          emit();
        }, onError: (e) => debugPrint('[Firestore] watchLinkedStudents teacherIds: $e')));
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  // ─────────────────────────────────────────────────────────────
  // TAREAS (por estudiante)
  // ─────────────────────────────────────────────────────────────

  @override
  Future<void> uploadTask(TaskModel task) async {
    if (task.studentId.isEmpty) return;
    await _db
        .doc(FirestorePaths.task(task.studentId, task.id))
        .set(task.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<List<TaskModel>> downloadTasks(String studentId,
      {DateTime? updatedAfter}) async {
    Query<Map<String, dynamic>> query =
        _db.collection(FirestorePaths.tasks(studentId));
    if (updatedAfter != null) {
      query = query.where('updated_at',
          isGreaterThan: updatedAfter.toIso8601String());
    }
    final snap = await query.get();
    return _parseDocs(
        snap.docs, (d, id) => TaskModel.fromFirestore(d, id, studentId: studentId));
  }

  @override
  Stream<List<TaskModel>> watchTasks(String studentId) {
    return _db
        .collection(FirestorePaths.tasks(studentId))
        .snapshots()
        .map((snap) => _parseDocs(snap.docs,
            (d, id) => TaskModel.fromFirestore(d, id, studentId: studentId)));
  }

  // ─────────────────────────────────────────────────────────────
  // EVENTOS (por estudiante)
  // ─────────────────────────────────────────────────────────────

  @override
  Future<void> uploadEvent(EventModel event) async {
    if (event.studentId.isEmpty) return;
    await _db
        .doc(FirestorePaths.event(event.studentId, event.id))
        .set(event.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<List<EventModel>> downloadEvents(String studentId,
      {DateTime? updatedAfter}) async {
    Query<Map<String, dynamic>> query =
        _db.collection(FirestorePaths.events(studentId));
    if (updatedAfter != null) {
      query = query.where('updated_at',
          isGreaterThan: updatedAfter.toIso8601String());
    }
    final snap = await query.get();
    return _parseDocs(snap.docs,
        (d, id) => EventModel.fromFirestore(d, id, studentId: studentId));
  }

  @override
  Stream<List<EventModel>> watchEvents(String studentId) {
    return _db
        .collection(FirestorePaths.events(studentId))
        .snapshots()
        .map((snap) => _parseDocs(snap.docs,
            (d, id) => EventModel.fromFirestore(d, id, studentId: studentId)));
  }

  // ─────────────────────────────────────────────────────────────
  // HORARIO (por estudiante)
  // ─────────────────────────────────────────────────────────────

  @override
  Future<void> uploadScheduleBlock(ScheduleBlock block) async {
    await _db
        .doc(FirestorePaths.scheduleBlock(block.studentId, block.id))
        .set(block.toFirestore(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteScheduleBlock(String studentId, String blockId) async {
    await _db
        .doc(FirestorePaths.scheduleBlock(studentId, blockId))
        .delete();
  }

  @override
  Future<List<ScheduleBlock>> downloadScheduleBlocks(String studentId) async {
    final snap =
        await _db.collection(FirestorePaths.scheduleBlocks(studentId)).get();
    return _parseDocs(snap.docs,
        (d, id) => ScheduleBlock.fromFirestore(d, id, studentId));
  }

  @override
  Stream<List<ScheduleBlock>> watchScheduleBlocks(String studentId) {
    return _db
        .collection(FirestorePaths.scheduleBlocks(studentId))
        .snapshots()
        .map((snap) => _parseDocs(
            snap.docs, (d, id) => ScheduleBlock.fromFirestore(d, id, studentId)));
  }

  // ─────────────────────────────────────────────────────────────
  // PRIMITIVAS GENÉRICAS (doc/colección suelta)
  // ─────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getRawDoc(String relPath) async {
    final snap = await _db.doc(relPath).get();
    return snap.data();
  }

  @override
  Future<void> setRawDoc(String relPath, Map<String, dynamic> data) async {
    await _db.doc(relPath).set(data, SetOptions(merge: true));
  }

  @override
  Future<void> deleteRawDoc(String relPath) async {
    await _db.doc(relPath).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> getRawCollection(String relPath) async {
    final snap = await _db.collection(relPath).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  @override
  Stream<Map<String, dynamic>?> watchRawDoc(String relPath, {Duration interval = Duration.zero}) {
    // interval se ignora: el SDK nativo usa streaming real, no polling.
    return _db.doc(relPath).snapshots().map((snap) => snap.data());
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRawCollection(String relPath, {Duration interval = Duration.zero}) {
    return _db.collection(relPath).snapshots().map(
        (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // ─────────────────────────────────────────────────────────────

  /// Parsea docs tolerando documentos malformados (no tumba el stream).
  List<T> _parseDocs<T>(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    T Function(Map<String, dynamic> data, String id) parser,
  ) {
    final items = <T>[];
    for (final doc in docs) {
      try {
        items.add(parser(doc.data(), doc.id));
      } catch (e) {
        debugPrint('[Firestore] Doc malformado ${doc.id}: $e');
      }
    }
    return items;
  }
}
