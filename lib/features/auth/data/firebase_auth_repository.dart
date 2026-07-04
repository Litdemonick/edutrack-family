import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/services/api_client.dart';

// ═══════════════════════════════════════════════════════════════
// FIREBASE AUTH REPOSITORY — EduTrack Family 2.0
// Operaciones de autenticación real:
//   email+password · Google Sign-In v7 · vinculación de cuentas ·
//   reset · verificación · custom token (dispositivo del niño)
//
// El rol vive en un custom claim (lo pone la CF registerRole) y
// se espeja en users/{uid} para la UI.
// ═══════════════════════════════════════════════════════════════

/// Resultado de una operación de auth con mensaje en español.
class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.success()
      : ok = true,
        error = null;
  const AuthResult.fail(this.error) : ok = false;
}

class FirebaseAuthRepository {
  FirebaseAuthRepository._();
  static final FirebaseAuthRepository instance = FirebaseAuthRepository._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool _googleInitialized = false;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get userChanges => _auth.userChanges();

  // ─────────────────────────────────────────────────────────────
  // REGISTRO DE ADULTO (email + password)
  // ─────────────────────────────────────────────────────────────

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
      debugPrint('[Auth] registerAdult: $e');
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
      debugPrint('[Auth] registerRole no disponible (se reintenta luego): $e');
    }
  }

  /// Completa el perfil de un usuario ya autenticado (Google primer login).
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
      debugPrint('[Auth] completeProfile: $e');
      return const AuthResult.fail('No se pudo completar el perfil.');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────────────────────

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
      debugPrint('[Auth] Google: $e');
      return const AuthResult.fail('No se pudo iniciar con Google.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  /// Vincula la cuenta actual (email) con Google.
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

  Future<OAuthCredential?> _googleCredential() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await signIn.initialize();
      _googleInitialized = true;
    }
    final account = await signIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) return null;
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  /// Sesión del dispositivo del niño (custom token de redeemLinkCode).
  Future<AuthResult> signInWithCustomToken(String token) async {
    try {
      await _auth.signInWithCustomToken(token);
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GESTIÓN DE CUENTA
  // ─────────────────────────────────────────────────────────────

  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(mapAuthError(e.code));
    }
  }

  Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

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

  Future<void> signOut() async {
    try {
      if (_googleInitialized) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────────────────────
  // PERFIL
  // ─────────────────────────────────────────────────────────────

  Future<SessionUser?> loadProfile(User user) async {
    try {
      final token = await user.getIdTokenResult();
      final roleName = token.claims?['role'] as String?;

      final doc = await _db.doc(FirestorePaths.user(user.uid)).get();
      final data = doc.data();

      if (roleName == null && data == null) return null; // perfil incompleto

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
    } catch (e) {
      debugPrint('[Auth] loadProfile: $e');
      return null;
    }
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
