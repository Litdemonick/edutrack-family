import '../data/local/models/event_model.dart';
import '../data/local/models/schedule_block_model.dart';
import '../data/local/models/student_model.dart';
import '../data/local/models/task_model.dart';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE GATEWAY — EduTrack Family 2.0
// Interfaz neutral de plataforma. Android/iOS/macOS/Web usan
// FirestoreService (SDK nativo cloud_firestore, ver
// firestore_service.dart); Windows/Linux usan RestFirestoreGateway
// (REST directo a Firestore, ver core/firebase/rest/) porque
// cloud_firestore no tiene implementación nativa ahí.
// ═══════════════════════════════════════════════════════════════

abstract class FirestoreGateway {
  Future<void> upsertStudent(StudentProfile student);
  Future<StudentProfile?> getStudent(String studentId);
  Future<List<StudentProfile>> getLinkedStudents(String uid);
  Stream<StudentProfile?> watchStudent(String studentId);

  /// Lista en vivo de estudiantes vinculados (padre o profesor) — se
  /// actualiza sola si otro dispositivo agrega, edita o elimina un
  /// hijo/a, sin depender de un refresh manual ni de reabrir la app.
  Stream<List<StudentProfile>> watchLinkedStudents(String uid);

  Future<void> uploadTask(TaskModel task);
  Future<List<TaskModel>> downloadTasks(String studentId, {DateTime? updatedAfter});
  Stream<List<TaskModel>> watchTasks(String studentId);

  Future<void> uploadEvent(EventModel event);
  Future<List<EventModel>> downloadEvents(String studentId, {DateTime? updatedAfter});
  Stream<List<EventModel>> watchEvents(String studentId);

  Future<void> uploadScheduleBlock(ScheduleBlock block);
  Future<void> deleteScheduleBlock(String studentId, String blockId);
  Future<List<ScheduleBlock>> downloadScheduleBlocks(String studentId);
  Stream<List<ScheduleBlock>> watchScheduleBlocks(String studentId);

  // ── Primitivas genéricas (doc suelto) ───────────────────────
  // Usadas por sitios que no encajan en el modelo estudiante/tarea/
  // evento/horario: perfil de usuario (users/{uid}), dispositivos
  // FCM, zonas de ubicación, wellness checks, etc. Evitan que cada
  // llamador reimplemente el códec REST por su cuenta.
  Future<Map<String, dynamic>?> getRawDoc(String relPath);
  Future<void> setRawDoc(String relPath, Map<String, dynamic> data);
  Future<void> deleteRawDoc(String relPath);
  Future<List<Map<String, dynamic>>> getRawCollection(String relPath);

  /// [interval] solo se usa en la implementación REST (polling); el
  /// SDK nativo ignora el parámetro y usa streaming real.
  Stream<Map<String, dynamic>?> watchRawDoc(String relPath, {Duration interval});
  Stream<List<Map<String, dynamic>>> watchRawCollection(String relPath, {Duration interval});
}
