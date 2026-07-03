import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/theme_provider.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/notification_settings_provider.dart';
import 'package:edutrack_family/core/providers/profile_photo_provider.dart';
import 'package:edutrack_family/core/services/ringtone_service.dart';
import 'package:edutrack_family/core/services/biometric_service.dart';

// ═══════════════════════════════════════════════════════════════
// SETTINGS SCREEN — EduTrack Family
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _showChangePassword = false;

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(authProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final unread  = ref.watch(unreadNotificationCountProvider);

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Configuración',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Perfil ────────────────────────────────────────────
          _SectionHeader(title: 'Mi cuenta', isDark: isDark),
          _ProfileCard(user: user, isDark: isDark),
          const SizedBox(height: 20),

          // ── Familia (solo adultos) ────────────────────────────
          if (user.isAdmin) ...[
            _SectionHeader(title: 'Familia', isDark: isDark),
            _SettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.family_restroom_rounded,
                  title: 'Mi familia',
                  subtitle:
                      'Hijos, códigos de vinculación y profesores',
                  isDark: isDark,
                  onTap: () => context.push(AppRoutes.family),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Seguridad ─────────────────────────────────────────
          _SectionHeader(title: 'Seguridad', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Cambiar contraseña',
                subtitle: 'Actualiza tu contraseña de acceso',
                isDark: isDark,
                trailing: Icon(
                  _showChangePassword
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.accentBlue,
                ),
                onTap: () => setState(
                  () => _showChangePassword = !_showChangePassword,
                ),
              ),
              if (_showChangePassword) ...[
                const Divider(height: 1),
                _ChangePasswordForm(isDark: isDark),
              ],
              const Divider(height: 1),
              _BiometricToggleTile(isDark: isDark),
              const Divider(height: 1),
              _LinkGoogleTile(isDark: isDark),
            ],
          ),
          const SizedBox(height: 20),

          // ── Apariencia ────────────────────────────────────────
          _SectionHeader(title: 'Apariencia', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [_ThemeToggleTile(isDark: isDark)],
          ),
          const SizedBox(height: 20),

          // ── Notificaciones ────────────────────────────────────
          _SectionHeader(title: 'Notificaciones', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
              // Historial
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Historial de notificaciones',
                subtitle: unread > 0 ? '$unread sin leer' : 'Todo al día',
                isDark: isDark,
                iconColor: unread > 0 ? AppColors.statusAmber : AppColors.accentBlue,
                trailing: unread > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.statusAmber,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : null,
                onTap: () => context.push(AppRoutes.notifications),
              ),
              const Divider(height: 1),

              // Sonido — preview al activar
              _NotifToggleTile(
                icon: Icons.volume_up_rounded,
                title: 'Sonido',
                subtitle: 'Reproducir sonido al notificar',
                isDark: isDark,
                provider: notifSoundProvider,
                onEnable: () async {
                  final uri = ref.read(notifRingtoneProvider).uri;
                  await RingtoneService.instance.play(uri: uri);
                },
              ),
              const Divider(height: 1),

              // Tono de notificación (selector del sistema)
              _RingtoneTile(isDark: isDark),
              const Divider(height: 1),

              // Vibración — vibra al activar
              _NotifToggleTile(
                icon: Icons.vibration_rounded,
                title: 'Vibración',
                subtitle: 'Vibrar al recibir notificaciones de vencimiento',
                isDark: isDark,
                provider: notifVibrationProvider,
                onEnable: () async {
                  final p = ref.read(notifVibrationPatternProvider);
                  await RingtoneService.instance.vibrate(pattern: p);
                },
              ),
              // Duración de vibración (solo visible cuando vibración está activa)
              _VibrationPatternTile(isDark: isDark),
            ],
          ),
          const SizedBox(height: 20),

          // ── Información ───────────────────────────────────────
          _SectionHeader(title: 'Información', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'Versión de la app',
                subtitle: 'EduTrack Family v${AppStrings.appVersion}',
                isDark: isDark,
                onTap: null,
              ),
              const Divider(height: 1),
              _SettingsTile(
                icon: Icons.school_rounded,
                title: 'Almacenamiento',
                subtitle: 'Fotos y datos guardados en el dispositivo',
                isDark: isDark,
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Cerrar sesión ─────────────────────────────────────
          _LogoutButton(isDark: isDark),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PERFIL
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends ConsumerWidget {
  final dynamic user;
  final bool isDark;

  const _ProfileCard({required this.user, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoPath = ref.watch(profilePhotoProvider(user.id as String));
    final accentColor = (user.isAdmin as bool)
        ? AppColors.accentBlue
        : AppColors.statusGreen;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar con foto o emoji + badge cámara
          GestureDetector(
            onTap: () => ref
                .read(profilePhotoProvider(user.id as String).notifier)
                .pickFromGallery(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.30),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: photoPath != null && File(photoPath).existsSync()
                        ? Image.file(
                            File(photoPath),
                            fit: BoxFit.cover,
                            width: 64,
                            height: 64,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(user.avatarEmoji as String,
                                  style: const TextStyle(fontSize: 28)),
                            ),
                          )
                        : Center(
                            child: Text(user.avatarEmoji as String,
                                style: const TextStyle(fontSize: 28)),
                          ),
                  ),
                ),
                // Badge cámara
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1E1E2E)
                            : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user.isAdmin as bool) ? 'Administrador' : 'Estudiante',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Usuario: ${user.username}',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: isDark ? Colors.white54 : AppColors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Toca la foto para cambiarla',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 11,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              (user.isAdmin as bool) ? 'Admin' : 'Estudiante',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORMULARIO CAMBIAR CONTRASEÑA
