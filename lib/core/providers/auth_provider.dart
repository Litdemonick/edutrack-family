import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edutrack_family/core/data/local/models/user_model.dart';
import 'package:edutrack_family/main.dart' show sharedPreferencesProvider;

class AuthNotifier extends StateNotifier<AppUser?> {
  AuthNotifier(this._prefs) : super(null) {
    _loadSavedSession();
  }

  final SharedPreferences _prefs;

  static const _keyUserId = 'saved_user_id';
  static const _keyLastProfile = 'last_profile_id';
  // Claves de contraseña por usuario — separadas e independientes
  static String _passKey(String userId) => 'pass_$userId';

  void _loadSavedSession() {
    final savedId = _prefs.getString(_keyUserId);
    if (savedId == null) return;
    try {
      state = AppUsers.all.firstWhere((u) => u.id == savedId);
    } catch (_) {
      _prefs.remove(_keyUserId);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LOGIN — verifica contra contraseña guardada o la predeterminada
  // ─────────────────────────────────────────────────────────────

  Future<bool> login(String username, String password) async {
    AppUser? user;
    try {
      user = AppUsers.all.firstWhere(
        (u) => u.username.toLowerCase() == username.toLowerCase(),
      );
    } catch (_) {
      return false;
    }

    // Contraseña guardada tiene prioridad sobre la predeterminada
    final storedPass = _prefs.getString(_passKey(user.id)) ?? user.password;
    if (storedPass != password) return false;

    state = user;
    await _prefs.setString(_keyUserId, user.id);
    await _prefs.setString(_keyLastProfile, user.id);
    return true;
  }

  // ─────────────────────────────────────────────────────────────
  // CAMBIAR CONTRASEÑA — requiere contraseña actual correcta
  // Solo afecta al usuario actualmente logueado
  // ─────────────────────────────────────────────────────────────

  Future<PasswordChangeResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (state == null) return PasswordChangeResult.notLoggedIn;
    if (newPassword != confirmPassword) return PasswordChangeResult.mismatch;
    if (newPassword.length < 6) return PasswordChangeResult.tooShort;

    final userId = state!.id;
    final storedPass = _prefs.getString(_passKey(userId)) ?? state!.password;

    if (storedPass != currentPassword) return PasswordChangeResult.wrongCurrent;

    await _prefs.setString(_passKey(userId), newPassword);
    return PasswordChangeResult.success;
  }

  // ─────────────────────────────────────────────────────────────
  // LOGOUT
  // ─────────────────────────────────────────────────────────────

  Future<void> logout() async {
    state = null;
    await _prefs.remove(_keyUserId);
    // Mantiene last_profile_id para pre-seleccionar perfil en próximo login
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String? get lastProfileId => _prefs.getString(_keyLastProfile);
  bool get isAdmin => state?.role == UserRole.admin;
  bool get isStudent => state?.role == UserRole.student;
}

// Resultado del cambio de contraseña
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

final authProvider = StateNotifierProvider<AuthNotifier, AppUser?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthNotifier(prefs);
});
