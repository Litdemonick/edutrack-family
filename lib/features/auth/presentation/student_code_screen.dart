import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// ACCESO DE ESTUDIANTE POR CÓDIGO — EduTrack Family 2.0
// El niño escribe el código que generó su padre/tutor:
//   1. signInAnonymously() (bootstrap para poder llamar la CF)
//   2. redeemLinkCode(code) → custom token con uid = studentId
//   3. signInWithCustomToken → sesión permanente del niño
// ═══════════════════════════════════════════════════════════════

class StudentCodeScreen extends ConsumerStatefulWidget {
  const StudentCodeScreen({super.key});

  @override
  ConsumerState<StudentCodeScreen> createState() => _StudentCodeScreenState();
}

class _StudentCodeScreenState extends ConsumerState<StudentCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = 'El código tiene 6 caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Bootstrap anónimo (solo para autenticar la llamada a la CF)
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // 2. Canjear el código
      final result = await FirebaseFunctions.instance
          .httpsCallable('redeemLinkCode')
          .call<Map<String, dynamic>>({'code': code});

      final token = result.data['token'] as String?;
      if (token == null) {
        throw Exception('Respuesta inválida del servidor');
      }

      // 3. Sesión real del niño (uid == studentId)
      final auth = await ref.read(authProvider.notifier).signInAsChild(token);
      if (!auth.ok) {
        setState(() => _error = auth.error);
      }
      // El router redirige a /student al detectar la sesión
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'not-found' => 'Código no válido. Revisa que esté bien escrito.',
          'deadline-exceeded' ||
          'failed-precondition' =>
            'El código expiró o ya fue usado. Pide uno nuevo.',
          _ => e.message ?? 'No se pudo validar el código.',
        };
      });
    } catch (e) {
      setState(() => _error = 'Error de conexión. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Hola 👋',
      subtitle: 'Escribe el código que te dio tu papá, mamá o tutor',
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _codeCtrl,
            textAlign: TextAlign.center,
            maxLength: 8,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              UpperCaseTextFormatter(),
            ],
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
              fontFamily: 'Poppins',
            ),
            decoration: InputDecoration(
              hintText: '······',
              counterText: '',
              errorText: _error,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onSubmitted: (_) => _redeem(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _redeem,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Entrar', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(height: 14),
          Text(
            'El código lo genera un adulto desde su app en '
            '"Mi familia → Vincular dispositivo". Vence en 24 horas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
