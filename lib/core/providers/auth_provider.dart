import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/services/fcm_service.dart';
import 'package:edutrack_family/features/auth/data/auth_gateway.dart';
import 'package:edutrack_family/features/auth/data/firebase_auth_repository.dart';
import 'package:edutrack_family/main.dart' show sharedPreferencesProvider;

// ═══════════════════════════════════════════════════════════════
// AUTH PROVIDER — EduTrack Family 2.0
// Sesión real con Firebase Auth. El estado es SessionUser? :
//   null                → sin sesión (o perfil incompleto → ver
//                          needsProfileCompletion)
//   role parent/teacher → adulto verificado
//   role student        → dispositivo del niño (custom token)
// ═══════════════════════════════════════════════════════════════

const _kBiometricEnabled = 'biometric_enabled';
const _kBiometricSetupDone = 'biometric_setup_done';

class AuthNotifier extends StateNotifier<SessionUser?> {
  AuthNotifier(this._prefs) : super(null) {
    // .instance ya resuelve a la implementación correcta según la
    // plataforma (nativa en Android/iOS, REST en Windows/Linux) —
    // ver core/firebase/platform/firebase_backend.dart. Este
    // provider nunca necesita saber cuál es cuál.
    _sub = _repo.userChanges.listen(_onUserChanged);
  }

  final SharedPreferences _prefs;
  StreamSubscription<AuthUser?>? _sub;
  final _repo = FirebaseAuthRepository.instance;

  /// true cuando hay usuario de Firebase pero sin rol/perfil todavía
  /// (ej. primer login con Google → falta gate de rol + edad).
  bool needsProfileCompletion = false;

  /// true en cuanto la sesión terminó de restaurarse por primera vez
  /// (con o sin usuario) — el splash lo espera en vez de asumir tras
  /// un delay fijo que "null" ya es definitivo. Sin esto, en Windows
  /// (donde restaurar sesión es un round-trip de red) el splash podía
  /// mandar a /login antes de que la restauración terminara, y un
  /// instante después el router redirigía al panel — parpadeo visible.
  bool _hasResolvedOnce = false;
  bool get hasResolvedOnce => _hasResolvedOnce;

  Future<void> _onUserChanged(AuthUser? user) async {
    if (user == null) {
      needsProfileCompletion = false;
      state = null;
      _hasResolvedOnce = true;
      return;
    }
    // Los usuarios anónimos solo existen como bootstrap del canje
    // de código del niño: no son sesión de app.
    if (user.isAnonymous) return;

    final profile = await _repo.loadProfile(user);
    if (profile == null) {
      // Si ya había una sesión válida, no la borres por un error de
      // red transitorio al recargar el perfil (p. ej. al reabrir la
      // app en el celular sin señal todavía por un instante) — eso
      // confundía "sin conexión ahora mismo" con "sin perfil, hay que
      // completar el registro", cerrando la sesión sin motivo real.
      if (state != null) {
        _hasResolvedOnce = true;
        return;
      }
      needsProfileCompletion = true;
      state = null;
      _hasResolvedOnce = true;
      return;
    }
    needsProfileCompletion = false;
    state = profile;
    _hasResolvedOnce = true;
  }

  /// Re-lee el perfil (tras completar onboarding o verificar email).
  Future<void> refresh() async {
    final user = _repo.currentUser;
    if (user != null) await _onUserChanged(user);
  }

  // ── Login / registro ─────────────────────────────────────────

  Future<AuthResult> loginEmail(String email, String password) =>
      _repo.signInWithEmail(email, password);

  Future<AuthResult> loginGoogle() async {
    // No basta con esperar signInWithGoogle(): needsProfileCompletion
    // lo fija _onUserChanged, disparado por el stream userChanges de
    // forma asíncrona e independiente (incluye su propio await a
    // loadProfile(), una llamada de red). Sin este refresh() explícito,
    // quien llama a loginGoogle() puede leer needsProfileCompletion
    // ANTES de que el listener termine — carrera real, no cosmética:
    // así se quedaba "en la zona de login" tras un primer login con
    // Google (mismo patrón ya usado por completeProfile() abajo).
    final result = await _repo.signInWithGoogle();
    if (result.ok) await refresh();
    return result;
  }

  Future<AuthResult> registerAdult({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required int dobYear,
  }) async {
    // Mismo problema que loginGoogle(): sin refresh() explícito, el
    // estado se queda en null (needsProfileCompletion nunca llega a
    // fijarse como false + user real) y el router manda a /login en
    // vez de /verify-email justo después de registrarse.
    final result = await _repo.registerAdult(
      email: email,
      password: password,
      displayName: displayName,
      role: role,
      dobYear: dobYear,
    );
    if (result.ok) await refresh();
    return result;
  }

