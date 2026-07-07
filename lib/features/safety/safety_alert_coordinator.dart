import 'dart:async';

// ═══════════════════════════════════════════════════════════════
// SAFETY ALERT COORDINATOR — EduTrack Family
// La alerta sísmica tiene prioridad sobre el check-in "¿Estás
// bien?": si las dos coinciden en el dispositivo del hijo, la
// pantalla de sismo se muestra primero (en bucle) y el check-in
// espera a que se acepte esa antes de mostrarse — dos alertas de
// pantalla completa a la vez serían confusas para un niño.
// ═══════════════════════════════════════════════════════════════

class SafetyAlertCoordinator {
  SafetyAlertCoordinator._();
  static final SafetyAlertCoordinator instance = SafetyAlertCoordinator._();

  bool _seismicActive = false;
  Completer<void>? _clearCompleter;

  void markSeismicActive() {
    _seismicActive = true;
    _clearCompleter ??= Completer<void>();
  }

  void markSeismicCleared() {
    _seismicActive = false;
    if (_clearCompleter != null && !_clearCompleter!.isCompleted) {
      _clearCompleter!.complete();
    }
    _clearCompleter = null;
  }

  /// Si hay una alerta sísmica en pantalla ahora mismo, espera a que
  /// el usuario la acepte antes de continuar (no-op si no hay ninguna).
  Future<void> waitUntilSeismicClear() async {
    if (!_seismicActive) return;
    await _clearCompleter?.future;
  }
}
