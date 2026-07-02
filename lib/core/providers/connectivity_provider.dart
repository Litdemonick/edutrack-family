import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/services/connectivity_service.dart';

// ═══════════════════════════════════════════════════════════════
// CONNECTIVITY PROVIDER — EduTrack Family
// Estado reactivo de la conectividad a internet.
// ═══════════════════════════════════════════════════════════════

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(false) {
    _init();
  }

  StreamSubscription<bool>? _sub;

  Future<void> _init() async {
    final svc = ConnectivityService.instance;
    await svc.init();
    state = svc.isOnline;
    _sub = svc.onConnectivityChanged.listen((online) {
      state = online;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
      return ConnectivityNotifier();
    });
