import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:edutrack_family/core/config/desktop_oauth_config.dart';

// ═══════════════════════════════════════════════════════════════
// DESKTOP GOOGLE SIGN-IN — EduTrack Family 2.0 (Windows/Linux)
// Login de Google vía navegador del sistema + servidor local
// (loopback) con PKCE. El navegador abre, el usuario inicia sesión
// con Google, y un servidor HTTP local efímero captura el redirect
// y completa el intercambio de tokens (incluye el "client secret"
// del cliente OAuth tipo Desktop — ver core/config/
// desktop_oauth_config.dart para por qué eso es seguro aquí).
// ═══════════════════════════════════════════════════════════════

class GoogleAuthResult {
  final String idToken;
  final String redirectUri;
  const GoogleAuthResult({required this.idToken, required this.redirectUri});
}

class DesktopGoogleSignInException implements Exception {
  final String message;
  DesktopGoogleSignInException(this.message);
  @override
  String toString() => message;
}

class DesktopGoogleSignIn {
  DesktopGoogleSignIn._();
  static final DesktopGoogleSignIn instance = DesktopGoogleSignIn._();

  /// null = cancelado por el usuario o timeout (25s).
  Future<GoogleAuthResult?> signIn() async {
    if (!DesktopOAuthConfig.isConfigured) {
      throw DesktopGoogleSignInException(
        'El login de Google en escritorio no está configurado todavía '
        '(falta el OAuth client "Desktop app" — ver core/config/desktop_oauth_config.dart). '
        'Usa correo y contraseña mientras tanto.',
      );
    }

    final verifier = _randomVerifier();
    final challenge = _codeChallenge(verifier);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirectUri = 'http://127.0.0.1:${server.port}';

    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': DesktopOAuthConfig.clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'openid email profile',
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'access_type': 'offline',
    });

    final codeCompleter = Completer<String?>();
    final sub = server.listen((request) => _handleRedirect(request, codeCompleter));

    try {
      final launched = await launchUrl(authUri, mode: LaunchMode.externalApplication);
      if (!launched) return null;

      String? code;
      try {
        // 25s: si el navegador no completa el login de Google en ese
        // tiempo (ventana cerrada sin terminar, cuenta con problemas,
        // el usuario se distrajo, etc.), se cancela solo — sin esto,
        // el botón de Google quedaba "cargando" hasta 3 minutos antes
        // de poder tocarlo de nuevo.
        code = await codeCompleter.future.timeout(const Duration(seconds: 25));
      } on TimeoutException {
        code = null;
      }
      if (code == null) return null;

      final idToken = await _exchangeCode(code, verifier, redirectUri);
      if (idToken == null) return null;
      return GoogleAuthResult(idToken: idToken, redirectUri: redirectUri);
    } finally {
      await sub.cancel();
      await server.close(force: true);
    }
  }

  Future<void> _handleRedirect(HttpRequest request, Completer<String?> completer) async {
    final code = request.uri.queryParameters['code'];
    final error = request.uri.queryParameters['error'];
    request.response.headers.contentType = ContentType.html;
    request.response.write(_closeTabHtml(success: code != null && error == null));
    await request.response.close();
    if (!completer.isCompleted) {
      completer.complete(error != null ? null : code);
    }
  }

  Future<String?> _exchangeCode(String code, String verifier, String redirectUri) async {
    final res = await http.post(
      Uri.parse('https://oauth2.googleapis.com/token'),
      body: {
        'client_id': DesktopOAuthConfig.clientId,
        'client_secret': DesktopOAuthConfig.clientSecret,
        'code': code,
        'code_verifier': verifier,
        'grant_type': 'authorization_code',
        'redirect_uri': redirectUri,
      },
    );
    if (res.statusCode >= 400) {
      debugPrint('[GoogleSignIn] Token exchange falló (${res.statusCode}): ${res.body}');
      return null;
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['id_token'] as String?;
  }

  String _randomVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(64, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _closeTabHtml({required bool success}) => '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>EduTrack Family</title></head>
<body style="font-family:sans-serif;text-align:center;padding-top:80px;">
<h2>${success ? 'Inicio de sesión completado ✓' : 'No se pudo iniciar sesión'}</h2>
<p>Puedes cerrar esta pestaña y volver a EduTrack Family.</p>
</body></html>''';
}
