import 'package:flutter/material.dart';

import 'package:edutrack_family/core/services/ringtone_service.dart';
import 'safety_alert_coordinator.dart';

// ═══════════════════════════════════════════════════════════════
// ALERTA SÍSMICA — pantalla completa
// Igual que el check-in "¿Estás bien?": suena en bucle (alarma,
// ignora el silencio) y vibra sin parar hasta que el usuario toca
// "Entendido" — un aviso de sismo real no debe poder pasar
// inadvertido con un solo beep. Se muestra a TODOS los roles
// vinculados al estudiante (padre/tutor, profesor y el propio
// estudiante), no solo a quien comparte ubicación.
// ═══════════════════════════════════════════════════════════════

class SeismicAlertScreen extends StatefulWidget {
  final String title;
  final String body;

  const SeismicAlertScreen({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  State<SeismicAlertScreen> createState() => _SeismicAlertScreenState();
}

class _SeismicAlertScreenState extends State<SeismicAlertScreen> {
  @override
  void initState() {
    super.initState();
    // Sonido propio (alerta_sismica), distinto al del check-in "¿Estás
    // bien?" (alert_sound) — para no confundir ambas alertas de voz.
    RingtoneService.instance.startAlarmLoop(sound: 'alerta_sismica');
    // Mientras esta pantalla esté activa, el check-in "¿Estás bien?"
    // del hijo (si llega al mismo tiempo) espera a que se acepte esto
    // primero — un sismo real tiene prioridad.
    SafetyAlertCoordinator.instance.markSeismicActive();
  }

  @override
  void dispose() {
    RingtoneService.instance.stopAlarmLoop();
    SafetyAlertCoordinator.instance.markSeismicCleared();
    super.dispose();
  }

  Future<void> _dismiss(BuildContext context) async {
    await RingtoneService.instance.stopAlarmLoop();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No se cierra con el botón atrás — hay que confirmar que se
      // leyó, igual que el check-in de seguridad.
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF7A0C0C),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌍', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 16),
                    const Text(
                      'ALERTA SÍSMICA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ponte en un lugar seguro, mantén la calma y espera '
                      'instrucciones.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () => _dismiss(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF7A0C0C),
                        minimumSize: const Size.fromHeight(74),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('ACEPTAR',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
