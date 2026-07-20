import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:edutrack_family/features/auth/data/firebase_auth_repository.dart';

import '../config/api_config.dart';

// ═══════════════════════════════════════════════════════════════
// API CLIENT — EduTrack Family 2.0
// Llama al backend en Cloudflare Workers (workers/edutrack-api),
// que reemplaza a las Cloud Functions de Firebase (exigían Blaze).
//
// Cada llamada adjunta el ID token actual en Authorization: Bearer
// <token> — el Worker lo verifica contra el JWKS público de Google
// antes de hacer nada. El token sale de AuthGateway.instance
// (FirebaseAuthRepository.instance), que resuelve a SDK nativo o a
// la sesión REST de escritorio según la plataforma — este cliente
// no distingue cuál es cuál.
// ═══════════════════════════════════════════════════════════════

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  Future<Map<String, dynamic>> call(
    String path,
    Map<String, dynamic> body,
  ) async {
    final idToken = await FirebaseAuthRepository.instance.currentIdToken();
    if (idToken == null) {
      throw ApiException('Sesión no válida', 401);
    }

    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final decoded = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 400) {
      throw ApiException(
        decoded['error'] as String? ?? 'Error de red (${res.statusCode})',
        res.statusCode,
      );
    }
    return decoded;
  }
}
