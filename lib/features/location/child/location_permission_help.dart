import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// ═══════════════════════════════════════════════════════════════
// AYUDA DE PERMISOS DE UBICACIÓN — dispositivo del hijo
// Ninguno de los 3 casos que puede devolver
// TrackingService.ensurePermissions() se arregla con un diálogo
// normal de la app — los 3 requieren que el usuario vaya a Ajustes
// (de la app o del sistema) a mano. Compartido entre la pantalla de
// consentimiento y el interruptor de Ajustes del estudiante, para
// que ambos lleven al mismo lugar en vez de uno mostrar un botón
// accionable y el otro solo texto suelto.
// ═══════════════════════════════════════════════════════════════

Future<void> showLocationPermissionHelp(
  BuildContext context,
  String error, {
  String retryLabel = 'Compartir ubicación',
}) async {
  final String steps;
  final String buttonLabel;
  final Future<void> Function() openSettings;

  // Android traduce la opción de fondo distinto según versión/OEM
  // ("Permitir siempre" en unos, "Permitido todo el tiempo" o "Todo
  // el tiempo" en otros) — mencionar las variantes evita que alguien
  // no reconozca el botón porque su celular dice algo ligeramente
  // distinto a lo que esperaba leer.
  const alwaysOptionHint =
      '"Permitir siempre" (o "Permitido todo el tiempo"/"Todo el tiempo", '
      'según tu celular)';

  if (error.contains('Permitir siempre')) {
    steps = 'Para que funcione con la app cerrada, Android pide '
        'confirmarlo directo en Ajustes:\n\n'
        '1. Toca "Abrir Ajustes"\n'
        '2. Entra a Permisos → Ubicación\n'
        '3. Elige $alwaysOptionHint\n'
        '4. Vuelve aquí y toca "$retryLabel" de nuevo';
    buttonLabel = 'Abrir Ajustes';
    openSettings = Geolocator.openAppSettings;
  } else if (error.contains('Enciende el GPS')) {
    steps = 'El GPS del teléfono está apagado:\n\n'
        '1. Toca "Abrir Ajustes de ubicación"\n'
        '2. Actívalo\n'
        '3. Vuelve aquí y toca "$retryLabel" de nuevo';
    buttonLabel = 'Abrir Ajustes de ubicación';
    openSettings = Geolocator.openLocationSettings;
  } else {
    // "Activa el permiso de ubicación en Ajustes" (denegado del todo)
    steps = 'EduTrack necesita permiso de ubicación:\n\n'
        '1. Toca "Abrir Ajustes"\n'
        '2. Entra a Permisos → Ubicación\n'
        '3. Actívalo — elige $alwaysOptionHint para que funcione '
        'aunque la app esté cerrada\n'
        '4. Vuelve aquí y toca "$retryLabel" de nuevo';
    buttonLabel = 'Abrir Ajustes';
    openSettings = Geolocator.openAppSettings;
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Falta un permiso'),
      content: Text(steps),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cerrar'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await openSettings();
          },
          child: Text(buttonLabel),
        ),
      ],
    ),
  );
}
