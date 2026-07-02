import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edutrack_family/core/constants/utils/notification_utils.dart';

// ═══════════════════════════════════════════════════════════════
// NOTIFICATION SETTINGS PROVIDER — EduTrack Family
// Persiste y expone preferencias de sonido, vibración y tono.
// Cuando cambian, recrea los canales de Android automáticamente.
// ═══════════════════════════════════════════════════════════════

const _keySound              = 'notif_sound';
const _keyVibration          = 'notif_vibration';
const _keyVibrationPattern   = 'notif_vibration_pattern';
const _keyRingtoneUri        = 'notif_ringtone_uri';
const _keyRingtoneName       = 'notif_ringtone_name';

// ─────────────────────────────────────────────────────────────
// BOOL PREF NOTIFIER — toggle persistido en SharedPreferences
// ─────────────────────────────────────────────────────────────

class BoolPrefNotifier extends StateNotifier<bool> {
  BoolPrefNotifier(this._key, bool defaultValue) : super(defaultValue) {
    _load();
  }
  final String _key;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getBool(_key) ?? state;
  }

  Future<void> set(bool v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, v);
    // Recrea los canales Android con la configuración actualizada
    await _syncChannels();
  }

  Future<void> _syncChannels() async {
    final p = await SharedPreferences.getInstance();
    final sound     = p.getBool(_keySound)     ?? true;
    final vibration = p.getBool(_keyVibration) ?? true;
    final ringtoneUri = p.getString(_keyRingtoneUri);
    await NotificationUtils.recreateChannels(
      soundUri: sound ? ringtoneUri : null,
      playSound: sound,
      enableVibration: vibration,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STRING PREF NOTIFIER — valor de cadena persistido
// ─────────────────────────────────────────────────────────────

class StringPrefNotifier extends StateNotifier<String> {
  StringPrefNotifier(this._key, String defaultValue) : super(defaultValue) {
    _load();
  }
  final String _key;

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = p.getString(_key) ?? state;
  }

  Future<void> set(String v) async {
    state = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, v);
    await _syncChannels();
  }

  Future<void> _syncChannels() async {
    final p = await SharedPreferences.getInstance();
    final sound      = p.getBool(_keySound)      ?? true;
    final vibration  = p.getBool(_keyVibration)  ?? true;
    final ringtoneUri = p.getString(_keyRingtoneUri);
    await NotificationUtils.recreateChannels(
      soundUri: sound ? ringtoneUri : null,
      playSound: sound,
      enableVibration: vibration,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RINGTONE NOTIFIER — tono del sistema persistido
// ─────────────────────────────────────────────────────────────

typedef RingtoneState = ({String? uri, String name});

class RingtoneNotifier extends StateNotifier<RingtoneState> {
  RingtoneNotifier() : super((uri: null, name: 'Predeterminado')) {
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = (
      uri: p.getString(_keyRingtoneUri),
      name: p.getString(_keyRingtoneName) ?? 'Predeterminado',
    );
  }

  Future<void> setRingtone({String? uri, required String name}) async {
    state = (uri: uri, name: name);
    final p = await SharedPreferences.getInstance();
    if (uri != null) {
      await p.setString(_keyRingtoneUri, uri);
    } else {
      await p.remove(_keyRingtoneUri);
    }
    await p.setString(_keyRingtoneName, name);
    // Recrea los canales Android con el nuevo tono
    final sound     = p.getBool(_keySound)     ?? true;
    final vibration = p.getBool(_keyVibration) ?? true;
    await NotificationUtils.recreateChannels(
      soundUri: sound ? uri : null,
      playSound: sound,
      enableVibration: vibration,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────

final notifSoundProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_keySound, true),
);

final notifVibrationProvider =
    StateNotifierProvider<BoolPrefNotifier, bool>(
  (ref) => BoolPrefNotifier(_keyVibration, true),
);

final notifRingtoneProvider =
    StateNotifierProvider<RingtoneNotifier, RingtoneState>(
  (ref) => RingtoneNotifier(),
);

// 'short' | 'medium' | 'long'
final notifVibrationPatternProvider =
    StateNotifierProvider<StringPrefNotifier, String>(
  (ref) => StringPrefNotifier(_keyVibrationPattern, 'medium'),
);
