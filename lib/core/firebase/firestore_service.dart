import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/local/models/event_model.dart';
import '../data/local/models/schedule_block_model.dart';
import '../data/local/models/student_model.dart';
import '../data/local/models/task_model.dart';
import 'firestore_paths.dart';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE SERVICE — EduTrack Family 2.0
// Acceso a Firestore SIEMPRE scoped por estudiante:
// students/{studentId}/tasks|events|scheduleBlocks
// Las rutas salen de FirestorePaths (única fuente de verdad).
// ═══════════════════════════════════════════════════════════════

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // ESTUDIANTES
  // ─────────────────────────────────────────────────────────────

  Future<void> upsertStudent(StudentProfile student) async {
    await _db
        .doc(FirestorePaths.student(student.id))
        .set(student.toFirestore(), SetOptions(merge: true));
  }

  Future<StudentProfile?> getStudent(String studentId) async {
    final snap = await _db.doc(FirestorePaths.student(studentId)).get();
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return StudentProfile.fromFirestore(data, snap.id);
  }

  /// Estudiantes vinculados a este adulto (como padre o profesor).
  Future<List<StudentProfile>> getLinkedStudents(String uid) async {
    final results = <String, StudentProfile>{};
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
      }
    }
    return results.values.toList();
  }

  /// Stream en tiempo real del doc del estudiante (consentimiento GPS, etc.)
  Stream<StudentProfile?> watchStudent(String studentId) {
    return _db.doc(FirestorePaths.student(studentId)).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      return StudentProfile.fromFirestore(data, snap.id);
    });
  }

  // ─────────────────────────────────────────────────────────────
  // TAREAS (por estudiante)
  // ─────────────────────────────────────────────────────────────

  Future<void> uploadTask(TaskModel task) async {
    if (task.studentId.isEmpty) return;
    await _db
        .doc(FirestorePaths.task(task.studentId, task.id))
        .set(task.toFirestore(), SetOptions(merge: true));
  }

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

  Future<void> uploadEvent(EventModel event) async {
    if (event.studentId.isEmpty) return;
    await _db
        .doc(FirestorePaths.event(event.studentId, event.id))
        .set(event.toFirestore(), SetOptions(merge: true));
  }

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

  Future<void> uploadScheduleBlock(ScheduleBlock block) async {
    await _db
        .doc(FirestorePaths.scheduleBlock(block.studentId, block.id))
        .set(block.toFirestore(), SetOptions(merge: true));
  }

  Future<void> deleteScheduleBlock(String studentId, String blockId) async {
    await _db
        .doc(FirestorePaths.scheduleBlock(studentId, blockId))
        .delete();
  }

  Future<List<ScheduleBlock>> downloadScheduleBlocks(String studentId) async {
    final snap =
        await _db.collection(FirestorePaths.scheduleBlocks(studentId)).get();
    return _parseDocs(snap.docs,
        (d, id) => ScheduleBlock.fromFirestore(d, id, studentId));
  }

  Stream<List<ScheduleBlock>> watchScheduleBlocks(String studentId) {
    return _db
        .collection(FirestorePaths.scheduleBlocks(studentId))
        .snapshots()
        .map((snap) => _parseDocs(
            snap.docs, (d, id) => ScheduleBlock.fromFirestore(d, id, studentId)));
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
