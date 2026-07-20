import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/rest/firestore_rest_client.dart';
import 'package:edutrack_family/core/firebase/rest/identity_toolkit_client.dart';
import 'package:edutrack_family/core/firebase/rest/desktop_google_signin.dart';
import 'package:edutrack_family/core/services/api_client.dart';
import 'package:edutrack_family/features/auth/data/auth_gateway.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// DESKTOP AUTH SESSION — EduTrack Family 2.0 (Windows/Linux)
// Implementación de AuthGateway sin firebase_auth: Identity Toolkit
// REST + refresh token guardado en flutter_secure_storage (DPAPI
// en Windows, libsecret en Linux) + refresco automático ~5 min
// antes de expirar, igual al comportamiento del SDK nativo.
// ═══════════════════════════════════════════════════════════════

class DesktopAuthSession implements AuthGateway {
  DesktopAuthSession() {
    _hydrated = _hydrate();
  }

  /// signInAnonymously() decide si crear una cuenta anónima nueva
  /// mirando `_current == null` — sin esperar esto primero, una
  /// llamada rápida (p. ej. tocar "Entrar" en la pantalla de código de
  /// estudiante apenas abre la app) corría antes de que _hydrate()
  /// restaurara la sesión real desde el storage, veía _current==null
  /// por la carrera y creaba+persistía una cuenta anónima nueva —
  /// pisando el refresh token de la sesión real ya guardada. Ese fue
  /// el bug: la próxima vez que abrías la app, se restauraba esa
  /// cuenta anónima huérfana (sin rol) en vez de la tuya.
  late final Future<void> _hydrated;

  static const _storage = FlutterSecureStorage();
  static const _kRefreshToken = 'edutrack_refresh_token';
  static const _kProviders = 'edutrack_providers';

  final _itc = IdentityToolkitClient.instance;
  final _firestore = FirestoreRestClient.instance;

  String? _idToken;
  DateTime? _expiresAt;
  AuthUser? _current;
  Timer? _refreshTimer;
  List<String> _providerIds = [];

  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> get userChanges async* {
    yield _current;
    yield* _controller.stream;
  }

  Future<void> _hydrate() async {
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return;
    try {
      final providersJson = await _storage.read(key: _kProviders);
      _providerIds = providersJson != null
          ? (jsonDecode(providersJson) as List).cast<String>()
          : [];
      final session = await _itc.refresh(refreshToken);
      // Sin _providerIds.isEmpty acá, una sesión anónima restaurada
      // (p. ej. la que quedó huérfana del bug de la carrera de más
      // arriba) perdía la marca isAnonymous — _applySession() la pone
      // en false por default — y quedaba tratada como una cuenta real
      // sin rol: needsProfileCompletion se encendía y la app pedía
      // "elegir rol" en cada arranque en vez de ignorarla como hace
      // _onUserChanged() con toda sesión anónima recién creada.
      await _applySession(
        session,
        persistRefreshToken: true,
        isAnonymous: _providerIds.isEmpty,
      );
    } catch (e) {
      AppLog.d('[DesktopAuth] No se pudo restaurar la sesión: $e');
      await _storage.delete(key: _kRefreshToken);
    }
  }

