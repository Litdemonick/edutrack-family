import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY SERVICE — EduTrack Family
// Detecta si hay WiFi/datos para activar la sincronización.
// ═══════════════════════════════════════════════════════════════

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  Future<void> init() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);

    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _isConnected(results);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(online);
        AppLog.d('[Connectivity] ${online ? "Online ✓" : "Offline ✗"}');
      }
    });
  }

  bool _isConnected(List<ConnectivityResult> results) {
    return results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.ethernet,
    );
  }

  Future<bool> checkNow() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = _isConnected(result);
    return _isOnline;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
