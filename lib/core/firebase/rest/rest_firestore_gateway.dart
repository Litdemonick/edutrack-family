import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/firebase/firestore_gateway.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/rest/firestore_rest_client.dart';
import 'package:edutrack_family/core/firebase/rest/polling_stream.dart';

// ═══════════════════════════════════════════════════════════════
// REST FIRESTORE GATEWAY — EduTrack Family 2.0 (Windows/Linux)
// Implementación de FirestoreGateway sobre Firestore REST (ver
// firestore_rest_client.dart), con los watchX (streams en vivo)
// sustituidos por polling — no hay streaming nativo simple sobre
// REST plano. Los intervalos son deliberadamente "no urgentes"
// (15-20s): sync_service.dart ya hace el pull correcto vía cursor
// en SQLite; este polling solo mejora la UX de "actualización casi
// instantánea" mientras la app está abierta.
// ═══════════════════════════════════════════════════════════════

const _kListInterval = Duration(seconds: 18);

class RestFirestoreGateway implements FirestoreGateway {
  final _client = FirestoreRestClient.instance;

  // ── Estudiantes ──────────────────────────────────────────────

  @override
  Future<void> upsertStudent(StudentProfile student) async {
    await _client.patchDoc(FirestorePaths.student(student.id), student.toFirestore());
  }

  @override
  Future<StudentProfile?> getStudent(String studentId) async {
    final doc = await _client.getDoc(FirestorePaths.student(studentId));
    if (doc == null) return null;
    return StudentProfile.fromFirestore(doc.data, doc.id);
  }

  @override
  Future<List<StudentProfile>> getLinkedStudents(String uid) async {
    final results = <String, StudentProfile>{};
    var hadError = false;
    for (final field in ['parentIds', 'teacherIds']) {
      try {
        final docs = await _client.runQuery(
          collectionId: FirestorePaths.students,
          filters: [QueryFilter(field, 'ARRAY_CONTAINS', uid)],
        );
        for (final doc in docs) {
          results[doc.id] = StudentProfile.fromFirestore(doc.data, doc.id);
        }
      } catch (_) {
        // Tolerante: el patrón nativo también sigue con el otro campo.
        hadError = true;
      }
    }
    // Ambiguo si hubo error Y quedó vacío — el caller (refreshForAdult)
    // decide no pisar el cache local ante esta excepción, en vez de
    // asumir "cero estudiantes" y perder el cache por un fallo transitorio.
    if (hadError && results.isEmpty) {
      throw Exception('No se pudo verificar la lista de estudiantes vinculados.');
    }
    return results.values.toList();
  }

  @override
  Stream<StudentProfile?> watchStudent(String studentId) {
    return PollingDocStream<StudentProfile?>(
      fetch: () => getStudent(studentId),
      interval: _kListInterval,
    ).watch();
  }

  @override
  Stream<List<StudentProfile>> watchLinkedStudents(String uid) {
    // getLinkedStudents ya devuelve el conjunto COMPLETO vigente
    // (fusionando parentIds/teacherIds) — PollingStream reemplaza la
    // lista entera en cada tick, así que altas/ediciones/eliminaciones
    // se reflejan solas sin lógica extra.
    return PollingStream<StudentProfile>(
      fetchAll: () => getLinkedStudents(uid),
      interval: _kListInterval,
    ).watch();
  }

  // ── Tareas ───────────────────────────────────────────────────

  @override
  Future<void> uploadTask(TaskModel task) async {
    if (task.studentId.isEmpty) return;
    await _client.patchDoc(FirestorePaths.task(task.studentId, task.id), task.toFirestore());
  }

