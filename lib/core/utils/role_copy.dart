import 'package:edutrack_family/core/data/local/models/app_user_model.dart';

// ═══════════════════════════════════════════════════════════════
// ROLE COPY — EduTrack Family
// Textos que cambian según el rol del adulto (padre/tutor vs.
// profesor) para que un profesor nunca lea "tu hijo/a" ni acciones
// que no puede realizar (crear/editar el perfil del estudiante).
// ═══════════════════════════════════════════════════════════════

class RoleCopy {
  const RoleCopy._();

  static String linkedPersonWord(UserRole role) =>
      role == UserRole.teacher ? 'estudiante' : 'hijo/a';

  static String dashboardFallbackName(UserRole role) =>
      role == UserRole.teacher ? 'tu estudiante' : 'tu hijo/a';

  static String noStudentsTitle(UserRole role) => role == UserRole.teacher
      ? 'Sin estudiantes vinculados'
      : 'Aún no tienes hijos vinculados';

  static String noStudentsSubtitle(UserRole role) => role == UserRole.teacher
      ? 'Pide al padre/tutor un código de vinculación de profesor.'
      : 'Agrega el perfil de tu hijo/a para ver sus estadísticas aquí.';

  static String noStudentsActionLabel(UserRole role) =>
      role == UserRole.teacher ? 'Ir a Mis estudiantes' : 'Ir a Mi familia';

  static String familySettingsSubtitle(UserRole role) => role == UserRole.teacher
      ? 'Tus estudiantes vinculados y códigos de vinculación'
      : 'Hijos, códigos de vinculación y profesores';

  /// Cómo el ESTUDIANTE debe referirse al adulto que hizo algo (creó,
  /// editó, eliminó una tarea/evento) — usado en el texto que recibe
  /// el propio estudiante.
  static String actorLabelForStudent(String? actorRole) =>
      actorRole == 'teacher' ? 'tu profesor/a' : 'tu padre/tutor';

  /// Texto para el OTRO adulto vinculado (el que no hizo la acción):
  /// aclara quién fue (por rol) y de qué estudiante se trata, usando
  /// [linkedPersonWord] para decir "hijo/a" o "estudiante" según el
  /// rol de quien RECIBE el aviso.
  static String otherAdultActionText(
    String? actorRole,
    UserRole recipientRole,
    String studentName,
    String action,
  ) {
    final actorLabel = actorRole == 'teacher' ? 'El profesor/a' : 'El padre/tutor';
    final relWord = linkedPersonWord(recipientRole);
    return '$actorLabel de tu $relWord $studentName $action.';
  }

  /// "el profesor/a" / "el padre/tutor" — para aclarar QUIÉN asignó
  /// una tarea/evento dentro de un aviso dirigido a CUALQUIER adulto
  /// (ej. "Evidencia recibida" en Revisión, donde interesa saber de
  /// quién era la tarea sin importar el rol de quien lo lee). Null si
  /// no hay rol registrado (tareas viejas sin assignedByRole).
  static String? assignedByLabel(String? assignedByRole) {
    if (assignedByRole == 'teacher') return 'el profesor/a';
    if (assignedByRole == 'parent') return 'el padre/tutor';
    return null;
  }
}
