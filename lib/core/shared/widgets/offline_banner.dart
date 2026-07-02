import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/providers/connectivity_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/services/sync_service.dart';

class OfflineBanner extends ConsumerStatefulWidget {
  const OfflineBanner({super.key});

  @override
  ConsumerState<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends ConsumerState<OfflineBanner> {
  bool? _prevOnline;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider);

    // Detecta transición offline → online y dispara sync completo
    if (_prevOnline == false && isOnline) {
      _syncOnReconnect();
    }
    _prevOnline = isOnline;

    return const SizedBox.shrink();
  }

  Future<void> _syncOnReconnect() async {
    // Pequeña pausa para asegurar que la conexión está estable
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    await SyncService.instance.fullSync();
    if (!mounted) return;

    // Recargar datos locales con lo que llegó de Firestore
    ref.read(taskProvider.notifier).loadTasks();
    ref.read(eventProvider.notifier).loadEvents();
  }
}
