import 'package:shared_preferences/shared_preferences.dart';

// ═══════════════════════════════════════════════════════════════
// LOCAL STORAGE — EduTrack Family
// Wrapper para SharedPreferences — guarda preferencias y sesión.
// ═══════════════════════════════════════════════════════════════

class LocalStorage {
  LocalStorage._();
  static LocalStorage? _instance;

  static LocalStorage get instance {
    _instance ??= LocalStorage._();
    return _instance!;
  }

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─────────────────────────────────────────────────────────────
  // CLAVES
  // ─────────────────────────────────────────────────────────────

  static const String _keyUserId = 'saved_user_id';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyLastSync = 'last_sync';
  static const String _keyNotifEnabled = 'notifications_enabled';
  static const String _keyHistoryCleanDate = 'history_clean_date';

  // ─────────────────────────────────────────────────────────────
  // SESIÓN DE USUARIO
  // ─────────────────────────────────────────────────────────────

  String? get savedUserId => _prefs.getString(_keyUserId);

  Future<void> saveUserId(String id) => _prefs.setString(_keyUserId, id);

  Future<void> clearUserId() => _prefs.remove(_keyUserId);

  // ─────────────────────────────────────────────────────────────
  // TEMA (DARK / LIGHT)
  // ─────────────────────────────────────────────────────────────

  bool get isDarkMode => _prefs.getBool(_keyDarkMode) ?? false;

  Future<void> setDarkMode(bool value) => _prefs.setBool(_keyDarkMode, value);

  // ─────────────────────────────────────────────────────────────
  // SINCRONIZACIÓN
  // ─────────────────────────────────────────────────────────────

  DateTime? get lastSyncTime {
    final iso = _prefs.getString(_keyLastSync);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> setLastSyncTime(DateTime time) =>
      _prefs.setString(_keyLastSync, time.toIso8601String());

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ─────────────────────────────────────────────────────────────

  bool get notificationsEnabled => _prefs.getBool(_keyNotifEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool value) =>
      _prefs.setBool(_keyNotifEnabled, value);

  // ─────────────────────────────────────────────────────────────
  // LIMPIEZA DE HISTORIAL
  // ─────────────────────────────────────────────────────────────

  DateTime? get lastHistoryCleanDate {
    final iso = _prefs.getString(_keyHistoryCleanDate);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  Future<void> setLastHistoryCleanDate(DateTime date) =>
      _prefs.setString(_keyHistoryCleanDate, date.toIso8601String());

  Future<void> clearSession() async {
    await clearUserId();
  }
}
