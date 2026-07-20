import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/services/biometric_service.dart';
import 'biometric_gate_screen.dart' show biometricUnlockedProvider;

// ═══════════════════════════════════════════════════════════════
// CONFIGURACIÓN OBLIGATORIA DE HUELLA/WINDOWS HELLO
// Se muestra una sola vez, justo después de verificar el correo o
// completar el perfil (padres/profesores) — no tiene botón para
// omitirla: sin esto configurado, nadie más puede abrir la app con
// esta sesión. Después SÍ se puede desactivar desde Ajustes.
// ═══════════════════════════════════════════════════════════════

bool get _isWindows => !kIsWeb && Platform.isWindows;

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _checking = false;
  String? _error;

  Future<void> _configure() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    final ok = await BiometricService.instance.authenticate(
      reason: _isWindows
          ? 'Configura Windows Hello para proteger EduTrack Family'
          : 'Configura tu huella para proteger EduTrack Family',
    );

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _checking = false;
        _error = 'No se pudo verificar. Inténtalo de nuevo.';
      });
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    await notifier.setBiometricEnabled(true);
    await notifier.setBiometricSetupDone(true);
    // Ya se autenticó en este mismo paso — no hace falta pedirle
    // otra vez el gate normal apenas entre al dashboard.
    ref.read(biometricUnlockedProvider.notifier).state = true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // paso obligatorio: no se puede retroceder
      child: Scaffold(
        backgroundColor: AppColors.navyBlue,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isWindows ? Icons.password_rounded : Icons.fingerprint,
                    size: 96,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    _isWindows
                        ? 'Configura Windows Hello'
                        : 'Configura tu huella',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Por seguridad, toda cuenta de padre/tutor o profesor '
                    'debe protegerse con ${_isWindows ? "Windows Hello" : "huella o Face ID"} '
                    'antes de continuar. Podrás desactivarlo después desde Ajustes '
                    'si lo prefieres.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.orange, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _checking ? null : _configure,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(_isWindows
                            ? Icons.password_rounded
                            : Icons.fingerprint),
                    label: Text(_checking ? 'Verificando...' : 'Configurar ahora'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      minimumSize: const Size(240, 52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
