// ═══════════════════════════════════════════════════════════════
// APP LIFECYCLE SERVICE — EduTrack Family
// Singleton que rastrea si la app está actualmente en primer plano.
// Usado para decidir entre notificación interna (campana) o push.
// ═══════════════════════════════════════════════════════════════

class AppLifecycleService {
  AppLifecycleService._();
  static final AppLifecycleService instance = AppLifecycleService._();

  bool _isInForeground = true;

  /// true  → app visible al usuario
  /// false → app en segundo plano o cerrada
  bool get isInForeground => _isInForeground;

  void setForeground()   => _isInForeground = true;
  void setBackground()   => _isInForeground = false;
}
