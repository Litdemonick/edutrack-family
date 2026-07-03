import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/data/local/repositories/student_repository.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';

// ═══════════════════════════════════════════════════════════════
// FAMILY REPOSITORY — EduTrack Family 2.0
// Crear/editar perfiles de hijos y generar códigos de vinculación.
// ═══════════════════════════════════════════════════════════════

class LinkCodeResult {
  final String? code;
  final String? error;
  const LinkCodeResult.success(this.code) : error = null;
  const LinkCodeResult.fail(this.error) : code = null;
}

class FamilyRepository {
  FamilyRepository._();
  static final FamilyRepository instance = FamilyRepository._();

  /// Crea un perfil de hijo. El id generado será también el uid del
  /// niño cuando canjee su código (custom token).
  Future<StudentProfile> createChild({
    required String parentUid,
    required String name,
    String? grade,
    int? avatarColor,
  }) async {
    final student = StudentProfile(
      id: const Uuid().v4(),
      name: name.trim(),
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

  /// Genera un código de vinculación vía Cloud Function.
  /// kind: 'child-device' (dispositivo del hijo) | 'teacher' (profesor)
  Future<LinkCodeResult> generateLinkCode({
    required String studentId,
    required String kind,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('createLinkCode')
          .call<Map<String, dynamic>>({
        'studentId': studentId,
        'kind': kind,
      });
      return LinkCodeResult.success(result.data['code'] as String);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[Family] createLinkCode: ${e.code} ${e.message}');
      return LinkCodeResult.fail(
          e.message ?? 'No se pudo generar el código.');
    } catch (e) {
      return const LinkCodeResult.fail('Error de conexión.');
    }
  }

  /// Profesor canjea un código de vinculación de estudiante.
  Future<LinkCodeResult> redeemTeacherCode(String code) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemLinkCode')
          .call<Map<String, dynamic>>({'code': code.toUpperCase().trim()});
      return LinkCodeResult.success(result.data['studentId'] as String?);
    } on FirebaseFunctionsException catch (e) {
      return LinkCodeResult.fail(switch (e.code) {
        'not-found' => 'Código no válido.',
        'failed-precondition' => 'El código expiró o ya fue usado.',
        'permission-denied' => e.message ?? 'Código no válido para tu rol.',
        _ => e.message ?? 'No se pudo canjear el código.',
      });
    } catch (_) {
      return const LinkCodeResult.fail('Error de conexión.');
    }
  }
}
