import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:edutrack_family/firebase_options.dart';

// ═══════════════════════════════════════════════════════════════
// IDENTITY TOOLKIT CLIENT — EduTrack Family 2.0 (Windows/Linux)
// Llamadas REST directas a Identity Toolkit / Secure Token, para
// plataformas donde firebase_auth no tiene implementación nativa.
// Usa solo la API key pública de Firebase (ya está en git, no es
// secreta) — nunca un client_secret ni la service account.
//
// Referencia de formato: workers/edutrack-api/src/lib/identity.js
// (ese archivo habla con Identity Toolkit vía service account para
// operaciones de admin; este habla vía API key para operaciones de
// usuario final — mismo servicio, endpoints hermanos).
// ═══════════════════════════════════════════════════════════════

class IdentityToolkitException implements Exception {
  final String code;
  final String message;
  IdentityToolkitException(this.code, this.message);
  @override
  String toString() => message;
}

class IdentityToolkitSession {
  final String idToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String localId;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const IdentityToolkitSession({
    required this.idToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.localId,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}

class IdentityToolkitClient {
  IdentityToolkitClient._();
  static final IdentityToolkitClient instance = IdentityToolkitClient._();

  // La key de Android suele quedar restringida en Google Cloud Console
  // a esa app (package name + huella SHA-1) — usarla desde una
  // llamada REST de escritorio la bloquea en el gateway de Google
  // (con una respuesta que ni siquiera es JSON, así que ni se
  // reconoce como error de autenticación). Este cliente SOLO corre en
  // Windows/Linux (ver desktop_auth_session.dart), así que debe usar
  // la key registrada para esa plataforma, no la de Android.
  static final _apiKey = DefaultFirebaseOptions.windows.apiKey;
  static const _identityBase =
      'https://identitytoolkit.googleapis.com/v1/accounts';
  static const _tokenBase = 'https://securetoken.googleapis.com/v1/token';

  Future<Map<String, dynamic>> _post(String method, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$_identityBase:$method?key=$_apiKey'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final code = (decoded['error']?['message'] as String? ?? 'UNKNOWN_ERROR')
          .split(' ')
          .first
          .replaceAll(':', '');
      throw IdentityToolkitException(code, decoded['error']?['message'] as String? ?? code);
    }
    return decoded;
  }

  IdentityToolkitSession _sessionFrom(Map<String, dynamic> json) {
    final idToken = json['idToken'] as String?;
    final refreshToken = json['refreshToken'] as String?;
    // accounts:signInWithCustomToken (VerifyCustomTokenResponse) NUNCA
    // trae localId en el body — a diferencia de signUp/
    // signInWithPassword, que sí lo incluyen. Ahí hay que sacar el uid
    // del propio idToken (claim user_id/sub del JWT), no de la
    // respuesta.
    final localId = json['localId'] as String? ??
        (idToken != null ? _uidFromJwt(idToken) : null);
    if (idToken == null || refreshToken == null || localId == null) {
      // Identity Toolkit puede responder 200 sin estos campos en casos
      // que no son un error HTTP claro — sin esta validación, el cast
      // directo a String reventaba con un TypeError críptico ("Null is
      // not a subtype of String") en vez de un mensaje que dijera qué
      // pasó realmente.
      throw IdentityToolkitException(
        'INVALID_RESPONSE',
        'Respuesta incompleta de Identity Toolkit: $json',
      );
    }
    final expiresIn = int.tryParse(json['expiresIn']?.toString() ?? '3600') ?? 3600;
    return IdentityToolkitSession(
      idToken: idToken,
      refreshToken: refreshToken,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      localId: localId,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  /// Decodifica el payload de un JWT (sin verificar firma — ya viene
  /// de Identity Toolkit, que sí la verificó) y devuelve user_id/sub.
  String? _uidFromJwt(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      return payload['user_id'] as String? ?? payload['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<IdentityToolkitSession> signUp({
    required String email,
    required String password,
  }) async {
    final json = await _post('signUp', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return _sessionFrom(json);
  }

  /// Sesión anónima: mismo endpoint que signUp, sin email/password —
  /// Identity Toolkit crea un usuario nuevo sin credenciales. Sirve
  /// de bootstrap para poder llamar al Worker antes de tener una
  /// identidad real (ej. el niño canjeando su código de vinculación).
  Future<IdentityToolkitSession> signUpAnonymous() async {
    final json = await _post('signUp', {'returnSecureToken': true});
    return _sessionFrom(json);
  }

  Future<IdentityToolkitSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final json = await _post('signInWithPassword', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return _sessionFrom(json);
  }

  /// Intercambia un id_token de Google (obtenido vía el flujo de
  /// navegador + PKCE) por una sesión de Firebase.
  Future<IdentityToolkitSession> signInWithGoogleIdToken({
    required String googleIdToken,
    required String requestUri,
  }) async {
    final json = await _post('signInWithIdp', {
      'postBody': 'id_token=$googleIdToken&providerId=google.com',
      'requestUri': requestUri,
      'returnSecureToken': true,
      'returnIdpCredential': true,
    });
    return _sessionFrom(json);
  }

  Future<IdentityToolkitSession> signInWithCustomToken(String token) async {
    final json = await _post('signInWithCustomToken', {
      'token': token,
      'returnSecureToken': true,
    });
    return _sessionFrom(json);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _post('sendOobCode', {
      'requestType': 'PASSWORD_RESET',
      'email': email,
    });
  }

  Future<void> sendEmailVerification(String idToken) async {
    await _post('sendOobCode', {
      'requestType': 'VERIFY_EMAIL',
      'idToken': idToken,
    });
  }

  /// Perfil actual + emailVerified + custom claims (decodificados del
  /// propio idToken, Identity Toolkit no los expone en :lookup).
  Future<Map<String, dynamic>> lookup(String idToken) async {
    final json = await _post('lookup', {'idToken': idToken});
    final users = json['users'] as List?;
    if (users == null || users.isEmpty) {
      throw IdentityToolkitException('USER_NOT_FOUND', 'Usuario no encontrado.');
    }
    return users.first as Map<String, dynamic>;
  }

  Future<IdentityToolkitSession> changePassword({
    required String idToken,
    required String newPassword,
  }) async {
    final json = await _post('update', {
      'idToken': idToken,
      'password': newPassword,
      'returnSecureToken': true,
    });
    return _sessionFrom(json);
  }

  Future<IdentityToolkitSession> refresh(String refreshToken) async {
    final res = await http.post(
      Uri.parse('$_tokenBase?key=$_apiKey'),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final code = (decoded['error']?['message'] as String? ?? 'TOKEN_EXPIRED')
          .split(' ')
          .first;
      throw IdentityToolkitException(code, 'Sesión expirada, inicia sesión de nuevo.');
    }
    final expiresIn = int.tryParse(decoded['expires_in']?.toString() ?? '3600') ?? 3600;
    return IdentityToolkitSession(
      idToken: decoded['id_token'] as String,
      refreshToken: decoded['refresh_token'] as String,
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      localId: decoded['user_id'] as String,
    );
  }

  /// Traduce los códigos de error de Identity Toolkit REST a los
  /// mismos mensajes en español que ya usa mapAuthError() para el
  /// SDK nativo (firebase_auth_repository.dart) — misma UX.
  static String mapError(String code) {
    switch (code) {
      case 'EMAIL_NOT_FOUND':
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'EMAIL_EXISTS':
        return 'Ya existe una cuenta con ese correo.';
      case 'WEAK_PASSWORD':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'USER_DISABLED':
        return 'Esta cuenta fue deshabilitada.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Demasiados intentos. Espera un momento.';
      case 'INVALID_EMAIL':
        return 'El correo no es válido.';
      case 'CREDENTIAL_TOO_OLD_LOGIN_AGAIN':
        return 'Por seguridad, vuelve a iniciar sesión.';
      default:
        return 'Error de autenticación ($code).';
    }
  }
}
