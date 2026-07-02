import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

// ═══════════════════════════════════════════════════════════════
// BIOMETRIC SERVICE — EduTrack Family 2.0
// Gate de huella/Face ID para re-entrada rápida con sesión viva.
// Solo Android/iOS; en desktop/web devuelve "no disponible".
// ═══════════════════════════════════════════════════════════════

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// ¿El dispositivo puede usar biometría o PIN del sistema?
  Future<bool> isAvailable() async {
    if (!_isMobile) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported || canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Pide huella/rostro (con PIN del dispositivo como respaldo).
  /// Devuelve true si el usuario se autenticó.
  Future<bool> authenticate({String? reason}) async {
    if (!_isMobile) return true; // desktop/web: sin gate
    try {
      return await _auth.authenticate(
        localizedReason: reason ?? 'Desbloquea EduTrack Family',
        biometricOnly: false, // permite PIN/patrón como respaldo
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      debugPrint('[Biometric] error: $e');
      return false;
    }
  }
}
