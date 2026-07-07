import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// ═══════════════════════════════════════════════════════════════
// BIOMETRIC SERVICE — EduTrack Family 2.0
// Gate de huella/Face ID (Android/iOS) o Windows Hello (Windows)
// para re-entrada rápida con sesión viva. local_auth resuelve a
// local_auth_windows automáticamente en Windows — confirmado como
// dependencia transitiva real, no un supuesto (ver pubspec.lock).
// Linux queda sin gate: no existe un local_auth_linux oficial.
// ═══════════════════════════════════════════════════════════════

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// ¿El dispositivo puede usar biometría, Windows Hello o PIN del sistema?
  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Pide huella/rostro/Windows Hello (con PIN como respaldo donde
  /// aplique). Devuelve true si el usuario se autenticó.
  /// En plataformas sin soporte (Linux/web), sin gate: no hay forma
  /// de pedir nada, así que no se puede bloquear la entrada ahí.
  Future<bool> authenticate({String? reason}) async {
    if (!_isSupportedPlatform) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? 'Desbloquea EduTrack Family',
        biometricOnly: false, // permite PIN/patrón/Windows Hello alterno
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('[Biometric] error: $e');
      return false;
    }
  }
}
