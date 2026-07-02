import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
// PERMISSION GATE SCREEN — EduTrack Family
// Pantalla bloqueante que solicita los permisos críticos antes
// de permitir el acceso a la app.
// ═══════════════════════════════════════════════════════════════

class PermissionGateScreen extends ConsumerStatefulWidget {
  const PermissionGateScreen({super.key});

  @override
  ConsumerState<PermissionGateScreen> createState() =>
      _PermissionGateScreenState();
}

class _PermissionGateScreenState extends ConsumerState<PermissionGateScreen>
    with WidgetsBindingObserver {
  bool _notifGranted = false;
  bool _exactAlarmGranted = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-verifica cuando el usuario regresa de Ajustes del sistema
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkAll();
  }

  Future<void> _checkAll() async {
    setState(() => _isChecking = true);
    bool notif = true;
    bool alarm = true;
    try {
      notif = await Permission.notification.isGranted;
      if (Platform.isAndroid) {
        alarm = await Permission.scheduleExactAlarm.isGranted;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _notifGranted = notif;
      _exactAlarmGranted = alarm;
      _isChecking = false;
    });

    if (_notifGranted && _exactAlarmGranted) _proceed();
  }

  void _proceed() {
    final user = ref.read(authProvider);
    if (user == null) {
      context.go(AppRoutes.login);
    } else if (user.isAdmin) {
      context.go(AppRoutes.admin);
    } else {
      context.go(AppRoutes.student);
    }
  }

  Future<void> _requestNotif() async {
    final status = await Permission.notification.request();
    final granted = status.isGranted || status.isLimited;
    setState(() => _notifGranted = granted);
    if (granted && _exactAlarmGranted) _proceed();
  }

  Future<void> _requestExactAlarm() async {
    final status = await Permission.scheduleExactAlarm.request();
    if (status.isGranted) {
      setState(() => _exactAlarmGranted = true);
      if (_notifGranted) _proceed();
    } else {
      // Android 12: abre los Ajustes del sistema directamente
      await openAppSettings();
      // _checkAll() se llama automáticamente en didChangeAppLifecycleState.resumed
    }
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _notifGranted && _exactAlarmGranted;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.gradientNavy),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52),

                // ── Ícono y título ────────────────────────────────
                const Text('🔐', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 18),
                const Text(
                  'Permisos necesarios',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Para enviarte alertas de tareas exactamente a tiempo, '
                  'la app necesita los siguientes permisos antes de continuar.',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Tarjeta: Notificaciones ───────────────────────
                _PermCard(
                  icon: Icons.notifications_rounded,
                  title: 'Notificaciones',
                  description:
                      'Recibe alertas cuando una tarea vence hoy o es urgente.',
                  granted: _notifGranted,
                  onGrant: _isChecking ? null : _requestNotif,
                ),

                // ── Tarjeta: Alarmas exactas (Android) ───────────
                if (isAndroid) ...[
                  const SizedBox(height: 14),
                  _PermCard(
                    icon: Icons.alarm_rounded,
                    title: 'Alarmas exactas',
                    description:
                        'Las alertas llegan puntualmente aunque el teléfono '
                        'esté en segundo plano.',
                    granted: _exactAlarmGranted,
                    onGrant: _isChecking ? null : _requestExactAlarm,
                    grantLabel: 'Ir a Ajustes',
                  ),
                ],

                const Spacer(),

                // ── Botón continuar ───────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: allGranted && !_isChecking ? _proceed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navyBlue,
                      disabledBackgroundColor: Colors.white24,
                      disabledForegroundColor: Colors.white38,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: AppColors.navyBlue,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            allGranted
                                ? 'Continuar →'
                                : 'Activa los permisos para continuar',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA DE PERMISO
// ─────────────────────────────────────────────────────────────
class _PermCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool granted;
  final VoidCallback? onGrant;
  final String grantLabel;

  const _PermCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.granted,
    required this.onGrant,
    this.grantLabel = 'Activar',
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: granted ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted
              ? AppColors.statusGreen.withValues(alpha: 0.7)
              : Colors.white24,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Ícono
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: granted
                  ? AppColors.statusGreen.withValues(alpha: 0.18)
                  : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: granted ? AppColors.statusGreen : Colors.white54,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // Texto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            granted ? AppColors.statusGreen : Colors.white,
                      ),
                    ),
                    if (granted) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.statusGreen,
                        size: 16,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: Colors.white54,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Botón activar
          if (!granted) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onGrant,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentBlue,
                backgroundColor: AppColors.accentBlue.withValues(alpha: 0.18),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                grantLabel,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
