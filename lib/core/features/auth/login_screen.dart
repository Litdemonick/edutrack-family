import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/data/local/models/user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  AppUser? _selectedProfile;
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastId = ref.read(authProvider.notifier).lastProfileId;
      if (lastId != null) {
        try {
          final last = AppUsers.all.firstWhere((u) => u.id == lastId);
          setState(() => _selectedProfile = last);
          _animCtrl.forward();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _selectProfile(AppUser user) {
    if (_selectedProfile?.id == user.id) return;
    setState(() {
      _selectedProfile = user;
      _passCtrl.clear();
      _error = null;
      _obscurePass = true;
    });
    _animCtrl.forward(from: 0);
  }

  Future<void> _login() async {
    if (_selectedProfile == null) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _error = null; });

    // Ejecuta el auth y el tiempo mínimo de pantalla de carga en paralelo.
    // Si el auth termina antes de 1.4 s, esperamos; si tarda más, no bloqueamos.
    final results = await Future.wait([
      Future.delayed(const Duration(milliseconds: 1400)),
      ref.read(authProvider.notifier).login(
        _selectedProfile!.username, _passCtrl.text.trim()),
    ]);

    if (!mounted) return;
    final ok = results[1] as bool;
    if (!ok) {
      setState(() {
        _isLoading = false;
        _error = AppStrings.loginError;
        _passCtrl.clear();
      });
    }
    // Si ok == true, GoRouter redirige solo al detectar el cambio en authProvider.
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor:
            isDark ? const Color(0xFF12121E) : AppColors.background,
      body: _isLoading
          ? _LoginLoadingScreen(profile: _selectedProfile)
          : Stack(
        children: [
          // ── Fondo degradado superior ───────────────────────────
          Container(
            height: screenH * 0.42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF091D38), Color(0xFF163566)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
            ),
          ),

          // ── Contenido principal con scroll ────────────────────
          SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(),
                  const SizedBox(height: 4),
                  _LogoSection(),

                  // Separación proporcional: logo arriba, opciones visibles
                  SizedBox(height: screenH * 0.06),

                  // ── Selector de perfil ───────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      children: [
                        _ProfileCard(
                          user: AppUsers.admin,
                          label: 'Administrador',
                          icon: Icons.admin_panel_settings_rounded,
                          isSelected:
                              _selectedProfile?.id == AppUsers.admin.id,
                          isDark: isDark,
                          onTap: () => _selectProfile(AppUsers.admin),
                        ),
                        const SizedBox(width: 14),
                        _ProfileCard(
                          user: AppUsers.student,
                          label: 'Estudiante',
                          icon: Icons.school_rounded,
                          isSelected:
                              _selectedProfile?.id == AppUsers.student.id,
                          isDark: isDark,
                          onTap: () => _selectProfile(AppUsers.student),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Campo de contraseña ──────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _selectedProfile == null
                          ? const SizedBox.shrink()
                          : SlideTransition(
                              position: _slideAnim,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: _PasswordCard(
                                  formKey: _formKey,
                                  passCtrl: _passCtrl,
                                  obscurePass: _obscurePass,
                                  isLoading: _isLoading,
                                  error: _error,
                                  profileName: _selectedProfile!.isAdmin
                                      ? 'Administrador'
                                      : 'Estudiante',
                                  isDark: isDark,
                                  onToggleObscure: () => setState(
                                    () => _obscurePass = !_obscurePass,
                                  ),
                                  onSubmit: _login,
                                ),
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Versión
                  Center(
                    child: Text(
                      'EduTrack Family v${AppStrings.appVersion}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isDark ? Colors.white24 : Colors.black26,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BARRA SUPERIOR — solo título, sin toggle de tema
// ─────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.accentBlue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'EduTrack Family',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SECCIÓN DE LOGO
// ─────────────────────────────────────────────────────────────
class _LogoSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Contenedor glassmorphism
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.20),
                Colors.white.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text('📚', style: TextStyle(fontSize: 34)),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Bienvenido',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '¿Con qué perfil ingresas hoy?',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: Colors.white60,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA DE PERFIL
// GestureDetector + AnimatedContainer puro = transición fluida
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AppUser user;
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.user,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF15274A) : const Color(0xFFEBF3FF))
                : (isDark ? const Color(0xFF1C1C2E) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentBlue
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFDDE6F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.accentBlue.withValues(alpha: 0.22)
                    : Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                blurRadius: isSelected ? 18 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono con fondo circular animado
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.accentBlue.withValues(alpha: 0.14)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : AppColors.lightBlue.withValues(alpha: 0.70)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: isSelected
                      ? AppColors.accentBlue
                      : (isDark ? Colors.white54 : AppColors.navyBlue),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? AppColors.accentBlue
                      : (isDark ? Colors.white70 : AppColors.navyBlue),
                ),
              ),
              const SizedBox(height: 8),
              // Badge: siempre ocupa espacio, fade in/out sin salto de altura
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 11, color: AppColors.accentBlue),
                      const SizedBox(width: 4),
                      Text(
                        'Activo',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────────
// TARJETA DE CONTRASEÑA
// ─────────────────────────────────────────────────────────────
class _PasswordCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController passCtrl;
  final bool obscurePass;
  final bool isLoading;
  final String? error;
  final String profileName;
  final bool isDark;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  const _PasswordCard({
    required this.formKey,
    required this.passCtrl,
    required this.obscurePass,
    required this.isLoading,
    required this.error,
    required this.profileName,
    required this.isDark,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : const Color(0xFFE4EBF5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          if (!isDark)
            BoxShadow(
              color: AppColors.accentBlue.withValues(alpha: 0.06),
              blurRadius: 48,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado del campo
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 15,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Contraseña de $profileName',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.navyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Campo de contraseña
            TextFormField(
              controller: passCtrl,
              obscureText: obscurePass,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onSubmit(),
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.darkGrey,
              ),
              decoration: InputDecoration(
                hintText: 'Escribe tu contraseña',
                prefixIcon: Icon(
                  Icons.lock_outline_rounded,
                  color: isDark ? Colors.white38 : AppColors.grey,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: isDark ? Colors.white38 : AppColors.grey,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'La contraseña es obligatoria';
                }
                if (v.trim().length < 4) {
                  return 'La contraseña es muy corta';
                }
                return null;
              },
            ),

            // Mensaje de error
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusRedLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.statusRed.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.statusRed,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.statusRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),

            // Botón de ingreso con degradado
            _LoginButton(isLoading: isLoading, onTap: onSubmit),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN DE INGRESO CON DEGRADADO
// ─────────────────────────────────────────────────────────────
class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LoginButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isLoading
            ? const LinearGradient(
                colors: [Color(0xFF7A8FA6), Color(0xFF5A7080)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2347), Color(0xFF1A5098)],
              ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isLoading
            ? []
            : [
                BoxShadow(
                  color: const Color(0xFF0D2347).withValues(alpha: 0.48),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF1A5098).withValues(alpha: 0.20),
                  blurRadius: 40,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.12),
          highlightColor: Colors.white.withValues(alpha: 0.06),
          child: SizedBox(
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Ingresar',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.4,
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

// ─────────────────────────────────────────────────────────────
// PANTALLA DE CARGA POST-LOGIN
// Aparece entre el formulario y la redirección a admin/student.
// ─────────────────────────────────────────────────────────────
class _LoginLoadingScreen extends StatefulWidget {
  final AppUser? profile;
  const _LoginLoadingScreen({this.profile});

  @override
  State<_LoginLoadingScreen> createState() => _LoginLoadingScreenState();
}

class _LoginLoadingScreenState extends State<_LoginLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.profile == null
        ? ''
        : widget.profile!.isAdmin
            ? 'Administrador'
            : 'Estudiante';

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: const Color(0xFF0F2744),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 48)),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'EduTrack',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const Text(
                  'Family',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    color: Colors.white60,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 40),
                // Spinner propio con repeat()
                _LoginSpinner(),
                const SizedBox(height: 20),
                if (label.isNotEmpty)
                  Text(
                    'Ingresando como $label…',
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: Colors.white54,
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

class _LoginSpinner extends StatefulWidget {
  @override
  State<_LoginSpinner> createState() => _LoginSpinnerState();
}

class _LoginSpinnerState extends State<_LoginSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: SizedBox(
        width: 28,
        height: 28,
        child: CustomPaint(painter: _ArcPainter()),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -math.pi / 2,
      math.pi * 1.5, // 270°
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => false;
}
