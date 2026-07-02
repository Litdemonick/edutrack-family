import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// LOGIN — EduTrack Family 2.0
// Email + contraseña · Google · acceso de estudiante por código
// ═══════════════════════════════════════════════════════════════

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(authProvider.notifier)
        .loginEmail(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) _showError(result.error!);
    // Si ok, el router redirige solo (authProvider cambia)
  }

  Future<void> _loginGoogle() async {
    setState(() => _googleLoading = true);
    final result = await ref.read(authProvider.notifier).loginGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (!result.ok && result.error != 'Inicio con Google cancelado.') {
      _showError(result.error!);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'EduTrack Family',
      subtitle: 'Organiza, supervisa y acompaña las tareas escolares',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passCtrl,
              label: 'Contraseña',
              icon: Icons.lock_outline,
              obscure: _obscure,
              validator: AuthValidators.password,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _loginEmail(),
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure ? 'Mostrar' : 'Ocultar',
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.forgotPassword),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: _loading ? null : _loginEmail,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Iniciar sesión'),
            ),
            const SizedBox(height: 12),
            GoogleButton(onPressed: _loginGoogle, loading: _googleLoading),
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('o',
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.studentCode),
              icon: const Text('🎒', style: TextStyle(fontSize: 18)),
              label: const Text('Soy estudiante — tengo un código'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('¿No tienes cuenta?',
                    style: TextStyle(color: Colors.grey.shade600)),
                TextButton(
                  onPressed: () => context.push(AppRoutes.register),
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
