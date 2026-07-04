import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// ═══════════════════════════════════════════════════════════════
// API CLIENT — EduTrack Family 2.0
// Llama al backend en Cloudflare Workers (workers/edutrack-api),
// que reemplaza a las Cloud Functions de Firebase (exigían Blaze).
//
// Cada llamada adjunta el ID token de Firebase del usuario actual
// en Authorization: Bearer <token> — el Worker lo verifica contra
// el JWKS público de Google antes de hacer nada.
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw ApiException('Sesión no válida', 401);
    }
    final idToken = await user.getIdToken();

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
