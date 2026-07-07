import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/theme_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/providers/notification_settings_provider.dart';
import 'package:edutrack_family/core/providers/profile_photo_provider.dart';
import 'package:edutrack_family/core/services/ringtone_service.dart';
import 'package:edutrack_family/core/services/biometric_service.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';
import 'package:edutrack_family/features/location/child/location_permission_help.dart';
import 'package:edutrack_family/features/location/child/tracking_service.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'package:edutrack_family/features/auth/presentation/biometric_gate_screen.dart'
    show biometricAvailableProvider;

// ═══════════════════════════════════════════════════════════════
// SETTINGS SCREEN — EduTrack Family
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
      body: CenteredConstrained(
        maxWidth: 960,
        child: ListView(
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
                  title: user.isTeacher ? 'Mis estudiantes' : 'Mi familia',
                  subtitle: RoleCopy.familySettingsSubtitle(user.role),
                  isDark: isDark,
                  onTap: () => context.push(AppRoutes.family),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Acceso y cuenta ────────────────────────────────────
          // (método de login, vincular Google, contraseña — todo lo
          // relacionado a "cómo entro" en una sola subzona)
          _SectionHeader(title: 'Acceso y cuenta', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
              _LoginMethodTile(isDark: isDark),
              const Divider(height: 1),
              _LinkGoogleTile(isDark: isDark),
              // Un solo camino para cambiar la contraseña: por correo.
              // Antes había también un formulario en la app pidiendo
              // la contraseña actual — dos botones para lo mismo es
              // redundante y confuso; el flujo por correo además es
              // el más seguro (Firebase invalida la sesión actual al
              // cambiarla, forzando un login limpio con la nueva).
              if (user.hasPasswordProvider) ...[
                const Divider(height: 1),
                _ResetPasswordEmailTile(isDark: isDark),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // ── Bloqueo de la app ──────────────────────────────────
          // (subzona separada: "cómo protejo el acceso una vez que
          // ya inicié sesión" es un tema distinto de "cómo inicio
          // sesión". Oculta por completo si el dispositivo no tiene
          // huella/Windows Hello — no hay nada que configurar ahí.)
          if (ref.watch(biometricAvailableProvider).valueOrNull ?? false) ...[
            _SectionHeader(title: 'Bloqueo de la app', isDark: isDark),
            _SettingsCard(
              isDark: isDark,
              children: [
                _BiometricToggleTile(isDark: isDark),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // ── Ubicación (solo estudiante, solo Android — GPS es
          // exclusivo de móvil) ─────────────────────────────────
          if (user.isStudent && !kIsWeb && Platform.isAndroid) ...[
            _SectionHeader(title: 'Ubicación', isDark: isDark),
            _SettingsCard(
              isDark: isDark,
              children: [_LocationShareToggleTile(isDark: isDark, studentId: user.id)],
            ),
            const SizedBox(height: 20),
          ],

          // ── Apariencia ────────────────────────────────────────
          _SectionHeader(title: 'Apariencia', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [_ThemeToggleTile(isDark: isDark)],
          ),
          const SizedBox(height: 20),

          // ── Notificaciones: historial ──────────────────────────
          _SectionHeader(title: 'Notificaciones', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
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
            ],
          ),
          const SizedBox(height: 20),

          // ── Sonido y vibración (subzona aparte: "cómo suena" es
          // distinto de "qué se guardó") ─────────────────────────
          _SectionHeader(title: 'Sonido y vibración', isDark: isDark),
          _SettingsCard(
            isDark: isDark,
            children: [
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
              // Tono de notificación y Vibración: ambos usan un canal
              // nativo (com.edutrack/ringtone, com.edutrack/vibrate)
              // que SOLO existe en Android (ver ringtone_service.dart,
              // _isAndroid) — en cualquier otra plataforma serían
              // botones muertos, así que se ocultan por completo.
              if (!kIsWeb && Platform.isAndroid) ...[
                const Divider(height: 1),
                _RingtoneTile(isDark: isDark),
                const Divider(height: 1),
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
                  (user.role as UserRole).label,
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
              (user.role as UserRole).label,
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
// TOGGLE COMPARTIR UBICACIÓN (hijo) — apagarlo desde acá ahorra
// batería sin tener que esperar a que el padre/tutor lo desactive.
// Solo aparece si el padre/tutor ya activó "compartir ubicación" —
// si nunca lo pidió, no hay nada que apagar acá.
// ─────────────────────────────────────────────────────────────
class _LocationShareToggleTile extends ConsumerStatefulWidget {
  final bool isDark;
  final String studentId;
  const _LocationShareToggleTile({required this.isDark, required this.studentId});

  @override
  ConsumerState<_LocationShareToggleTile> createState() =>
      _LocationShareToggleTileState();
}

class _LocationShareToggleTileState
    extends ConsumerState<_LocationShareToggleTile> {
  bool _busy = false;

  Future<void> _toggle(bool wantOn) async {
    setState(() => _busy = true);
    try {
      if (wantOn) {
        final error = await TrackingService.instance.ensurePermissions();
        if (error != null) {
          // Se guarda en Firestore (no solo el diálogo de abajo) para
          // que este mismo interruptor siga mostrando el motivo
          // aunque el usuario cierre el diálogo sin resolverlo.
          await LocationRepository.instance
              .setPermissionError(widget.studentId, error);
          if (mounted) {
            await showLocationPermissionHelp(context, error,
                retryLabel: 'Compartir ubicación');
          }
          return;
        }
        await LocationRepository.instance
            .setPermissionError(widget.studentId, null);
        await LocationRepository.instance
            .setDeviceConfirmed(widget.studentId, true);
        await TrackingService.instance.start(widget.studentId);
      } else {
        await TrackingService.instance.stop();
        await LocationRepository.instance
            .setDeviceConfirmed(widget.studentId, false);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        ({bool enabledByParent, bool deviceConfirmed, String? permissionError})>(
      stream: LocationRepository.instance.watchConsent(widget.studentId),
      builder: (context, snap) {
        final consent = snap.data;
        final enabledByParent = consent?.enabledByParent ?? false;
        final deviceConfirmed = consent?.deviceConfirmed ?? false;
        final permissionError = consent?.permissionError;

        // El padre/tutor nunca lo pidió — no hay nada que mostrar.
        if (!enabledByParent) return const SizedBox.shrink();

        return ListTile(
          leading: Icon(
            Icons.location_on_rounded,
            color: permissionError != null
                ? AppColors.statusRed
                : deviceConfirmed
                    ? AppColors.statusGreen
                    : AppColors.grey,
            size: 22,
          ),
          title: Text(
            'Compartir ubicación',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: widget.isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          subtitle: Text(
            // Sin este caso, "Activo" se mostraba igual aunque en
            // realidad no hubiera podido arrancar por falta de un
            // permiso — el hijo no tenía ninguna pista del problema.
            permissionError ??
                (deviceConfirmed
                    ? 'Activo — usa batería mientras esté encendido'
                    : 'Apagado'),
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: permissionError != null
                  ? AppColors.statusRed
                  : (widget.isDark ? Colors.white54 : AppColors.grey),
            ),
          ),
          trailing: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Nada vuelve a revisar el permiso solo cuando el
                    // hijo ya fue a Ajustes y lo activó — el
                    // coordinador solo reacciona a cambios en
                    // Firestore, no a que el sistema operativo haya
                    // cambiado de opinión. Sin este botón, había que
                    // apagar y volver a prender el switch para forzar
                    // un nuevo intento.
                    if (permissionError != null)
                      IconButton(
                        tooltip: 'Ya lo activé, revisar de nuevo',
                        icon: const Icon(Icons.refresh_rounded,
                            color: AppColors.statusRed),
                        onPressed: () => _toggle(true),
                      ),
                    Switch(
                      value: deviceConfirmed,
                      onChanged: _toggle,
                      activeThumbColor: AppColors.statusGreen,
                    ),
                  ],
                ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOGGLE BIOMETRÍA (huella / Face ID)
// ─────────────────────────────────────────────────────────────
// Sin chequeo de disponibilidad propio: el padre (settings_screen.dart)
// ya gatea esta tarjeta completa con biometricAvailableProvider antes
// de construir este widget — repetirlo acá con un initState().then()
// aparte solo causaba que la fila apareciera vacía un instante y
// "saltara" al resolver, cada vez que se abría Ajustes.
//
// Estado LOCAL (no ref.watch(authProvider...)): biometricEnabled vive
// en SharedPreferences, no en el SessionUser? de authProvider, así
// que cambiarlo nunca disparaba una notificación de Riverpod — el
// switch se quedaba visualmente pegado en su valor original sin
// importar cuántas veces se tocara. La lectura inicial es síncrona
// (SharedPreferences ya cargado), así que no reintroduce el bug del
// "salto" que sí causaba el chequeo ASÍNCRONO de disponibilidad.
class _BiometricToggleTile extends ConsumerStatefulWidget {
  final bool isDark;
  const _BiometricToggleTile({required this.isDark});

  @override
  ConsumerState<_BiometricToggleTile> createState() =>
      _BiometricToggleTileState();
}

class _BiometricToggleTileState extends ConsumerState<_BiometricToggleTile> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = ref.read(authProvider.notifier).biometricEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final isWindows = !kIsWeb && Platform.isWindows;
    return ListTile(
      leading: Icon(
          isWindows ? Icons.password_rounded : Icons.fingerprint,
          color: AppColors.accentBlue, size: 24),
      title: Text(
        isWindows ? 'Desbloqueo con Windows Hello' : 'Desbloqueo con huella',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: widget.isDark ? Colors.white : AppColors.navyBlue,
        ),
      ),
      subtitle: Text(
        isWindows
            ? 'Pide Windows Hello al abrir la app'
            : 'Pide tu huella al abrir la app',
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: 12,
          color: widget.isDark ? Colors.white54 : AppColors.grey,
        ),
      ),
      trailing: Switch(
        value: _enabled,
        onChanged: (v) async {
          if (v) {
            // Confirmar identidad antes de activar
            final ok = await BiometricService.instance.authenticate(
                reason: isWindows
                    ? 'Confirma con Windows Hello para activar'
                    : 'Confirma tu huella para activar');
            if (!ok) return;
          }
          await ref.read(authProvider.notifier).setBiometricEnabled(v);
          if (mounted) setState(() => _enabled = v);
        },
        activeThumbColor: AppColors.accentBlue,
        activeTrackColor: AppColors.accentBlue.withValues(alpha: 0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MÉTODO DE INICIO DE SESIÓN — indicador de solo lectura
// ─────────────────────────────────────────────────────────────
class _LoginMethodTile extends ConsumerWidget {
  final bool isDark;
  const _LoginMethodTile({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    if (user == null) return const SizedBox.shrink();

    // El estudiante entra por custom token (código de vinculación) —
    // nunca tiene proveedor 'password' ni 'google.com', así que sin
    // este caso especial siempre caía en el "else" y decía "Correo y
    // contraseña" aunque nunca puso ninguna.
    if (user.isStudent) {
      return _SettingsTile(
        icon: Icons.qr_code_2_rounded,
        title: 'Método de inicio de sesión',
        subtitle: 'Código de vinculación (cuenta estudiante)',
        isDark: isDark,
      );
    }

    final hasGoogle = user.hasGoogleLinked;
    final hasPassword = user.hasPasswordProvider;
    final label = hasGoogle && hasPassword
        ? 'Google y correo/contraseña'
        : hasGoogle
            ? 'Google'
            : 'Correo y contraseña';

    return _SettingsTile(
      icon: hasGoogle ? Icons.g_mobiledata_rounded : Icons.email_outlined,
      title: 'Método de inicio de sesión',
      subtitle: label,
      isDark: isDark,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RESTABLECER CONTRASEÑA POR CORREO
// ─────────────────────────────────────────────────────────────
class _ResetPasswordEmailTile extends ConsumerStatefulWidget {
  final bool isDark;
  const _ResetPasswordEmailTile({required this.isDark});

  @override
  ConsumerState<_ResetPasswordEmailTile> createState() =>
      _ResetPasswordEmailTileState();
}

class _ResetPasswordEmailTileState
    extends ConsumerState<_ResetPasswordEmailTile> {
  bool _sending = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  Timer? _sessionPollTimer;
  int _pollTicks = 0;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _sessionPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final user = ref.read(authProvider);
    if (user?.email == null || _sending || _cooldown > 0) return;
    setState(() => _sending = true);
    final result =
        await ref.read(authProvider.notifier).sendPasswordReset(user!.email!);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.ok
          ? 'Enlace enviado a ${user.email} ✓'
          : result.error ?? 'No se pudo enviar el correo.'),
      backgroundColor:
          result.ok ? AppColors.statusGreen : AppColors.statusRed,
      behavior: SnackBarBehavior.floating,
    ));
    if (result.ok) {
      // Enfriamiento de 60s: evita spamear el envío (Firebase igual
      // tiene su propio límite en el servidor, pero devolvería un
      // error confuso en vez de esta cuenta regresiva clara).
      setState(() => _cooldown = 60);
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        setState(() => _cooldown--);
        if (_cooldown <= 0) t.cancel();
      });
      _startSessionPolling();
    }
  }

  /// Tras enviar el enlace, revisa cada 5s (hasta 5 min) si la
  /// contraseña ya se cambió — Firebase invalida el refresh token de
  /// inmediato al completarse, así que validateSession() lo detecta
  /// y cierra la sesión sin esperar a que el token viejo expire solo.
  /// El router hace el resto (state==null → /login) apenas ocurra.
  void _startSessionPolling() {
    _sessionPollTimer?.cancel();
    _pollTicks = 0;
    _sessionPollTimer = Timer.periodic(const Duration(seconds: 5), (t) async {
      _pollTicks++;
      if (!mounted || _pollTicks > 60) {
        t.cancel();
        return;
      }
      await ref.read(authProvider.notifier).validateSession();
      // Si la sesión se invalidó, validateSession() ya disparó el
      // signOut y el router nos saca de Ajustes solo (state==null);
      // el próximo tick de este mismo timer se cancela arriba por
      // "!mounted" apenas el widget se desmonte.
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: Icons.mail_outline_rounded,
      title: 'Restablecer por correo',
      subtitle: _sending
          ? 'Enviando...'
          : _cooldown > 0
              ? 'Puedes reenviar en $_cooldown s'
              : '¿Olvidaste tu contraseña? Te enviamos un enlace',
      isDark: widget.isDark,
      onTap: (_sending || _cooldown > 0) ? null : _send,
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
    // Ventana ancha (Windows/Linux en la práctica) → look Fluent:
    // borde fino en vez de sombra, filas separadas por línea en vez
    // de una sola tarjeta flotante. Teléfono se queda con el
    // Material de siempre.
    final fluent = context.isMedium || context.isExpanded;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final radius = fluent ? 8.0 : 16.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: fluent ? Border.all(color: borderColor) : null,
        boxShadow: fluent
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      // Material (no un Container con color) es el ancestro que
      // necesitan los ListTile internos para pintar su efecto de
      // tinta al tocar — un DecoratedBox con color de fondo directo
      // lo tapa (warning de Flutter: "ink splashes may be invisible").
      child: Material(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: fluent && children.length > 1
              ? _withDividers(children, borderColor)
              : children,
        ),
      ),
    );
  }

  List<Widget> _withDividers(List<Widget> items, Color color) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(Divider(
          height: 1,
          thickness: 1,
          indent: 16,
          endIndent: 16,
          color: color,
        ));
      }
    }
    return out;
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
