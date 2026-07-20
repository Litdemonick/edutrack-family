import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/utils/input_sanitizer.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// OLVIDÉ MI CONTRASEÑA — envía email de restablecimiento
// ═══════════════════════════════════════════════════════════════

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result = await ref
        .read(authProvider.notifier)
        .sendPasswordReset(InputSanitizer.clean(_emailCtrl.text));
    if (!mounted) return;
    setState(() {
      _loading = false;
      // Por privacidad no revelamos si el correo existe o no
      _sent = result.ok || result.error == 'Correo o contraseña incorrectos.';
    });
    if (!_sent && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result.error!),
            backgroundColor: Colors.red.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Recuperar contraseña',
      showBack: true,
      child: _sent
          ? Column(
              children: [
                const Text('✅', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(
                  'Si existe una cuenta con ese correo, te enviamos un '
                  'enlace para crear una contraseña nueva.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Volver al inicio de sesión'),
                ),
              ],
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Escribe el correo de tu cuenta y te enviaremos un '
                    'enlace para restablecer la contraseña.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 18),
                  AuthTextField(
                    controller: _emailCtrl,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: AuthValidators.email,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _send(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loading ? null : _send,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Enviar enlace'),
                  ),
                ],
              ),
            ),
    );
  }
}
