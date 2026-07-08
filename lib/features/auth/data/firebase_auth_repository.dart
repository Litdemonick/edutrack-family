import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/platform/firebase_backend.dart';
import 'package:edutrack_family/core/firebase/rest/desktop_auth_session.dart';
import 'package:edutrack_family/core/services/api_client.dart';
import 'package:edutrack_family/features/auth/data/auth_gateway.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// FIREBASE AUTH REPOSITORY — EduTrack Family 2.0
// Implementación NATIVA de AuthGateway (Android/iOS/macOS/Web):
//   email+password · Google Sign-In v7 · vinculación de cuentas ·
//   reset · verificación · custom token (dispositivo del niño)
//
// En Windows/Linux, `.instance` resuelve a DesktopAuthSession (REST
// a Identity Toolkit) en vez de esta clase — ver
// core/firebase/platform/firebase_backend.dart. Ningún llamador
// (auth_provider.dart, pantallas) distingue cuál es cuál: ambas
// implementan AuthGateway con la misma firma pública.
//
// El rol vive en un custom claim (lo pone el Worker /register-role)
// y se espeja en users/{uid} para la UI.
// ═══════════════════════════════════════════════════════════════

class FirebaseAuthRepository implements AuthGateway {
  FirebaseAuthRepository._();
  static final AuthGateway instance =
      useDesktopRestBackend ? DesktopAuthSession() : FirebaseAuthRepository._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _googleInitialized = false;

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
      providerIds: user.providerData.map((p) => p.providerId).toList(),
    );
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get userChanges => _auth.userChanges().map(_toAuthUser);

  @override
  Future<String?> currentIdToken() async => _auth.currentUser?.getIdToken();

  // ─────────────────────────────────────────────────────────────
  // REGISTRO DE ADULTO (email + password)
  // ─────────────────────────────────────────────────────────────

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
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());

      await _completeAdultProfile(
        user: user,
        displayName: displayName.trim(),
        role: role,
        dobYear: dobYear,
      );

      await user.sendEmailVerification();
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    } catch (e) {
      AppLog.d('[Auth] registerAdult: $e');
      return const AuthResult.fail('No se pudo crear la cuenta. Intenta de nuevo.');
    }
  }

  /// Crea el doc users/{uid} y pide el custom claim del rol a la CF.
  /// También se usa en el primer login con Google (onboarding).
  Future<void> _completeAdultProfile({
    required User user,
    required String displayName,
    required UserRole role,
    required int dobYear,
  }) async {
    await _db.doc(FirestorePaths.user(user.uid)).set({
      'role': role.name,
      'displayName': displayName,
      'email': user.email,
      'photoURL': user.photoURL,
      'dobYear': dobYear,
      'providers': user.providerData.map((p) => p.providerId).toList(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Custom claim (rules lo leen como request.auth.token.role).
    // Best-effort: si el backend (Cloudflare Worker) aún no está
    // desplegado, las reglas caen al rol del doc users/{uid}.
    try {
      await ApiClient.instance.call('/register-role', {'role': role.name});
      await user.getIdToken(true); // refrescar para que el claim aplique ya
    } catch (e) {
      AppLog.d('[Auth] registerRole no disponible (se reintenta luego): $e');
    }
  }

  /// Completa el perfil de un usuario ya autenticado (Google primer login).
  @override
  Future<AuthResult> completeProfile({
    required UserRole role,
    required int dobYear,
    String? displayName,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return const AuthResult.fail('Sesión no válida');
    try {
      await _completeAdultProfile(
        user: user,
        displayName: displayName ?? user.displayName ?? '',
        role: role,
        dobYear: dobYear,
      );
      return const AuthResult.success();
    } on ApiException catch (e) {
      return AuthResult.fail(e.message);
    } catch (e) {
      AppLog.d('[Auth] completeProfile: $e');
      return const AuthResult.fail('No se pudo completar el perfil.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  /// Google Sign-In v7. Devuelve además si es la primera vez
  /// (sin doc de perfil → hay que pasar por el gate de rol+edad).
  @override
  Future<AuthResult> signInWithGoogle() async {
    try {
      final credential = await _googleCredential();
      if (credential == null) {
        return const AuthResult.fail('Inicio con Google cancelado.');
      }
      await _auth.signInWithCredential(credential);
      return const AuthResult.success();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const AuthResult.fail('Inicio con Google cancelado.');
      }
      AppLog.d('[Auth] Google: $e');
      return const AuthResult.fail('No se pudo iniciar con Google.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  /// Vincula la cuenta actual (email) con Google.
  @override
  Future<AuthResult> linkWithGoogle() async {
    final user = _auth.currentUser;
    if (user == null) return const AuthResult.fail('Sesión no válida');
    try {
      final credential = await _googleCredential();
      if (credential == null) {
        return const AuthResult.fail('Vinculación cancelada.');
      }
      await user.linkWithCredential(credential);
      await _db.doc(FirestorePaths.user(user.uid)).set({
        'providers': user.providerData.map((p) => p.providerId).toList(),
      }, SetOptions(merge: true));
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    } on GoogleSignInException {
      return const AuthResult.fail('Vinculación cancelada.');
    }
  }

  // Cliente OAuth "type 3" (web) de google-services.json — necesario
  // para que el idToken de Android traiga la audiencia que Firebase
  // Auth espera (sin esto, google_sign_in v7 puede devolver un idToken
  // nulo o inválido en Android).
  static const _googleServerClientId =
      '378454359271-9k1ldm7o1fnjusmgeklnotnnvbrhtmkq.apps.googleusercontent.com';

  Future<OAuthCredential?> _googleCredential() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await signIn.initialize(serverClientId: _googleServerClientId);
      _googleInitialized = true;
    }
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return null;
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  /// Sesión del dispositivo del niño (custom token de redeemLinkCode).
  @override
  Future<AuthResult> signInWithCustomToken(String token) async {
    try {
      await _auth.signInWithCustomToken(token);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  @override
  Future<AuthResult> signInAnonymously() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GESTIÓN DE CUENTA
  // ─────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  @override
  Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  @override
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      return const AuthResult.fail('Sesión no válida');
    }
    try {
      // Reautenticación requerida por Firebase para operaciones sensibles
      final cred = EmailAuthProvider.credential(
          email: email, password: currentPassword);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  Future<void> validateSession() async {
    // El SDK nativo ya escucha idTokenChanges/userChanges y maneja la
    // revocación de sesión por su cuenta al refrescar — no hace falta
    // forzar nada aquí (a diferencia de la sesión REST de escritorio).
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true); // fuerza refresh; lanza si ya no es válida
    } on FirebaseAuthException {
      await signOut();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PERFIL
  // ─────────────────────────────────────────────────────────────

  // No hay try/catch envolvente a propósito: si algo de red falla acá
  // (getIdTokenResult, el get() de Firestore), esta función DEBE
  // lanzar en vez de devolver null — null significa específicamente
  // "no tiene perfil, hay que completar el registro", y el llamador
  // (auth_provider._onUserChanged) lo usa para decidir si manda a la
  // pantalla de onboarding. Si un error transitorio se tragara como
  // null, un usuario YA registrado terminaría viendo "elige tu rol"
  // de nuevo solo porque la lectura falló un instante.
  @override
  Future<SessionUser?> loadProfile(AuthUser authUser) async {
    // AuthUser es un snapshot neutral; para leer el custom claim
    // necesitamos el User vivo de firebase_auth (getIdTokenResult).
    final user = _auth.currentUser;
    if (user == null || user.uid != authUser.uid) return null;

    final token = await user.getIdTokenResult();
    final roleName = token.claims?['role'] as String?;

    // Un estudiante (uid == studentId) no tiene doc en users/{uid}
    // — su nombre (el que le puso el padre/tutor) vive en
    // students/{uid}. Sin este caso especial, displayName quedaba
    // vacío ("Hola, ") porque el custom token tampoco trae nombre.
    if (roleName == 'student') {
      final studentDoc = await _db.doc(FirestorePaths.student(user.uid)).get();
      final studentData = studentDoc.data();
      return SessionUser(
        uid: user.uid,
        role: UserRole.student,
        displayName: studentData?['name'] as String? ?? '',
        photoUrl: user.photoURL,
      );
    }

    final doc = await _db.doc(FirestorePaths.user(user.uid)).get();
    final data = doc.data();

    if (roleName == null && data == null) return null; // perfil incompleto (de verdad, no error)

    final base = data != null
        ? SessionUser.fromFirestore(data, user.uid)
        : SessionUser(
            uid: user.uid,
            role: UserRoleExt.fromName(roleName),
            displayName: user.displayName ?? '',
          );

    return base.copyWith(
      role: roleName != null ? UserRoleExt.fromName(roleName) : base.role,
      displayName: base.displayName.isNotEmpty
          ? base.displayName
          : (user.displayName ?? ''),
      email: user.email ?? base.email,
      emailVerified: user.emailVerified,
      photoUrl: user.photoURL ?? base.photoUrl,
      providers: user.providerData.map((p) => p.providerId).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────

  static String mapAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta fue deshabilitada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es muy débil (mínimo 6 caracteres).';
      case 'too-many-requests':
        return 'Demasiados intentos. Espera un momento.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'requires-recent-login':
        return 'Por seguridad, vuelve a iniciar sesión.';
      case 'credential-already-in-use':
        return 'Esa cuenta de Google ya está vinculada a otro usuario.';
      case 'provider-already-linked':
        return 'Ya tienes Google vinculado.';
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return 'El código no es válido. Pide uno nuevo.';
      default:
        return 'Error de autenticación ($code).';
    }
  }
}