  Future<void> _applySession(
    IdentityToolkitSession session, {
    required bool persistRefreshToken,
    bool emitUser = true,
    bool isAnonymous = false,
  }) async {
    _idToken = session.idToken;
    _expiresAt = session.expiresAt;
    if (persistRefreshToken) {
      await _storage.write(key: _kRefreshToken, value: session.refreshToken);
    }
    _scheduleRefresh();

    if (emitUser) {
      _current = AuthUser(
        uid: session.localId,
        email: session.email,
        displayName: session.displayName,
        photoUrl: session.photoUrl,
        emailVerified: _current?.uid == session.localId ? _current!.emailVerified : false,
        isAnonymous: isAnonymous,
        providerIds: _providerIds,
      );
      _controller.add(_current);
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    final expiresAt = _expiresAt;
    if (expiresAt == null) return;
    final delay = expiresAt.difference(DateTime.now()) - const Duration(minutes: 5);
    _refreshTimer = Timer(delay.isNegative ? Duration.zero : delay, () async {
      final refreshToken = await _storage.read(key: _kRefreshToken);
      if (refreshToken == null) return;
      try {
        final session = await _itc.refresh(refreshToken);
        await _applySession(session, persistRefreshToken: true, emitUser: false);
      } catch (e) {
        AppLog.d('[DesktopAuth] Refresh falló: $e');
        // El refresh token queda inválido cuando la contraseña se
        // cambió por el enlace del correo (Firebase revoca las
        // sesiones existentes por seguridad) — sin esto la app se
        // quedaba "conectada" con un token muerto en vez de pedir
        // iniciar sesión de nuevo con la contraseña nueva.
        await _forceSignOutOnInvalidToken();
      }
    });
  }

  @override
  Future<String?> currentIdToken() async {
    if (_idToken == null) return null;
    final expiresAt = _expiresAt;
    if (expiresAt != null && expiresAt.difference(DateTime.now()) < const Duration(seconds: 60)) {
      final refreshToken = await _storage.read(key: _kRefreshToken);
      if (refreshToken != null) {
        try {
          final session = await _itc.refresh(refreshToken);
          await _applySession(session, persistRefreshToken: true, emitUser: false);
        } catch (e) {
          AppLog.d('[DesktopAuth] Refresh falló en currentIdToken: $e');
          await _forceSignOutOnInvalidToken();
          return null;
        }
      }
    }
    return _idToken;
  }

  /// Cierra la sesión localmente cuando el refresh token ya no sirve
  /// (contraseña cambiada por correo, revocación manual, etc.) — el
  /// router detecta state==null y manda a /login para que inicie
  /// sesión de nuevo con la contraseña nueva.
  Future<void> _forceSignOutOnInvalidToken() async {
    _refreshTimer?.cancel();
    _idToken = null;
    _expiresAt = null;
    _current = null;
    _providerIds = [];
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kProviders);
    _controller.add(null);
  }

  Future<void> _saveProviders(List<String> providers) async {
    _providerIds = providers;
    await _storage.write(key: _kProviders, value: jsonEncode(providers));
  }

  Future<void> _writeUserDoc({
    required String uid,
    required String displayName,
    required UserRole role,
    required int dobYear,
    required String? email,
    required List<String> providers,
  }) async {
    await _firestore.patchDoc('users/$uid', {
      'role': role.name,
      'displayName': displayName,
      'email': email,
      'dobYear': dobYear,
      'providers': providers,
    });
    try {
      await ApiClient.instance.call('/register-role', {'role': role.name});
    } catch (e) {
      AppLog.d('[DesktopAuth] registerRole no disponible (se reintenta luego): $e');
    }
  }

  @override
  Future<AuthResult> registerAdult({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required int dobYear,
  }) async {
    assert(role == UserRole.parent || role == UserRole.teacher);
    try {
      final session = await _itc.signUp(email: email.trim(), password: password);
      // _saveProviders ANTES de _applySession: _applySession construye
      // el AuthUser cacheado (_current) leyendo _providerIds en ese
      // instante — si se llama antes de fijarlo, _current.providerIds
      // queda en [] para siempre (nada lo actualiza después), por lo
      // que hasPasswordProvider da false y el router se salta por
      // completo la verificación de correo. signInWithEmail/Google ya
      // seguían el orden correcto; aquí estaba invertido.
      await _saveProviders(['password']);
      await _applySession(session, persistRefreshToken: true);
      await _writeUserDoc(
        uid: session.localId,
        displayName: displayName.trim(),
        role: role,
        dobYear: dobYear,
        email: email.trim(),
        providers: ['password'],
      );
      await _itc.sendEmailVerification(session.idToken);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    } catch (e) {
      AppLog.d('[DesktopAuth] registerAdult: $e');
      return const AuthResult.fail('No se pudo crear la cuenta. Intenta de nuevo.');
    }
  }

