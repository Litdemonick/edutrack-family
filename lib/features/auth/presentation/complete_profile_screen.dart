import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'widgets/auth_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// COMPLETAR PERFIL — primer login con Google:
// falta elegir rol (padre/profesor) y declarar fecha de nacimiento.
// ═══════════════════════════════════════════════════════════════

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState
    extends ConsumerState<CompleteProfileScreen> {
  UserRole _role = UserRole.parent;
  DateTime? _dob;
  bool _loading = false;

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

  Future<void> _save() async {
    if (_dob == null) {
      _showError('Selecciona tu fecha de nacimiento');
      return;
    }
    if (_age < 18) {
      _showError('Debes ser mayor de 18 años para usar una cuenta de adulto.');
      return;
    }
    setState(() => _loading = true);
    final result = await ref.read(authProvider.notifier).completeProfile(
          role: _role,
          dobYear: _dob!.year,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.ok) _showError(result.error!);
    // Si ok, authProvider.refresh() dispara el redirect del router
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Un último paso',
      subtitle: 'Cuéntanos quién eres para configurar tu cuenta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _RoleOption(
                  role: UserRole.parent,
                  selected: _role == UserRole.parent,
                  onTap: () => setState(() => _role = UserRole.parent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _RoleOption(
                  role: UserRole.teacher,
                  selected: _role == UserRole.teacher,
                  onTap: () => setState(() => _role = UserRole.teacher),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Fecha de nacimiento',
                prefixIcon: const Icon(Icons.cake_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _dob == null
                    ? 'Toca para seleccionar'
                    : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                style: TextStyle(
                    color: _dob == null ? Colors.grey.shade600 : null),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Continuar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              // El estado ya estaba en null (perfil incompleto) antes
              // de cerrar sesión, así que Riverpod no dispara una
              // reconstrucción del router al volver a quedar en null
              // — sin este go() explícito el botón no hacía nada.
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('Usar otra cuenta'),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  const _RoleOption(
      {required this.role, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
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
            Text(role.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
