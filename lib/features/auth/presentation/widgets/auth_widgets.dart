import 'package:flutter/material.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH WIDGETS — kit compartido de las pantallas de autenticación
// ═══════════════════════════════════════════════════════════════

/// Scaffold de auth: gradiente de marca, logo, tarjeta central
/// responsiva (max 560px) con scroll seguro en pantallas chicas.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;

  const AuthScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyBlue, Color(0xFF1A3C5E)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (showBack)
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                    tooltip: 'Volver',
                  ),
                ),
              Expanded(
                child: CenteredConstrained(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        Image.asset('assets/images/logo.png',
                            height: context.isCompact ? 72 : 96),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Card(
                          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: child,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Campo de texto estándar de los formularios de auth.
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final bool autofocus;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autofocus: autofocus,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Botón de "Continuar con Google".
class GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleButton({super.key, required this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('G',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentBlue)),
      label: const Text('Continuar con Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Validadores comunes.
class AuthValidators {
  AuthValidators._();

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Escribe tu correo';
    final rx = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!rx.hasMatch(value)) return 'Correo no válido';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Escribe tu contraseña';
    if (v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Escribe tu nombre';
    if (value.length < 3) return 'Nombre muy corto';
    return null;
  }
}
