import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/data/local/repositories/student_repository.dart';
import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/services/api_client.dart';

// ═══════════════════════════════════════════════════════════════
// FAMILY REPOSITORY — EduTrack Family 2.0
// Crear/editar perfiles de hijos y generar códigos de vinculación.
// ═══════════════════════════════════════════════════════════════

class LinkCodeResult {
  final String? code;
  final String? error;
  final bool permanent;
  const LinkCodeResult.success(this.code, {this.permanent = false}) : error = null;
  const LinkCodeResult.fail(this.error)
      : code = null,
        permanent = false;
}

/// ¿Hay un código activo ahora mismo para este estudiante?
class LinkCodeStatus {
  final bool childActive;
  final bool teacherActive;
  const LinkCodeStatus({required this.childActive, required this.teacherActive});
  const LinkCodeStatus.unknown()
      : childActive = false,
        teacherActive = false;
}

/// Un profesor vinculado a un hijo/a — datos mínimos para mostrar
/// "quién tiene acceso" en la pantalla de profesores vinculados.
class LinkedTeacher {
  final String uid;
  final String? displayName;
  final String? email;
  const LinkedTeacher({required this.uid, this.displayName, this.email});
}

class LinkedTeachersResult {
  final List<LinkedTeacher> teachers;
  final String? error;
  const LinkedTeachersResult.success(this.teachers) : error = null;
  const LinkedTeachersResult.fail(this.error) : teachers = const [];
}

/// Resultado de pedir el correo de confirmación de borrado.
class DeleteConfirmationRequest {
  final String? requestId;
  final String? email;
  final String? error;
  const DeleteConfirmationRequest.success(this.requestId, this.email)
      : error = null;
  const DeleteConfirmationRequest.fail(this.error)
      : requestId = null,
        email = null;
}

class FamilyRepository {
  FamilyRepository._();
  static final FamilyRepository instance = FamilyRepository._();

  /// Crea un perfil de hijo. El id generado será también el uid del
  /// niño cuando canjee su código (custom token).
  Future<StudentProfile> createChild({
    required String parentUid,
    required String name,
    required String cedula,
    String? grade,
    int? avatarColor,
  }) async {
    final student = StudentProfile(
      id: const Uuid().v4(),
      name: name.trim(),
      cedula: cedula.trim(),
      grade: grade?.trim(),
      avatarColor: avatarColor,
      parentIds: [parentUid],
      updatedAt: DateTime.now(),
    );

    // Primero remoto (las reglas exigen parent en parentIds), luego local
    await FirestoreService.instance.upsertStudent(student);
    await StudentRepository.instance.upsert(student);
    return student;
  }

  Future<void> updateChild(StudentProfile student) async {
    final updated = student.copyWith(updatedAt: DateTime.now());
    await FirestoreService.instance.upsertStudent(updated);
    await StudentRepository.instance.upsert(updated);
  }

  /// Pide el correo de confirmación (link que se auto-verifica al
  /// abrirlo) previo a borrar un hijo/a — ver requestId en deleteChild.
  Future<DeleteConfirmationRequest> requestDeleteConfirmation(
      String studentId) async {
    try {
      final result = await ApiClient.instance
          .call('/request-delete-confirmation', {'studentId': studentId});
      return DeleteConfirmationRequest.success(
        result['requestId'] as String,
        result['email'] as String?,
      );
    } on ApiException catch (e) {
      return DeleteConfirmationRequest.fail(e.message);
    } catch (e) {
      return const DeleteConfirmationRequest.fail('Error de conexión.');
    }
  }

  /// ¿Ya se confirmó ese requestId desde el correo? Para hacer polling
  /// mientras se espera a que el padre/tutor abra el link.
  Future<bool> checkDeleteConfirmed(String requestId) async {
    try {
      final result = await ApiClient.instance
          .call('/delete-confirmation-status', {'requestId': requestId});
      return result['confirmed'] as bool? ?? false;
    } catch (e) {
      debugPrint('[Family] checkDeleteConfirmed: $e');
      return false;
    }
  }

  /// Borra el perfil del hijo/a y TODO su subárbol (tareas, eventos,
  /// horario, evidencias, ubicación, zonas, check-ins, códigos de
  /// vinculación) vía el Worker — algunas subcolecciones (ubicación,
  /// check-ins) no se pueden borrar desde el cliente aunque seas el
  /// guardián (storage.rules solo deja escribir esas al propio hijo).
  /// [requestId] debe venir de un requestDeleteConfirmation ya
  /// confirmado por correo — el backend lo exige y rechaza si no.
  /// Devuelve null si salió bien, o un mensaje de error.
  Future<String?> deleteChild(String studentId, {required String requestId}) async {
    try {
      await ApiClient.instance.call(
        '/delete-student',
        {'studentId': studentId, 'requestId': requestId},
      );
    } on ApiException catch (e) {
      debugPrint('[Family] deleteChild: $e');
      return e.message;
    } catch (e) {
      return 'Error de conexión.';
    }

    // El backend ya limpió Firestore/R2 — ahora lo mismo en local.
    // Incluye location_buffer (GPS sin subir aún) y sync_meta/pending_ops
    // (checkpoints y cola offline) — sin esto quedaban huérfanos en el
    // dispositivo aunque el hijo ya no existiera en ningún lado.
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
    return null;
  }

