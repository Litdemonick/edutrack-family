import 'package:shared_preferences/shared_preferences.dart';
import 'package:edutrack_family/core/data/local/models/user_model.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH REPOSITORY — EduTrack Family
// Gestiona la sesión persistida de los usuarios fijos.
// ═══════════════════════════════════════════════════════════════

class AuthRepository {
  AuthRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _keyUserId = 'saved_user_id';

  AppUser? get currentUser {
    final id = _prefs.getString(_keyUserId);
    if (id == null) return null;
    try {
      return AppUsers.all.firstWhere((u) => u.id == id);
    } catch (_) {
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
