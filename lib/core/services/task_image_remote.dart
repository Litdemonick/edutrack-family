import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:edutrack_family/core/config/api_config.dart';
import 'package:edutrack_family/features/auth/data/firebase_auth_repository.dart';

// ═══════════════════════════════════════════════════════════════
// TASK IMAGE REMOTE — EduTrack Family 2.0
// Sube/baja fotos de evidencia y referencia de tareas vía el Worker
// de Cloudflare (R2), no Firebase Storage (nunca se activó en la
// consola del proyecto — por eso las imágenes de referencia/
// evidencia nunca llegaban a otros dispositivos, solo quedaban en el
// que las tomó). Mismo patrón que ProfilePhotoRemote: un solo HTTP
// client cross-platform, Android/iOS/Windows/Linux usan el mismo
// código.
// ═══════════════════════════════════════════════════════════════

class TaskImageRemote {
  TaskImageRemote._();
  static final TaskImageRemote instance = TaskImageRemote._();

  Future<Map<String, String>?> _authHeader() async {
    final token = await FirebaseAuthRepository.instance.currentIdToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  /// Sube [bytes] con el nombre [name] (ej. "evidence_0.jpg"). El
  /// servidor valida que evidencia solo la suba el propio hijo, y
  /// referencia el padre/tutor o profesor. [version] (opcional, solo
  /// evidencia): sube a una carpeta propia de ese envío en vez de
  /// sobrescribir el anterior — ver EvidenceImageService.
  Future<bool> upload({
    required String studentId,
    required String taskId,
    required String kind,
    required String name,
    required Uint8List bytes,
    String? version,
  }) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return false;
      final uri = Uri.parse('${ApiConfig.baseUrl}/upload-task-image').replace(
        queryParameters: {
          'studentId': studentId,
          'taskId': taskId,
          'kind': kind,
          'name': name,
          if (version != null) 'version': version,
        },
      );
      final res = await http.post(
        uri,
        headers: {...authHeader, 'Content-Type': 'image/jpeg'},
        body: bytes,
      );
      if (res.statusCode >= 400) {
        debugPrint('[TaskImageRemote] ✗ upload: ${res.statusCode} ${res.body}');
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[TaskImageRemote] ✗ upload: $e');
      return false;
    }
  }

  /// Nombres de archivo (ej. ["evidence_0.jpg", "evidence_1.jpg"])
  /// que ya existen para esa tarea/tipo.
  Future<List<String>> listNames({
    required String studentId,
    required String taskId,
    required String kind,
    String? version,
  }) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return const [];
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/list-task-images'),
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': studentId,
          'taskId': taskId,
          'kind': kind,
          if (version != null) 'version': version,
        }),
      );
      if (res.statusCode >= 400) {
        debugPrint('[TaskImageRemote] ✗ list: ${res.statusCode} ${res.body}');
        return const [];
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return (decoded['names'] as List? ?? []).cast<String>();
    } catch (e) {
      debugPrint('[TaskImageRemote] ✗ list: $e');
      return const [];
    }
  }

  Future<Uint8List?> download({
    required String studentId,
    required String taskId,
    required String kind,
    required String name,
    String? version,
  }) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return null;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/get-task-image'),
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'studentId': studentId,
          'taskId': taskId,
          'kind': kind,
          'name': name,
          if (version != null) 'version': version,
        }),
      );
      if (res.statusCode == 404) return null;
      if (res.statusCode >= 400) {
        debugPrint('[TaskImageRemote] ✗ download: ${res.statusCode} ${res.body}');
        return null;
      }
      return res.bodyBytes;
    } catch (e) {
      debugPrint('[TaskImageRemote] ✗ download: $e');
      return null;
    }
  }

  /// Borra TODAS las imágenes de ese tipo para esa tarea (re-subida
  /// limpia — evita acumular versiones viejas de la misma tarea).
  Future<void> deleteAll({
    required String studentId,
    required String taskId,
    required String kind,
  }) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/delete-task-images'),
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'studentId': studentId, 'taskId': taskId, 'kind': kind}),
      );
      // http.post no lanza por códigos 4xx/5xx (solo por fallos de
      // red) — sin este chequeo, un 403 del Worker (ej. permiso
      // insuficiente) quedaba en silencio total: sin excepción, sin
      // log, y las carpetas de R2 nunca se borraban sin que nada lo
      // avisara.
      if (res.statusCode >= 400) {
        debugPrint('[TaskImageRemote] ✗ deleteAll: ${res.statusCode} ${res.body}');
      }
    } catch (e) {
      debugPrint('[TaskImageRemote] ✗ deleteAll: $e');
    }
  }
}
