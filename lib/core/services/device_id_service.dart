import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ═══════════════════════════════════════════════════════════════
// DEVICE ID SERVICE — EduTrack Family 2.0
// Id estable de esta instalación (UUID persistido en prefs).
// Extraído de FcmService para que cualquier otro escritor (p.ej.
// el tracking de ubicación) pueda identificar "de qué dispositivo
// vino esto" con el MISMO id que ya se usa para el registro de
// push, en vez de inventar un segundo identificador.
// ═══════════════════════════════════════════════════════════════

class DeviceIdService {
  DeviceIdService._();
  static final DeviceIdService instance = DeviceIdService._();

  static const _kInstallId = 'fcm_install_id';

  String? _cached;

  Future<String> installId() async {
    final cached = _cached;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kInstallId);
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString(_kInstallId, id);
    }
    _cached = id;
    return id;
  }
}