  Future<AuthResult> completeProfile({
    required UserRole role,
    required int dobYear,
    String? displayName,
  }) async {
    final result = await _repo.completeProfile(
      role: role,
      dobYear: dobYear,
      displayName: displayName,
    );
    if (result.ok) await refresh();
    return result;
  }

  Future<AuthResult> signInAsChild(String customToken) =>
      _repo.signInWithCustomToken(customToken);

  // ── Cuenta ───────────────────────────────────────────────────

  Future<AuthResult> linkWithGoogle() async {
    final result = await _repo.linkWithGoogle();
    if (result.ok) await refresh();
    return result;
  }

  Future<AuthResult> sendPasswordReset(String email) =>
      _repo.sendPasswordReset(email);

  Future<void> resendVerification() => _repo.resendVerification();

  Future<bool> reloadAndCheckVerified() async {
    final verified = await _repo.reloadAndCheckVerified();
    if (verified) await refresh();
    return verified;
  }

  /// Fuerza confirmar la sesión contra el servidor ahora mismo (en
  /// vez de esperar el refresh pasivo) — usado tras pedir un
  /// restablecimiento de contraseña por correo, para detectar la
  /// revocación apenas ocurra y cerrar sesión sin demora.
  Future<void> validateSession() => _repo.validateSession();

  /// Mantiene la firma que usa la pantalla de Ajustes (v1).
  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state == null) return PasswordChangeResult.notLoggedIn;
    if (newPassword != confirmPassword) return PasswordChangeResult.mismatch;
    if (newPassword.length < 6) return PasswordChangeResult.tooShort;

    final result = await _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    if (result.ok) return PasswordChangeResult.success;
    return PasswordChangeResult.wrongCurrent;
  }

  // ── Biometría ────────────────────────────────────────────────

  bool get biometricEnabled => _prefs.getBool(_kBiometricEnabled) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_kBiometricEnabled, enabled);
  }

  /// true una vez que el padre/profesor pasó por la configuración
  /// OBLIGATORIA de huella/Windows Hello al menos una vez en este
  /// dispositivo. Después puede desactivar el toggle en Ajustes sin
  /// que esto vuelva a pedirle configurarlo de nuevo.
  bool get biometricSetupDone => _prefs.getBool(_kBiometricSetupDone) ?? false;

  Future<void> setBiometricSetupDone(bool done) async {
    await _prefs.setBool(_kBiometricSetupDone, done);
  }

  // ── Logout ───────────────────────────────────────────────────

  Future<void> logout() async {
    // Desregistrar el token FCM de ESTA cuenta ANTES de terminar el
    // logout — un dispositivo compartido (padre/profesor/estudiante
    // turnándose en el mismo celular) podía iniciar sesión con la
    // cuenta siguiente antes de que esto terminara (antes solo
    // corría como reacción fire-and-forget en app.dart, sin
    // garantía de orden), dejando temporalmente el token registrado
    // bajo la cuenta VIEJA y la NUEVA a la vez — riesgo real de que
    // push de un rol le lleguen al otro en el mismo aparato.
    // deleteToken() invalida el token real (no solo borra el doc de
    // Firestore), así que aunque quede algo huérfano, ya no sirve.
    await FcmService.instance.unregisterDevice();
    await _repo.signOut();
    // Datos locales fuera: son de la cuenta anterior
    await DatabaseHelper.instance.wipeAll();
    // needsProfileCompletion no se resetea solo: _onUserChanged(null)
    // (disparado por el stream de _repo.signOut(), de forma async)
    // sí lo resetea, pero depender de esa carrera es lo que dejaba a
    // "Usar otra cuenta" sin efecto — el router seguía mandando de
    // vuelta a completeProfile porque la bandera quedaba en true.
    needsProfileCompletion = false;
    state = null;
  }

  // ── Helpers ──────────────────────────────────────────────────

  bool get isAdmin => state?.isAdult ?? false;
  bool get isStudent => state?.isStudent ?? false;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// Resultado del cambio de contraseña (compatibilidad UI v1)
enum PasswordChangeResult {
  success,
  wrongCurrent,
  mismatch,
  tooShort,
  notLoggedIn,
}

extension PasswordChangeResultX on PasswordChangeResult {
  String get message {
    switch (this) {
      case PasswordChangeResult.success:
        return 'Contraseña actualizada correctamente';
      case PasswordChangeResult.wrongCurrent:
        return 'La contraseña actual es incorrecta';
      case PasswordChangeResult.mismatch:
        return 'Las contraseñas nuevas no coinciden';
      case PasswordChangeResult.tooShort:
        return 'La contraseña debe tener al menos 6 caracteres';
      case PasswordChangeResult.notLoggedIn:
        return 'Sesión no válida';
    }
  }

  bool get isSuccess => this == PasswordChangeResult.success;
}

final authProvider = StateNotifierProvider<AuthNotifier, SessionUser?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});
