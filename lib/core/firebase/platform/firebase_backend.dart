import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

// ═══════════════════════════════════════════════════════════════
// FIREBASE BACKEND — punto único de decisión de plataforma
// firebase_auth/cloud_firestore/firebase_storage no tienen
// implementación nativa en Windows/Linux (no existen los paquetes
// federados _windows/_linux). En esas plataformas, los singletons
// *.instance de Auth/Firestore/Storage resuelven a una
// implementación REST en vez del SDK nativo — ver
// core/firebase/rest/. Ningún otro archivo debe repetir este
// check; todos los factories (*.instance) leen este único flag.
// ═══════════════════════════════════════════════════════════════
bool get useDesktopRestBackend =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux);
