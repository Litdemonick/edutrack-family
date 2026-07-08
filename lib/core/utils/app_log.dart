import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════
// APP LOG — EduTrack Family
// debugPrint() de Flutter imprime en TODOS los modos (incluido
// release) — para que la build de producción no deje rastro en
// logcat/consola, este wrapper solo imprime en modo debug/profile.
// Reemplaza cada debugPrint(...) del proyecto por AppLog.d(...).
// ═══════════════════════════════════════════════════════════════

class AppLog {
  AppLog._();

  static void d(String message) {
    if (kDebugMode || kProfileMode) {
      debugPrint(message);
    }
  }
}
