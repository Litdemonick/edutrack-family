import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/services/biometric_service.dart';

// ═══════════════════════════════════════════════════════════════
// GATE BIOMÉTRICO — re-entrada rápida con huella/Face ID.
// Se muestra al abrir la app con sesión viva si el usuario activó
// la biometría en Ajustes. Reemplaza el auto-logout de la v1.
// ═══════════════════════════════════════════════════════════════

/// true cuando el usuario ya pasó el gate en esta sesión de app.
final biometricUnlockedProvider = StateProvider<bool>((_) => false);

class BiometricGateScreen extends ConsumerStatefulWidget {
  const BiometricGateScreen({super.key});

  @override
  ConsumerState<BiometricGateScreen> createState() =>
      _BiometricGateScreenState();
}

class _BiometricGateScreenState extends ConsumerState<BiometricGateScreen> {
  bool _checking = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Lanzar la huella apenas se muestra la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _failed = false;
    });

    final available = await BiometricService.instance.isAvailable();
    if (!available) {
      // Sin hardware biométrico → no bloquear
      ref.read(biometricUnlockedProvider.notifier).state = true;
      return;
    }

    final ok = await BiometricService.instance
        .authenticate(reason: 'Desbloquea EduTrack Family');
    if (!mounted) return;
    if (ok) {
      ref.read(biometricUnlockedProvider.notifier).state = true;
    } else {
      setState(() {
        _checking = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 90),
                const SizedBox(height: 24),
                Text(
                  'Hola, ${user?.displayName ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 40),
                Icon(
                  Icons.fingerprint,
                  size: 84,
                  color: _failed ? Colors.orange : Colors.white70,
                ),
                const SizedBox(height: 16),
                Text(
                  _failed
                      ? 'No se pudo verificar. Intenta de nuevo.'
                      : 'Usa tu huella para entrar',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _tryUnlock,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('Desbloquear'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    minimumSize: const Size(220, 52),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                  },
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
