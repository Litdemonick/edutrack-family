import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'location_permission_help.dart';
import 'tracking_service.dart';

// ═══════════════════════════════════════════════════════════════
// COORDINADOR DE UBICACIÓN — dispositivo del hijo
//
// Decisión del usuario: el padre/tutor activa "compartir ubicación"
// y el rastreo arranca directo — el hijo NO tiene una pantalla de
// aceptar/rechazar. Sí sigue viendo SIEMPRE el aviso persistente de
// Android ("EduTrack está compartiendo tu ubicación 📍") — eso no se
// puede quitar, es el mismo indicador técnico que evita que Doze
// mate el servicio — y puede apagarlo él mismo cuando quiera desde
// Ajustes → Ubicación (ver settings_screen.dart).
//
// deviceConfirmed (locations/consent) cambió de significado: ya no
// es "¿el hijo aceptó?" sino "¿debe estar activo en este
// dispositivo?" — se auto-confirma solo la PRIMERA vez que
// enabledByParent pasa a true (o se reactiva tras que el padre lo
// hubiera apagado), y el hijo lo puede apagar después sin que este
// coordinador lo vuelva a prender solo.
// ═══════════════════════════════════════════════════════════════

class LocationCoordinator extends ConsumerStatefulWidget {
  const LocationCoordinator({super.key});

  @override
  ConsumerState<LocationCoordinator> createState() =>
      _LocationCoordinatorState();
}

class _LocationCoordinatorState extends ConsumerState<LocationCoordinator> {
  StreamSubscription? _sub;
  bool? _prevEnabledByParent;
  bool _permissionNudgeShown = false;

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

      // ¿El padre/tutor lo acaba de prender (o re-prender) justo
      // ahora? Distingue "el padre activó" de "el hijo lo apagó desde
      // Ajustes" — ambos casos llegan acá con enabledByParent==true,
      // pero solo el primero debe auto-confirmar sin preguntarle nada
      // al hijo.
      final justEnabled =
          consent.enabledByParent && _prevEnabledByParent != true;
      _prevEnabledByParent = consent.enabledByParent;

      if (!consent.enabledByParent) {
        await TrackingService.instance.stop();
        return;
      }

      if (justEnabled && !consent.deviceConfirmed) {
        await LocationRepository.instance.setDeviceConfirmed(user.uid, true);
        return; // la próxima emisión del stream ya trae deviceConfirmed=true
      }

      if (!consent.deviceConfirmed) {
        // El hijo lo apagó desde Ajustes — se respeta, no se reactiva solo.
        await TrackingService.instance.stop();
        return;
      }

      final error = await TrackingService.instance.ensurePermissions();
      if (error != null) {
        // Se guarda en Firestore (no solo un diálogo local) para que
        // el padre/tutor Y el propio hijo (en Ajustes) vean SIEMPRE
        // por qué no hay rastreo — sin esto, el padre veía
        // "Compartiendo ubicación" en verde aunque en realidad
        // estuviera bloqueado esperando un permiso, sin ninguna pista.
        if (consent.permissionError != error) {
          await LocationRepository.instance.setPermissionError(user.uid, error);
        }
        // El diálogo con el botón "Abrir Ajustes" sí se muestra solo
        // una vez por sesión de la app (no en cada reevaluación del
        // stream) — el aviso persistente de arriba cubre el resto.
        if (!_permissionNudgeShown && mounted) {
          _permissionNudgeShown = true;
          await showLocationPermissionHelp(context, error,
              retryLabel: 'Compartir ubicación (en Ajustes)');
        }
        return;
      }
      if (consent.permissionError != null) {
        await LocationRepository.instance.setPermissionError(user.uid, null);
      }
      await TrackingService.instance.start(user.uid);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
