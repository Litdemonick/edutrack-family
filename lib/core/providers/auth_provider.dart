import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/database/database_helper.dart';
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

class AuthNotifier extends StateNotifier<SessionUser?> {
  AuthNotifier(this._prefs) : super(null) {
    _sub = FirebaseAuthRepository.instance.userChanges.listen(_onUserChanged);
  }

  final SharedPreferences _prefs;
  StreamSubscription<User?>? _sub;
  final _repo = FirebaseAuthRepository.instance;

  /// true cuando hay usuario de Firebase pero sin rol/perfil todavía
  /// (ej. primer login con Google → falta gate de rol + edad).
  bool needsProfileCompletion = false;

  Future<void> _onUserChanged(User? user) async {
    if (user == null) {
      needsProfileCompletion = false;
      state = null;
      return;
    }
    // Los usuarios anónimos solo existen como bootstrap del canje
    // de código del niño: no son sesión de app.
    if (user.isAnonymous) return;

    final profile = await _repo.loadProfile(user);
    if (profile == null) {
      needsProfileCompletion = true;
      state = null;
      return;
    }
    needsProfileCompletion = false;
    state = profile;
  }

  /// Re-lee el perfil (tras completar onboarding o verificar email).
  Future<void> refresh() async {
    final user = _repo.currentUser;
    if (user != null) await _onUserChanged(user);
  }

  // ── Login / registro ─────────────────────────────────────────

  Future<AuthResult> loginEmail(String email, String password) =>
      _repo.signInWithEmail(email, password);

  Future<AuthResult> loginGoogle() => _repo.signInWithGoogle();

  Future<AuthResult> registerAdult({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required int dobYear,
  }) =>
      _repo.registerAdult(
        email: email,
        password: password,
        displayName: displayName,
        role: role,
        dobYear: dobYear,
      );

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

  // ── Logout ───────────────────────────────────────────────────

  Future<void> logout() async {
    await _repo.signOut();
    // Datos locales fuera: son de la cuenta anterior
    await DatabaseHelper.instance.wipeAll();
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
