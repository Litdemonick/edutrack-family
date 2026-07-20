import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/utils/input_sanitizer.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// REGISTRO DE ADULTO — EduTrack Family 2.0
// Rol (padre/tutor | profesor) + nombre + email + contraseña +
// fecha de nacimiento (≥18). Tras crear la cuenta se envía email
// de verificación y el router lleva a /verify-email.
// Los estudiantes NO se registran aquí: entran con código.
// ═══════════════════════════════════════════════════════════════

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  UserRole _role = UserRole.parent;
  DateTime? _dob;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  int get _age {
    if (_dob == null) return 0;
    final now = DateTime.now();
    var age = now.year - _dob!.year;
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Tu fecha de nacimiento',
      locale: const Locale('es'),
      builder: EduDateUtils.clampPickerTextScale,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      _showError('Selecciona tu fecha de nacimiento');
      return;
    }
    if (_age < 18) {
      _showError(
          'Debes ser mayor de 18 años para crear una cuenta de ${_role.label}. '
          'Los estudiantes entran con el código que genera su padre o tutor.');
      return;
    }
    final email = InputSanitizer.clean(_emailCtrl.text);
    final password = InputSanitizer.clean(_passCtrl.text);
    final password2 = InputSanitizer.clean(_pass2Ctrl.text);
    final name = InputSanitizer.clean(_nameCtrl.text);

    if (password != password2) {
      _showError('Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).registerAdult(
          email: email,
          password: password,
          displayName: name,
          role: _role,
          dobYear: _dob!.year,
        );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.ok) {
      _showError(result.error!);
    } else if (mounted) {
      // El router redirige a /verify-email al detectar la sesión
      Navigator.of(context).popUntil((r) => r.isFirst);
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
      title: 'Crear cuenta',
      subtitle: 'Para padres, tutores y profesores',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Selector de rol ─────────────────────────────
            Text('¿Quién eres?',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    role: UserRole.parent,
                    selected: _role == UserRole.parent,
                    onTap: () => setState(() => _role = UserRole.parent),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    role: UserRole.teacher,
                    selected: _role == UserRole.teacher,
                    onTap: () => setState(() => _role = UserRole.teacher),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AuthTextField(
              controller: _nameCtrl,
              label: 'Nombre completo',
              icon: Icons.person_outline,
              validator: AuthValidators.name,
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _emailCtrl,
              label: 'Correo electrónico',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: AuthValidators.email,
            ),
            const SizedBox(height: 14),
            // ── Fecha de nacimiento (verificación de adulto) ─
            InkWell(
              onTap: _pickDob,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _dob == null
                      ? 'Toca para seleccionar'
                      : '${_dob!.day}/${_dob!.month}/${_dob!.year}'
                          '${_dob != null && _age >= 18 ? '  ✓' : ''}',
                  style: TextStyle(
                    color: _dob == null ? Colors.grey.shade600 : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passCtrl,
              label: 'Contraseña (8+, mayúscula y número)',
              icon: Icons.lock_outline,
              obscure: _obscure,
              validator: AuthValidators.newPassword,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _pass2Ctrl,
              label: 'Confirmar contraseña',
              icon: Icons.lock_outline,
              obscure: true,
              validator: AuthValidators.newPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _register,
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
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Crear cuenta'),
            ),
            const SizedBox(height: 10),
            Text(
              'Te enviaremos un correo para verificar tu cuenta.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accentBlue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? AppColors.accentBlue.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(role.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text(
              role.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
