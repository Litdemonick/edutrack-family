import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/models/photo_evidence_model.dart';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE SERVICE — EduTrack Family
// Sincronización WiFi en tiempo real con Firebase Firestore.
// Se usa solo cuando hay conexión a internet.
// ═══════════════════════════════════════════════════════════════

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────
  // COLECCIONES
  // ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _tasks =>
      _db.collection('tasks');

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection('events');

  CollectionReference<Map<String, dynamic>> get _evidences =>
      _db.collection('evidences');

  // ─────────────────────────────────────────────────────────────
  // TAREAS
  // ─────────────────────────────────────────────────────────────

  Future<void> uploadTask(TaskModel task) async {
    try {
      await _tasks.doc(task.id).set(task.toFirestore());
    } catch (_) {}
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _tasks.doc(taskId).delete();
    } catch (_) {}
  }

  Future<List<TaskModel>> downloadAllTasks() async {
    try {
      final snap = await _tasks.get();
      return snap.docs
          .map((d) => TaskModel.fromFirestore(d.data(), d.id))
          .toList();
    } catch (_) { return []; }
  }

  Stream<List<TaskModel>> watchTasks() {
    return _tasks.snapshots().map((snap) {
      final result = <TaskModel>[];
      for (final doc in snap.docs) {
        try {
          result.add(TaskModel.fromFirestore(doc.data(), doc.id));
        } catch (_) {
          // Documento malformado: se ignora para no matar el stream
        }
      }
      return result;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // EVENTOS
  // ─────────────────────────────────────────────────────────────

  Future<void> uploadEvent(EventModel event) async {
    try {
      await _events.doc(event.id).set(event.toFirestore());
    } catch (_) {}
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await _events.doc(eventId).delete();
    } catch (_) {}
  }

  Future<List<EventModel>> downloadAllEvents() async {
    try {
      final snap = await _events.get();
      return snap.docs
          .map((d) => EventModel.fromFirestore(d.data(), d.id))
          .toList();
    } catch (_) { return []; }
  }

  Stream<List<EventModel>> watchEvents() {
    return _events.snapshots().map((snap) {
      final result = <EventModel>[];
      for (final doc in snap.docs) {
        try {
          result.add(EventModel.fromFirestore(doc.data(), doc.id));
        } catch (_) {
          // Documento malformado: se ignora para no matar el stream
        }
      }
      return result;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // EVIDENCIAS
  // ─────────────────────────────────────────────────────────────

  Future<void> uploadEvidence(PhotoEvidenceModel evidence) async {
    try {
      await _evidences.doc(evidence.id).set(evidence.toFirestore());
    } catch (_) {}
  }

  Future<List<PhotoEvidenceModel>> downloadEvidencesForTask(
    String taskId,
  ) async {
    try {
      final snap =
          await _evidences.where('task_id', isEqualTo: taskId).get();
      return snap.docs
          .map((d) => PhotoEvidenceModel.fromFirestore(d.data(), d.id))
          .toList();
    } catch (_) { return []; }
  }
}
