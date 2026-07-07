import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'package:edutrack_family/core/config/api_config.dart';
import 'package:edutrack_family/features/auth/data/firebase_auth_repository.dart';

// ═══════════════════════════════════════════════════════════════
// PROFILE PHOTO REMOTE — EduTrack Family 2.0
// Sube/baja la foto de perfil vía el Worker de Cloudflare (R2), no
// Firebase Storage (nunca se activó en la consola del proyecto).
// HTTP normal — Android/iOS/Windows/Linux usan exactamente el mismo
// código (mismo patrón que TaskImageRemote para fotos de tareas).
// ═══════════════════════════════════════════════════════════════

class ProfilePhotoRemote {
  ProfilePhotoRemote._();
  static final ProfilePhotoRemote instance = ProfilePhotoRemote._();

  Future<Map<String, String>?> _authHeader() async {
    final token = await FirebaseAuthRepository.instance.currentIdToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  /// Sube [bytes] (ya comprimidos a JPEG) como la foto de perfil del
  /// usuario autenticado. El servidor sobreescribe siempre el mismo
  /// objeto (profiles/{uid}/photo.jpg) — nunca se duplica — y además
  /// marca photoUpdatedAt en Firestore (students o users según
  /// corresponda; un estudiante no puede escribir ninguno de los dos
  /// directo, así que ese marcado siempre pasa por acá). Devuelve el
  /// updatedAt que puso el servidor, o null si falló.
  Future<String?> upload(Uint8List bytes) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return null;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/upload-profile-photo'),
        headers: {...authHeader, 'Content-Type': 'image/jpeg'},
        body: bytes,
      );
      if (res.statusCode >= 400) {
        debugPrint('[ProfilePhotoRemote] ✗ upload: ${res.statusCode} ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      return decoded['updatedAt'] as String?;
    } catch (e) {
      debugPrint('[ProfilePhotoRemote] ✗ upload: $e');
      return null;
    }
  }

  /// Descarga la foto de perfil de [uid] (puede ser otro usuario, no
  /// solo el propio). Null si no existe o hay error de red.
  Future<Uint8List?> download(String uid) async {
    try {
      final authHeader = await _authHeader();
      if (authHeader == null) return null;
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/get-profile-photo'),
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid}),
      );
      if (res.statusCode == 404) return null;
      if (res.statusCode >= 400) {
        debugPrint('[ProfilePhotoRemote] ✗ download: ${res.statusCode} ${res.body}');
        return null;
      }
      return res.bodyBytes;
    } catch (e) {
      debugPrint('[ProfilePhotoRemote] ✗ download: $e');
      return null;
    }
  }
}
