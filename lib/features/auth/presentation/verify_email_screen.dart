import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// VERIFICAR EMAIL — pantalla bloqueante hasta confirmar el correo.
// Reintenta cada 5 s (user.reload) y permite reenviar el email.
// ═══════════════════════════════════════════════════════════════

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _pollTimer;
  bool _resent = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final verified =
          await ref.read(authProvider.notifier).reloadAndCheckVerified();
      // Si verified, authProvider se refresca y el router redirige solo
      if (verified) _pollTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    await ref.read(authProvider.notifier).resendVerification();
    setState(() {
      _resent = true;
      _cooldown = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(authProvider.select((u) => u?.email)) ?? 'tu correo';

    return AuthScaffold(
      title: 'Verifica tu correo',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('📬', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            'Te enviamos un enlace de verificación a:\n$email',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Abre el correo y toca el enlace. Esta pantalla se '
            'actualizará automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _cooldown > 0 ? null : _resend,
            icon: const Icon(Icons.refresh),
            label: Text(_cooldown > 0
                ? 'Reenviar en $_cooldown s'
                : _resent
                    ? 'Reenviar de nuevo'
                    : 'Reenviar correo'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: const Text('Usar otra cuenta'),
          ),
        ],
      ),
    );
  }
}