  /// Genera un código de vinculación vía el backend (Cloudflare Worker).
  /// kind: 'child-device' (dispositivo del hijo) | 'teacher' (profesor)
  /// [forceNew]: invalida el código vigente y crea uno nuevo — úsalo
  /// solo para "Regenerar" explícito (ej. sospecha de filtración); sin
  /// esto, reutiliza el código vigente si todavía no venció.
  Future<LinkCodeResult> generateLinkCode({
    required String studentId,
    required String kind,
    bool forceNew = false,
  }) async {
    try {
      final result = await ApiClient.instance.call('/create-link-code', {
        'studentId': studentId,
        'kind': kind,
        if (forceNew) 'forceNew': true,
      });
      return LinkCodeResult.success(
        result['code'] as String,
        permanent: result['permanent'] as bool? ?? false,
      );
    } on ApiException catch (e) {
      debugPrint('[Family] createLinkCode: $e');
      return LinkCodeResult.fail(e.message);
    } catch (e) {
      return const LinkCodeResult.fail('Error de conexión.');
    }
  }

  /// Consulta si ya hay un código activo (hijo/profesor) para este
  /// estudiante — para decidir si el botón dice "Vincular" o "Ver
  /// código", sin crear uno nuevo solo por mostrar la pantalla.
  Future<LinkCodeStatus> checkLinkCodeStatus(String studentId) async {
    try {
      final result = await ApiClient.instance
          .call('/link-code-status', {'studentId': studentId});
      return LinkCodeStatus(
        childActive: result['childActive'] as bool? ?? false,
        teacherActive: result['teacherActive'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('[Family] checkLinkCodeStatus: $e');
      return const LinkCodeStatus.unknown();
    }
  }

  /// ¿Ya hay otro hijo/a (de cualquier familia, no solo la propia)
  /// con esta cédula? Pasa por el Worker porque firestore.rules no
  /// deja al cliente listar students ajenos a los suyos — la única
  /// forma de garantizar unicidad real es consultando con el service
  /// account. [excludeStudentId]: al editar, para no marcarse a sí
  /// mismo como duplicado. Devuelve null si está disponible, o un
  /// mensaje de error si no.
  Future<String?> checkCedulaAvailable({
    required String cedula,
    String? excludeStudentId,
  }) async {
    try {
      final result = await ApiClient.instance.call('/check-cedula', {
        'cedula': cedula.trim(),
        if (excludeStudentId != null) 'excludeStudentId': excludeStudentId,
      });
      final available = result['available'] as bool? ?? true;
      return available ? null : 'Esta cédula ya está registrada.';
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'No se pudo verificar la cédula — revisa tu conexión.';
    }
  }

  /// Profesores actualmente vinculados a este hijo/a (para que el
  /// padre/tutor sepa quién tiene acceso). Pasa por el Worker porque
  /// firestore.rules no deja leer users/{otroUid} directo desde el
  /// cliente (solo el propio uid).
  Future<LinkedTeachersResult> getLinkedTeachers(String studentId) async {
    try {
      final result = await ApiClient.instance
          .call('/linked-teachers', {'studentId': studentId});
      final teachers = (result['teachers'] as List? ?? [])
          .map((t) => LinkedTeacher(
                uid: t['uid'] as String,
                displayName: t['displayName'] as String?,
                email: t['email'] as String?,
              ))
          .toList();
      return LinkedTeachersResult.success(teachers);
    } on ApiException catch (e) {
      debugPrint('[Family] getLinkedTeachers: $e');
      return LinkedTeachersResult.fail(e.message);
    } catch (e) {
      return const LinkedTeachersResult.fail('Error de conexión.');
    }
  }

  /// Profesor canjea un código de vinculación de estudiante.
  Future<LinkCodeResult> redeemTeacherCode(String code) async {
    try {
      final result = await ApiClient.instance.call(
        '/redeem-link-code',
        {'code': code.toUpperCase().trim()},
      );
      return LinkCodeResult.success(result['studentId'] as String?);
    } on ApiException catch (e) {
      return LinkCodeResult.fail(e.message);
    } catch (_) {
      return const LinkCodeResult.fail('Error de conexión.');
    }
  }

  /// Profesor se desvincula por su cuenta de un estudiante (a
  /// diferencia de que el padre/tutor regenere el código y quite a
  /// TODOS los profesores de golpe). Avisa al padre/tutor y al
  /// estudiante. Devuelve null si salió bien, o un mensaje de error.
  Future<String?> leaveStudent(String studentId) async {
    try {
      await ApiClient.instance.call('/leave-student', {'studentId': studentId});
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Error de conexión.';
    }
  }
}