  @override
  Future<AuthResult> completeProfile({
    required UserRole role,
    required int dobYear,
    String? displayName,
  }) async {
    final user = _current;
    if (user == null) return const AuthResult.fail('Sesión no válida');
    try {
      await _writeUserDoc(
        uid: user.uid,
        displayName: displayName ?? user.displayName ?? '',
        role: role,
        dobYear: dobYear,
        email: user.email,
        providers: _providerIds,
      );
      return const AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (e) {
      AppLog.d('[DesktopAuth] completeProfile: $e');
      return const AuthResult.fail('No se pudo completar el perfil.');
    }
  }

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final session = await _itc.signInWithPassword(email: email.trim(), password: password);
      await _saveProviders(const ['password']);
      await _applySession(session, persistRefreshToken: true);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleResult = await DesktopGoogleSignIn.instance.signIn();
      if (googleResult == null) {
        return const AuthResult.fail('Inicio con Google cancelado.');
      }
      final session = await _itc.signInWithGoogleIdToken(
        googleIdToken: googleResult.idToken,
        requestUri: googleResult.redirectUri,
      );
      await _saveProviders(const ['google.com']);
      await _applySession(session, persistRefreshToken: true);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    } catch (e) {
      AppLog.d('[DesktopAuth] Google: $e');
      return const AuthResult.fail('No se pudo iniciar con Google.');
    }
  }

  @override
  Future<AuthResult> linkWithGoogle() async {
    final user = _current;
    if (user == null) return const AuthResult.fail('Sesión no válida');
    // Identity Toolkit soporta vincular vía signInWithIdp con
    // idToken del usuario actual en el body (linkea en vez de crear
    // cuenta nueva cuando ya hay sesión). Reutiliza el mismo flujo
    // de navegador; simplificado a "sign-in" ya que en la práctica
    // el email/password ya fue el método principal en desktop.
    return signInWithGoogle();
  }

  @override
  Future<AuthResult> signInWithCustomToken(String token) async {
    try {
      final session = await _itc.signInWithCustomToken(token);
      // Sin esto, _providerIds se quedaba en [] (heredado del bootstrap
      // anónimo previo al canje de código) — _hydrate() usa una lista
      // vacía como señal de "sesión anónima" y, tras un hot restart o
      // reinicio de la app, terminaba ignorando la sesión REAL del
      // estudiante como si fuera la anónima huérfana. Por esto Windows
      // no mantenía la sesión del estudiante entre reinicios.
      await _saveProviders(const ['custom']);
      await _applySession(session, persistRefreshToken: true);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      AppLog.d('[DesktopAuth] signInWithCustomToken: ${e.code} — ${e.message}');
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    } catch (e) {
      AppLog.d('[DesktopAuth] signInWithCustomToken: $e');
      return const AuthResult.fail('Error de conexión. Revisa tu internet.');
    }
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    await _hydrated;
    if (_current != null) return const AuthResult.success();
    try {
      final session = await _itc.signUpAnonymous();
      _providerIds = [];
      await _storage.write(key: _kProviders, value: jsonEncode(_providerIds));
      await _applySession(session, persistRefreshToken: true, isAnonymous: true);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    } catch (e) {
      // Sin este log, cualquier falla (red, TLS, flutter_secure_storage
      // sin Credential Manager disponible, etc.) se veía siempre como
      // el mismo "revisa tu internet" genérico, sin forma de saber cuál
      // de las tres fue.
      AppLog.d('[DesktopAuth] signInAnonymously: $e');
      return const AuthResult.fail('Error de conexión. Revisa tu internet.');
    }
  }

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _itc.sendPasswordResetEmail(email.trim());
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    }
  }

  @override
  Future<void> resendVerification() async {
    final token = await currentIdToken();
    if (token == null) return;
    await _itc.sendEmailVerification(token);
  }

  @override
  Future<bool> reloadAndCheckVerified() async {
    final token = await currentIdToken();
    if (token == null) return false;
    try {
      final profile = await _itc.lookup(token);
      final verified = profile['emailVerified'] as bool? ?? false;
      // Sin esto, refresh() → _onUserChanged → loadProfile() vuelve a
      // leer _current.emailVerified (todavía false, nunca actualizado
      // aquí) y produce un SessionUser no verificado para siempre —
      // aunque este mismo lookup ya haya confirmado que sí se
      // verificó. El usuario se queda atascado en /verify-email
      // incluso después de verificar el correo de verdad.
      if (verified && _current != null) {
        _current = _current!.copyWithVerified(true);
      }
      return verified;
    } catch (e) {
      AppLog.d('[DesktopAuth] reloadAndCheckVerified falló: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _current;
    if (user == null || user.email == null) {
      return const AuthResult.fail('Sesión no válida');
    }
    try {
      // Reautenticación: Identity Toolkit no tiene un endpoint de
      // "reauthenticate" separado — un signIn fresco cumple la misma
      // función de confirmar la contraseña actual antes de cambiarla.
      await _itc.signInWithPassword(email: user.email!, password: currentPassword);
      final session = await _itc.changePassword(idToken: _idToken!, newPassword: newPassword);
      await _applySession(session, persistRefreshToken: true, emitUser: false);
      return const AuthResult.success();
    } on IdentityToolkitException catch (e) {
      return AuthResult.fail(IdentityToolkitClient.mapError(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    _refreshTimer?.cancel();
    _idToken = null;
    _expiresAt = null;
    _current = null;
    _providerIds = [];
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kProviders);
    _controller.add(null);
  }

  @override
  Future<void> validateSession() async {
    if (_current == null) return;
    final refreshToken = await _storage.read(key: _kRefreshToken);
    if (refreshToken == null) return;
    try {
      final session = await _itc.refresh(refreshToken);
      await _applySession(session, persistRefreshToken: true, emitUser: false);
    } catch (e) {
      // Refresh token inválido — normalmente porque la contraseña se
      // cambió por el enlace del correo (Firebase la revoca de
      // inmediato). El idToken viejo seguiría "funcionando" un rato
      // más por su cuenta, pero forzar el refresh aquí detecta el
      // cambio ya, en vez de esperar a que expire solo.
      AppLog.d('[DesktopAuth] validateSession: sesión inválida ($e)');
      await _forceSignOutOnInvalidToken();
    }
  }

  // No hay try/catch envolvente a propósito: si getDoc() falla (red,
  // cuota de Firestore, etc.), esta función DEBE lanzar en vez de
  // devolver null — null aquí significa específicamente "no tiene
  // perfil, hay que completar el registro", y el llamador
  // (auth_provider._onUserChanged) lo usa para decidir si manda a la
  // pantalla de onboarding. Si un error transitorio se tragara como
  // null, un usuario YA registrado terminaría viendo "elige tu rol"
  // de nuevo solo porque la lectura falló un instante (bug real
  // encontrado en vivo: un 429 de cuota en Firestore mandaba a
  // cualquiera de vuelta a completar perfil).
  @override
  Future<SessionUser?> loadProfile(AuthUser user) async {
    final roleName = _decodeRoleClaim(_idToken);

    // Un estudiante (uid == studentId) no tiene doc en users/{uid}
    // — su nombre (el que le puso el padre/tutor) vive en
    // students/{uid}. Sin este caso especial, displayName quedaba
    // vacío ("Hola, ") porque el custom token tampoco trae nombre.
    if (roleName == 'student') {
      final studentDoc = await _firestore.getDoc(FirestorePaths.student(user.uid));
      final resolved = SessionUser(
        uid: user.uid,
        role: UserRole.student,
        displayName: studentDoc?.data['name'] as String? ?? '',
        photoUrl: user.photoUrl,
      );
      _current = user;
      return resolved;
    }

    final doc = await _firestore.getDoc('users/${user.uid}');
    final data = doc?.data;

    if (roleName == null && data == null) return null; // perfil incompleto (de verdad, no error)

    // emailVerified se consulta de verdad en cada carga (no se
    // confía en user.emailVerified, que viene de _current — recién
    // reiniciada la app _current siempre arranca en false hasta que
    // algo lo corrija, así que sin esto la pantalla de verificación
    // reaparecía en cada reinicio aunque la cuenta ya estuviera
    // verificada, hasta que el sondeo de VerifyEmailScreen la
    // "arreglaba" unos segundos después.
    var emailVerified = user.emailVerified;
    if (!emailVerified && _idToken != null) {
      try {
        final profile = await _itc.lookup(_idToken!);
        emailVerified = profile['emailVerified'] as bool? ?? false;
      } catch (_) {
        // Sin red o token inválido: se queda con el valor conocido:
        // no empeora nada, solo no lo confirma en este intento.
      }
    }

    final base = data != null
        ? SessionUser.fromFirestore(data, user.uid)
        : SessionUser(
            uid: user.uid,
            role: UserRoleExt.fromName(roleName),
            displayName: user.displayName ?? '',
          );

    final resolved = base.copyWith(
      role: roleName != null ? UserRoleExt.fromName(roleName) : base.role,
      displayName: base.displayName.isNotEmpty ? base.displayName : (user.displayName ?? ''),
      email: user.email ?? base.email,
      emailVerified: emailVerified,
      photoUrl: user.photoUrl ?? base.photoUrl,
      providers: user.providerIds,
    );
    _current = user.copyWithVerified(emailVerified);
    return resolved;
  }

  String? _decodeRoleClaim(String? idToken) {
    if (idToken == null) return null;
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      return payload['role'] as String?;
    } catch (_) {
      return null;
    }
  }
}

extension on AuthUser {
  /// Copia con emailVerified actualizado — AuthUser no expone
  /// setters; loadProfile es el único lugar que refina ese campo
  /// tras leer el perfil (emailVerified real solo se conoce después
  /// de un lookup, no en el idToken del sign-in original).
  AuthUser copyWithVerified(bool emailVerified) => AuthUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        emailVerified: emailVerified,
        isAnonymous: isAnonymous,
        providerIds: providerIds,
      );
}
