import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/main.dart' show sharedPreferencesProvider;

// ═══════════════════════════════════════════════════════════════
// THEME PROVIDER — EduTrack Family
// Controla el modo claro / oscuro de la app.
// Persiste la preferencia en SharedPreferences.
// ═══════════════════════════════════════════════════════════════

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier(this._ref) : super(ThemeMode.light) {
    _loadSaved();
  }

  final Ref _ref;
  static const _key = 'dark_mode';

  void _loadSaved() {
    final prefs = _ref.read(sharedPreferencesProvider);
    final isDark = prefs.getBool(_key) ?? false;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggle() async {
    final isDark = state == ThemeMode.dark;
    state = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, !isDark);
  }

  Future<void> setDark(bool value) async {
    state = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier(ref);
});
