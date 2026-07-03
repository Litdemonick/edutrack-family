import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'tracking_service.dart';

// ═══════════════════════════════════════════════════════════════
// CONSENTIMIENTO DE UBICACIÓN — dispositivo del hijo
//
// LocationCoordinator (invisible, vive en la shell del estudiante):
//   - escucha students/{uid} (enabledByParent) + locations/consent
//   - padre activó y el niño no ha confirmado → muestra la pantalla
//   - ambos sí → asegura permisos y arranca el foreground service
//   - cualquiera en no → detiene el servicio al instante
// ═══════════════════════════════════════════════════════════════

class LocationCoordinator extends ConsumerStatefulWidget {
  const LocationCoordinator({super.key});

  @override
  ConsumerState<LocationCoordinator> createState() =>
      _LocationCoordinatorState();
}

class _LocationCoordinatorState extends ConsumerState<LocationCoordinator> {
  StreamSubscription? _sub;
  bool _consentShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final user = ref.read(authProvider);
    if (user == null || !user.isStudent) return;

    _sub = LocationRepository.instance
        .watchConsent(user.uid)
        .listen((consent) async {
      if (!mounted) return;

      if (consent.enabledByParent && !consent.deviceConfirmed) {
        _showConsentScreen(user.uid);
      } else if (consent.enabledByParent && consent.deviceConfirmed) {
        final error = await TrackingService.instance.ensurePermissions();
        if (error == null) {
          await TrackingService.instance.start(user.uid);
        }
      } else {
        await TrackingService.instance.stop();
      }
    });
  }

  Future<void> _showConsentScreen(String studentId) async {
    if (_consentShowing || !mounted) return;
    _consentShowing = true;
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ConsentScreen(studentId: studentId),
      ),
    );
    _consentShowing = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ─────────────────────────────────────────────────────────────
// Pantalla de consentimiento (lenguaje para niños, honesto)
// ─────────────────────────────────────────────────────────────

class ConsentScreen extends StatefulWidget {
  final String studentId;
  const ConsentScreen({super.key, required this.studentId});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);

    final error = await TrackingService.instance.ensurePermissions();
    if (error != null) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    await LocationRepository.instance
        .setDeviceConfirmed(widget.studentId, true);
    await TrackingService.instance.start(widget.studentId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Text('📍', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 20),
              const Text(
                'Tu familia quiere saber que estás bien',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tu papá/mamá activó compartir tu ubicación. Si aceptas:\n\n'
                '• Podrán ver dónde estás en un mapa\n'
                '• Verás SIEMPRE un aviso en tu teléfono cuando esté activo\n'
                '• Puedes apagarlo cuando quieras desde la app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _accept,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Aceptar y compartir',
                        style: TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Ahora no',
                  style: TextStyle(color: Colors.white54, fontSize: 15),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
