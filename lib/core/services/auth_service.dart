import 'package:shared_preferences/shared_preferences.dart';
import 'package:edutrack_family/core/data/local/models/user_model.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH SERVICE — EduTrack Family
// Valida credenciales y persiste la sesión activa.
// ═══════════════════════════════════════════════════════════════

class AuthService {
  AuthService(this._prefs);

  final SharedPreferences _prefs;
  static const _keyUserId = 'saved_user_id';

  AppUser? loadSavedSession() {
    final id = _prefs.getString(_keyUserId);
    if (id == null) return null;
    try {
      return AppUsers.all.firstWhere((u) => u.id == id);
    } catch (_) {
      _prefs.remove(_keyUserId);
      return null;
    }
  }

  Future<AppUser?> login(String username, String password) async {
    final user = AppUsers.authenticate(username, password);
    if (user == null) return null;
    await _prefs.setString(_keyUserId, user.id);
    return user;
  }

  Future<void> logout() async {
    await _prefs.remove(_keyUserId);
  }
}
