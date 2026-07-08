import 'dart:async';

import '../utils/app_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local/models/student_model.dart';
import '../data/local/repositories/student_repository.dart';
import '../database/database_helper.dart';
import '../firebase/firestore_service.dart';
import '../services/sync_service.dart';
import '../../features/family/data/family_repository.dart';
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
  StreamSubscription<List<StudentProfile>>? _remoteSub;

  /// Se pone en false cada vez que arranca un startWatching() nuevo —
  /// la PRIMERA emisión de ese stream no es una base confiable para
  /// detectar "se quitó un estudiante" (puede ser un snapshot de
  /// caché local vacío/incompleto antes de sincronizar con el
  /// servidor, típico justo al reabrir la app). Sin esto, un
  /// profesor podía perder su estudiante vinculado (borrado local)
  /// solo por reabrir la app, sin que nadie lo haya quitado de
  /// verdad — mismo tipo de guardia que _sawValidDoc en RevocationGate.
  bool _hasConfirmedRemote = false;

  Future<void> _loadLocal() async {
    state = await StudentRepository.instance.getAll();
    SyncService.instance.setLinkedStudents(state.map((s) => s.id).toList());
  }

  /// Limpia tareas/eventos/horario/evidencias/GPS/checkpoints locales
  /// de un estudiante que ya no aparece en la lista remota — pasa en
  /// CUALQUIER dispositivo adulto (no solo el que borró al hijo):
  /// otro padre/tutor de la misma familia, o un profesor que perdió
  /// acceso porque el código se regeneró. Sin esto, esos datos se
  /// quedaban huérfanos en el SQLite local de ese otro dispositivo
  /// aunque en Firestore ya no existiera nada.
  /// Mismo contenido exacto (mismos ids con el mismo updatedAt) que ya
  /// está en pantalla. Sin este chequeo, cada emisión del polling de
  /// escritorio (~15-20s) o cada refresco manual reemplazaba `state`
  /// por una lista "nueva" aunque nada hubiera cambiado, haciendo
  /// parpadear cualquier UI derivada (ej. el nombre del estudiante
  /// activo en el encabezado del panel).
  bool _sameStudents(List<StudentProfile> a, List<StudentProfile> b) {
    if (a.length != b.length) return false;
    final byId = {for (final s in a) s.id: s.updatedAt};
    for (final s in b) {
      final prevUpdatedAt = byId[s.id];
      if (prevUpdatedAt == null || prevUpdatedAt != s.updatedAt) return false;
    }
    return true;
  }

  Future<void> _purgeRemoved(List<StudentProfile> remote) async {
    final oldIds = state.map((s) => s.id).toSet();
    final newIds = remote.map((s) => s.id).toSet();
    final removed = oldIds.difference(newIds);
    for (final studentId in removed) {
      for (final table in [
        DatabaseHelper.tableTask,
        DatabaseHelper.tableEvent,
        DatabaseHelper.tableScheduleBlock,
        DatabaseHelper.tableEvidence,
        DatabaseHelper.tableLocationBuffer,
        DatabaseHelper.tableSyncMeta,
        DatabaseHelper.tablePendingOp,
      ]) {
        await DatabaseHelper.instance.deleteWhereStudent(table, studentId);
      }
    }
  }

  /// Escucha en vivo (streaming real en Android/iOS, polling ~18s en
  /// Windows/Linux — ver firestore_gateway.dart) los estudiantes
  /// vinculados a este adulto: si otro dispositivo agrega, edita o
  /// elimina un hijo/a, se refleja solo, sin depender de un refresh
  /// manual ni de reabrir la app. Idempotente: llamar de nuevo con
  /// el mismo/otro uid reemplaza la suscripción anterior.
  void startWatching(String uid) {
    _remoteSub?.cancel();
    _hasConfirmedRemote = false;
    _remoteSub = FirestoreService.instance.watchLinkedStudents(uid).listen(
      (remote) async {
        // Solo purgar a partir de la 2da emisión confirmada — la 1ra
        // ya sirve para actualizar el estado/cache normalmente, pero
        // no como base para decidir qué se "quitó".
        if (_hasConfirmedRemote) {
          await _purgeRemoved(remote);
        }
        _hasConfirmedRemote = true;
        await StudentRepository.instance.replaceAll(remote);
        if (!_sameStudents(state, remote)) state = remote;
        SyncService.instance.setLinkedStudents(remote.map((s) => s.id).toList());
      },
      onError: (e) =>
          AppLog.d('[LinkedStudents] startWatching: cache local sin cambios ($e)'),
    );
  }

  @override
  void dispose() {
    _remoteSub?.cancel();
    super.dispose();
  }

  /// Refresca la lista desde Firestore para el uid dado (adulto).
  /// Uso puntual (botón/pull-to-refresh) — startWatching ya cubre la
  /// actualización continua mientras la app está abierta.
  Future<void> refreshForAdult(String uid) async {
    try {
      // getLinkedStudents lanza si hubo error de red Y quedó vacío
      // (ambiguo) — un resultado vacío SIN excepción es de fiar (p. ej.
      // se eliminó el único hijo vinculado desde otro dispositivo) y
      // debe reflejarse, no quedarse pegado al cache local viejo.
      final remote = await FirestoreService.instance.getLinkedStudents(uid);
      await _purgeRemoved(remote);
      await StudentRepository.instance.replaceAll(remote);
      if (!_sameStudents(state, remote)) state = remote;
    } catch (e) {
      AppLog.d('[LinkedStudents] refreshForAdult: cache local sin cambios ($e)');
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
    final remaining = state.where((s) => s.id != studentId).toList();
    await _purgeRemoved(remaining);
    await StudentRepository.instance.delete(studentId);
    state = remaining;
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

/// Pestaña pendiente de abrir en AdminHome al volver de otra pantalla
/// (ej. "Ver logros" en Mi familia, que primero cambia el estudiante
/// activo y luego necesita que AdminHome salte a la pestaña de
/// Estadísticas) — se consume una sola vez y vuelve a null.
final pendingAdminTabProvider = StateProvider<int?>((ref) => null);

/// Estado del código de vinculación (hijo/profesor) por estudiante —
/// SIN autoDispose a propósito: se consulta una sola vez por sesión y
/// queda en cache. Sin esto, cada vez que se entra a "Mi familia" el
/// widget de la tarjeta se recreaba y el botón mostraba "Vincular..."
/// un instante antes de corregirse a "Ver código" (el mismo "salto"
/// que ya se arregló en Ajustes). Invalidar manualmente
/// (ref.invalidate) después de generar/regenerar un código.
final linkCodeStatusProvider =
    FutureProvider.family<LinkCodeStatus, String>((ref, studentId) {
  return FamilyRepository.instance.checkLinkCodeStatus(studentId);
});
