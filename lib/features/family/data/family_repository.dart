import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/data/local/repositories/student_repository.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/services/api_client.dart';

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

  /// Genera un código de vinculación vía el backend (Cloudflare Worker).
  /// kind: 'child-device' (dispositivo del hijo) | 'teacher' (profesor)
  Future<LinkCodeResult> generateLinkCode({
    required String studentId,
    required String kind,
  }) async {
    try {
      final result = await ApiClient.instance.call('/create-link-code', {
        'studentId': studentId,
        'kind': kind,
      });
      return LinkCodeResult.success(result['code'] as String);
    } on ApiException catch (e) {
      debugPrint('[Family] createLinkCode: $e');
      return LinkCodeResult.fail(e.message);
    } catch (e) {
      return const LinkCodeResult.fail('Error de conexión.');
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
}