  @override
  Future<List<TaskModel>> downloadTasks(String studentId, {DateTime? updatedAfter}) async {
    final docs = await _client.runQuery(
      parentRelPath: FirestorePaths.student(studentId),
      collectionId: 'tasks',
      filters: updatedAfter == null
          ? const []
          : [QueryFilter('updated_at', 'GREATER_THAN', updatedAfter.toIso8601String())],
    );
    return docs
        .map((d) => TaskModel.fromFirestore(d.data, d.id, studentId: studentId))
        .toList();
  }

  @override
  Stream<List<TaskModel>> watchTasks(String studentId) {
    return PollingStream<TaskModel>(
      fetchAll: () => downloadTasks(studentId),
      interval: _kListInterval,
    ).watch();
  }

  // ── Eventos ──────────────────────────────────────────────────

  @override
  Future<void> uploadEvent(EventModel event) async {
    if (event.studentId.isEmpty) return;
    await _client.patchDoc(FirestorePaths.event(event.studentId, event.id), event.toFirestore());
  }

  @override
  Future<List<EventModel>> downloadEvents(String studentId, {DateTime? updatedAfter}) async {
    final docs = await _client.runQuery(
      parentRelPath: FirestorePaths.student(studentId),
      collectionId: 'events',
      filters: updatedAfter == null
          ? const []
          : [QueryFilter('updated_at', 'GREATER_THAN', updatedAfter.toIso8601String())],
    );
    return docs
        .map((d) => EventModel.fromFirestore(d.data, d.id, studentId: studentId))
        .toList();
  }

  @override
  Stream<List<EventModel>> watchEvents(String studentId) {
    return PollingStream<EventModel>(
      fetchAll: () => downloadEvents(studentId),
      interval: _kListInterval,
    ).watch();
  }

  // ── Horario ──────────────────────────────────────────────────

  @override
  Future<void> uploadScheduleBlock(ScheduleBlock block) async {
    await _client.patchDoc(
        FirestorePaths.scheduleBlock(block.studentId, block.id), block.toFirestore());
  }

  @override
  Future<void> deleteScheduleBlock(String studentId, String blockId) async {
    await _client.deleteDoc(FirestorePaths.scheduleBlock(studentId, blockId));
  }

  @override
  Future<List<ScheduleBlock>> downloadScheduleBlocks(String studentId) async {
    final docs = await _client.getCollection(FirestorePaths.scheduleBlocks(studentId));
    return docs.map((d) => ScheduleBlock.fromFirestore(d.data, d.id, studentId)).toList();
  }

  @override
  Stream<List<ScheduleBlock>> watchScheduleBlocks(String studentId) {
    return PollingStream<ScheduleBlock>(
      fetchAll: () => downloadScheduleBlocks(studentId),
      interval: _kListInterval,
    ).watch();
  }

  // ── Primitivas genéricas ─────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getRawDoc(String relPath) async {
    final doc = await _client.getDoc(relPath);
    return doc?.data;
  }

  @override
  Future<void> setRawDoc(String relPath, Map<String, dynamic> data) async {
    await _client.patchDoc(relPath, data);
  }

  @override
  Future<void> deleteRawDoc(String relPath) async {
    await _client.deleteDoc(relPath);
  }

  @override
  Future<List<Map<String, dynamic>>> getRawCollection(String relPath) async {
    final docs = await _client.getCollection(relPath);
    return docs.map((d) => {'id': d.id, ...d.data}).toList();
  }

  @override
  Stream<Map<String, dynamic>?> watchRawDoc(String relPath, {Duration interval = _kListInterval}) {
    return PollingDocStream<Map<String, dynamic>?>(
      fetch: () => getRawDoc(relPath),
      interval: interval,
    ).watch();
  }

  @override
  Stream<List<Map<String, dynamic>>> watchRawCollection(String relPath,
      {Duration interval = _kListInterval}) {
    return PollingStream<Map<String, dynamic>>(
      fetchAll: () async {
        final docs = await _client.getCollection(relPath);
        return docs.map((d) => {'id': d.id, ...d.data}).toList();
      },
      interval: interval,
    ).watch();
  }
}
