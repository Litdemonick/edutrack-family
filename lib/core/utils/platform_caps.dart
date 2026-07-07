import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

// ═══════════════════════════════════════════════════════════════
// PLATFORM CAPS — EduTrack Family
// Única fuente de verdad para "¿esta plataforma tiene X?" — evita
// repetir el mismo chequeo kIsWeb/Platform.isX suelto en cada
// pantalla que necesita ocultar algo solo-móvil (cámara, GPS,
// biometría, foreground service, etc.).
// ═══════════════════════════════════════════════════════════════

class PlatformCaps {
  PlatformCaps._();

  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Cámara real (no "elegir archivo") — solo tiene sentido en
  /// celular/tablet. En Windows/Linux/macOS/web se oculta el botón
  /// de "Tomar foto" y solo queda "Elegir de galería/archivo".
  static bool get hasCamera => isMobile;
}