// ─────────────────────────────────────────────────────────────
class _ChangePasswordForm extends ConsumerStatefulWidget {
  final bool isDark;
  const _ChangePasswordForm({required this.isDark});

  @override
  ConsumerState<_ChangePasswordForm> createState() =>
      _ChangePasswordFormState();
}

class _ChangePasswordFormState extends ConsumerState<_ChangePasswordForm> {
  final _formKey      = GlobalKey<FormState>();
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    final result = await ref.read(authProvider.notifier).changePassword(
          currentPassword: _currentCtrl.text.trim(),
          newPassword:     _newCtrl.text.trim(),
          confirmPassword: _confirmCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.isSuccess
            ? AppColors.statusGreen
            : AppColors.statusRed,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (result.isSuccess) {
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _PasswordField(
              controller: _currentCtrl,
              label: 'Contraseña actual',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
            ),
            const SizedBox(height: 10),
            _PasswordField(
              controller: _newCtrl,
              label: 'Nueva contraseña',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 10),
            _PasswordField(
              controller: _confirmCtrl,
              label: 'Confirmar nueva contraseña',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirma la nueva contraseña';
                if (v != _newCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // FIX: sin SizedBox de altura fija que corta el texto
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Guardar contraseña',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
          ),
          onPressed: onToggle,
        ),
        isDense: true,
      ),
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOGGLE TEMA
// ─────────────────────────────────────────────────────────────
class _ThemeToggleTile extends ConsumerWidget {
  final bool isDark;
  const _ThemeToggleTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isCurrentlyDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return ListTile(
      leading: Icon(
        isCurrentlyDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        color: AppColors.accentBlue,
      ),
      title: Text(
        'Modo oscuro',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        isCurrentlyDark ? 'Activado' : 'Desactivado',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: Switch(
        value: isCurrentlyDark,
        onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
        activeThumbColor: AppColors.accentBlue,
        activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOGGLE BIOMETRÍA (huella / Face ID)
// ─────────────────────────────────────────────────────────────
class _BiometricToggleTile extends ConsumerStatefulWidget {
  final bool isDark;
  const _BiometricToggleTile({required this.isDark});

  @override
  ConsumerState<_BiometricToggleTile> createState() =>
      _BiometricToggleTileState();
}

class _BiometricToggleTileState extends ConsumerState<_BiometricToggleTile> {
  bool _available = false;

  @override
  void initState() {
    super.initState();
    BiometricService.instance.isAvailable().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final enabled = ref.watch(
        authProvider.select((_) =>
            ref.read(authProvider.notifier).biometricEnabled));

    return ListTile(
      leading:
          const Icon(Icons.fingerprint, color: AppColors.accentBlue, size: 24),
      title: Text(
        'Desbloqueo con huella',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: widget.isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        'Pide tu huella al abrir la app',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: widget.isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (v) async {
          if (v) {
            // Confirmar identidad antes de activar
            final ok = await BiometricService.instance
                .authenticate(reason: 'Confirma tu huella para activar');
            if (!ok) return;
          }
          await ref.read(authProvider.notifier).setBiometricEnabled(v);
          if (mounted) setState(() {});
        },
        activeThumbColor: AppColors.accentBlue,
        activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// VINCULAR CUENTA DE GOOGLE
// ─────────────────────────────────────────────────────────────
class _LinkGoogleTile extends ConsumerWidget {
  final bool isDark;
  const _LinkGoogleTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null || user.isStudent) return const SizedBox.shrink();
    final linked = user.hasGoogleLinked;

    return ListTile(
      leading: const Icon(Icons.link_rounded,
          color: AppColors.accentBlue, size: 24),
      title: Text(
        linked ? 'Google vinculado' : 'Vincular con Google',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        linked
            ? 'Puedes iniciar sesión con tu cuenta de Google'
            : 'Entra también con tu cuenta de Google',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: linked
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.chevron_right_rounded),
      onTap: linked
          ? null
          : () async {
              final result =
                  await ref.read(authProvider.notifier).linkWithGoogle();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(result.ok
                    ? 'Cuenta de Google vinculada ✓'
                    : result.error!),
                backgroundColor: result.ok
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ));
            },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOGGLE SONIDO / VIBRACIÓN
// ─────────────────────────────────────────────────────────────
class _NotifToggleTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final StateNotifierProvider<BoolPrefNotifier, bool> provider;
  final Future<void> Function()? onEnable;

  const _NotifToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.provider,
    this.onEnable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(provider);
    return ListTile(
      leading: Icon(icon, color: AppColors.accentBlue, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: Switch(
        value: enabled,
        onChanged: (v) async {
          await ref.read(provider.notifier).set(v);
          if (v) await onEnable?.call();
        },
        activeThumbColor: AppColors.accentBlue,
        activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SELECTOR DE TONO DEL SISTEMA
// ─────────────────────────────────────────────────────────────
class _RingtoneTile extends ConsumerWidget {
  final bool isDark;
  const _RingtoneTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringtone      = ref.watch(notifRingtoneProvider);
    final soundEnabled  = ref.watch(notifSoundProvider);

    return ListTile(
      leading: Icon(
        Icons.music_note_rounded,
        color: soundEnabled ? AppColors.accentBlue : AppColors.grey,
        size: 22,
      ),
      title: Text(
        'Tono de notificación',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: soundEnabled
              ? (isDark ? Colors.white : AppColors.navyBlue)
              : (isDark ? Colors.white30 : AppColors.lightGrey),
        ),
      ),
      subtitle: Text(
        ringtone.name,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: isDark ? Colors.white38 : AppColors.grey,
        ),
      ),
      trailing: soundEnabled
          ? Icon(Icons.chevron_right_rounded,
              color: isDark ? Colors.white30 : Colors.black26)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onTap: soundEnabled
          ? () async {
              final svc    = RingtoneService.instance;
              final result = await svc.pickRingtone(currentUri: ringtone.uri);
              if (result == null || !context.mounted) return;
              await svc.stop();
              await ref.read(notifRingtoneProvider.notifier).setRingtone(
                    uri:  result.uri,
                    name: result.name,
                  );
            }
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SELECTOR DURACIÓN DE VIBRACIÓN — chips Corta / Media / Larga
// Solo visible cuando el toggle de vibración está activado
// ─────────────────────────────────────────────────────────────
class _VibrationPatternTile extends ConsumerWidget {
  final bool isDark;
  const _VibrationPatternTile({required this.isDark});

  static const _options = [
    ('short',  'Corta',  Icons.vibration_rounded),
    ('medium', 'Media',  Icons.vibration_rounded),
    ('long',   'Larga',  Icons.vibration_rounded),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibEnabled = ref.watch(notifVibrationProvider);
    if (!vibEnabled) return const SizedBox.shrink();

    final current = ref.watch(notifVibrationPatternProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Duración de vibración',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : AppColors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (value, label, _) in _options) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      await ref
                          .read(notifVibrationPatternProvider.notifier)
                          .set(value);
                      await RingtoneService.instance.vibrate(pattern: value);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: current == value
                            ? AppColors.accentBlue
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.background),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: current == value
                              ? AppColors.accentBlue
                              : (isDark ? Colors.white12 : AppColors.lightGrey),
                        ),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: current == value
                              ? Colors.white
                              : (isDark ? Colors.white60 : AppColors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (value != 'long') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN CERRAR SESIÓN
// ─────────────────────────────────────────────────────────────
class _LogoutButton extends ConsumerStatefulWidget {
  final bool isDark;
  const _LogoutButton({required this.isDark});

  @override
  ConsumerState<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends ConsumerState<_LogoutButton> {
  bool _isLoading = false;

  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Cerrar sesión',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '¿Estás seguro? Tendrás que ingresar tu contraseña para volver a entrar.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusRed),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      // Cede 2 frames para que el spinner se renderice antes de que
      // logout() actualice el estado y GoRouter redirija.
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _confirmLogout,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isLoading
              ? AppColors.statusRed.withValues(alpha: 0.6)
              : AppColors.statusRed,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isLoading
            ? const RepaintBoundary(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.2,
                  ),
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPONENTES REUTILIZABLES
// ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: isDark ? Colors.white38 : AppColors.grey,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.accentBlue, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right_rounded,
                  color: isDark ? Colors.white30 : Colors.black26)
              : null),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
