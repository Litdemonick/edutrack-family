import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/models/student_model.dart';
import '../data/local/repositories/student_repository.dart';
import '../firebase/firestore_service.dart';
import '../services/sync_service.dart';
import '../../main.dart';

// ═══════════════════════════════════════════════════════════════
// FAMILY PROVIDERS — EduTrack Family 2.0
// Estudiantes vinculados a la sesión + estudiante activo.
//
// - linkedStudentsProvider: lista de hijos/estudiantes del adulto
//   (o el propio perfil si la sesión es de un estudiante)
// - activeStudentIdProvider: el hijo seleccionado en el selector
//   del dashboard; persiste en SharedPreferences.
// ═══════════════════════════════════════════════════════════════

const _kActiveStudentKey = 'active_student_id';

/// Estudiantes vinculados, offline-first: lee SQLite al instante y
/// refresca desde Firestore cuando hay sesión y red.
class LinkedStudentsNotifier extends StateNotifier<List<StudentProfile>> {
  LinkedStudentsNotifier(this._prefs) : super(const []) {
    _loadLocal();
  }

  final SharedPreferences _prefs;

  Future<void> _loadLocal() async {
    state = await StudentRepository.instance.getAll();
    SyncService.instance.setLinkedStudents(state.map((s) => s.id).toList());
  }

  /// Refresca la lista desde Firestore para el uid dado (adulto).
  Future<void> refreshForAdult(String uid) async {
    final remote = await FirestoreService.instance.getLinkedStudents(uid);
    if (remote.isNotEmpty || state.isEmpty) {
      await StudentRepository.instance.replaceAll(remote);
      state = remote;
    }
    SyncService.instance.setLinkedStudents(state.map((s) => s.id).toList());
  }

  /// Sesión de estudiante: su único "vinculado" es él mismo.
  Future<void> refreshForStudent(String studentId) async {
    final profile = await FirestoreService.instance.getStudent(studentId);
    if (profile != null) {
      await StudentRepository.instance.replaceAll([profile]);
      state = [profile];
    } else {
      await _loadLocal();
    }
    SyncService.instance.setLinkedStudents([studentId]);
  }

  Future<void> upsertLocal(StudentProfile student) async {
    await StudentRepository.instance.upsert(student);
    final rest = state.where((s) => s.id != student.id);
    state = [...rest, student]..sort((a, b) => a.name.compareTo(b.name));
    SyncService.instance.setLinkedStudents(state.map((s) => s.id).toList());
  }

  Future<void> removeLocal(String studentId) async {
    await StudentRepository.instance.delete(studentId);
    state = state.where((s) => s.id != studentId).toList();
    SyncService.instance.setLinkedStudents(state.map((s) => s.id).toList());
  }

  Future<void> clear() async {
    state = const [];
    SyncService.instance.setLinkedStudents(const []);
    await _prefs.remove(_kActiveStudentKey);
  }
}

final linkedStudentsProvider =
    StateNotifierProvider<LinkedStudentsNotifier, List<StudentProfile>>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LinkedStudentsNotifier(prefs);
});

/// Estudiante activo en el selector del dashboard (padre/profesor).
class ActiveStudentNotifier extends StateNotifier<String?> {
  ActiveStudentNotifier(this._prefs)
      : super(_prefs.getString(_kActiveStudentKey));

  final SharedPreferences _prefs;

  Future<void> select(String? studentId) async {
    state = studentId;
    if (studentId == null) {
      await _prefs.remove(_kActiveStudentKey);
    } else {
      await _prefs.setString(_kActiveStudentKey, studentId);
    }
  }
}

final activeStudentIdProvider =
    StateNotifierProvider<ActiveStudentNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ActiveStudentNotifier(prefs);
});

/// Perfil del estudiante activo. Si el seleccionado ya no está
/// vinculado (o no hay selección), cae al primero disponible.
final activeStudentProvider = Provider<StudentProfile?>((ref) {
  final id = ref.watch(activeStudentIdProvider);
  final students = ref.watch(linkedStudentsProvider);
  if (students.isEmpty) return null;
  for (final s in students) {
    if (s.id == id) return s;
  }
  return students.first;
});
