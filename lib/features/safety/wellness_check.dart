import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/services/push_queue_service.dart';
import 'package:edutrack_family/core/services/ringtone_service.dart';

// ═══════════════════════════════════════════════════════════════
// CHECK-IN "¿ESTÁS BIEN?" — EduTrack Family 2.0
//
// Padre pulsa "Verificar estado" → doc wellnessChecks pending
// (expira en 3 min) + push al hijo. El hijo responde con botones
// grandes. Si no responde, la Cloud Function checkWellnessTimeouts
// lo cierra y alerta a los padres (aunque el padre cierre la app).
// El padre además ve una cuenta regresiva local en vivo.
// ═══════════════════════════════════════════════════════════════

const wellnessTimeout = Duration(minutes: 3);

// ─────────────────────────────────────────────────────────────
// LADO PADRE — disparar y observar
// ─────────────────────────────────────────────────────────────

Future<void> startWellnessCheck(
  BuildContext context,
  WidgetRef ref,
  String studentId,
  String studentName,
) async {
  final user = ref.read(authProvider);
  if (user == null) return;

  final db = FirebaseFirestore.instance;
  final checkRef =
      db.collection(FirestorePaths.wellnessChecks(studentId)).doc();

  await checkRef.set({
    'status': 'pending',
    'requestedBy': user.uid,
    'requestedAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(DateTime.now().add(wellnessTimeout)),
  });

  // Push urgente al dispositivo del hijo
  await PushQueueService.instance.sendToUids(
    [studentId],
    title: '🧡 ¿Estás bien?',
    body: 'Tu familia quiere saber cómo estás. Responde con un toque.',
    data: {'type': 'wellness_check', 'checkId': checkRef.id},
  );

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ParentWaitingDialog(
      studentId: studentId,
      studentName: studentName,
      checkId: checkRef.id,
    ),
  );
}

class _ParentWaitingDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String checkId;

  const _ParentWaitingDialog({
    required this.studentId,
    required this.studentName,
    required this.checkId,
  });

  @override
  State<_ParentWaitingDialog> createState() => _ParentWaitingDialogState();
}

class _ParentWaitingDialogState extends State<_ParentWaitingDialog> {
  late final Timer _ticker;
  int _remaining = wellnessTimeout.inSeconds;
  StreamSubscription? _sub;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0 && mounted) setState(() => _remaining--);
    });
    _sub = FirebaseFirestore.instance
        .doc(FirestorePaths.wellnessCheck(widget.studentId, widget.checkId))
        .snapshots()
        .listen((snap) {
      final status = (snap.data()?['status'] ?? 'pending') as String;
      if (mounted && status != _status) setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, title, body, color) = switch (_status) {
      'ok' => (
          '✅',
          '¡${widget.studentName} está bien!',
          'Respondió que está bien.',
          Colors.green
        ),
      'help' => (
          '🆘',
          '¡${widget.studentName} pide ayuda!',
          'Respondió que NECESITA AYUDA. Llámale y revisa su ubicación.',
          Colors.red
        ),
      'no_response' => (
          '⚠️',
          'Sin respuesta',
          'No respondió en 3 minutos. Puede ser falta de conexión o batería '
              '— no significa necesariamente que algo pasó. Revisa su última '
              'ubicación y llámale.',
          Colors.orange
        ),
      _ => (
          '⏳',
          'Esperando respuesta…',
          '${widget.studentName} recibió el aviso. '
              'Tiempo restante: ${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
          AppColors.accentBlue
        ),
    };

    final finished = _status != 'pending';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style:
                    TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(body),
          if (!finished) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: _remaining / wellnessTimeout.inSeconds,
              color: color,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(finished ? 'Cerrar' : 'Seguir esperando en segundo plano'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LADO HIJO — gate que detecta checks pendientes y responde
// ─────────────────────────────────────────────────────────────

/// Widget invisible en la shell del estudiante: escucha los
/// wellnessChecks pendientes y muestra la pantalla de respuesta.
class WellnessCheckGate extends ConsumerStatefulWidget {
  const WellnessCheckGate({super.key});

  @override
  ConsumerState<WellnessCheckGate> createState() => _WellnessCheckGateState();
}

class _WellnessCheckGateState extends ConsumerState<WellnessCheckGate> {
  StreamSubscription? _sub;
  final Set<String> _handled = {};
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listen());
  }

  void _listen() {
    final user = ref.read(authProvider);
    if (user == null || !user.isStudent) return;

    _sub = FirebaseFirestore.instance
        .collection(FirestorePaths.wellnessChecks(user.uid))
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final expires = doc.get('expiresAt') as Timestamp?;
        if (expires != null && expires.toDate().isBefore(DateTime.now())) {
          continue; // vencido, lo cierra la Cloud Function
        }
        if (_handled.contains(doc.id) || _showing) continue;
        _handled.add(doc.id);
        _show(user.uid, doc.id);
      }
    });
  }

  Future<void> _show(String studentId, String checkId) async {
    if (!mounted) return;
    _showing = true;
    RingtoneService.instance.vibrate(pattern: 'long');
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            WellnessResponseScreen(studentId: studentId, checkId: checkId),
      ),
    );
    _showing = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Pantalla a pantalla completa con los dos botones grandes.
class WellnessResponseScreen extends StatelessWidget {
  final String studentId;
  final String checkId;

  const WellnessResponseScreen({
    super.key,
    required this.studentId,
    required this.checkId,
  });

  Future<void> _respond(BuildContext context, String status) async {
    await FirebaseFirestore.instance
        .doc(FirestorePaths.wellnessCheck(studentId, checkId))
        .update({
      'status': status,
      'respondedAt': DateTime.now().toIso8601String(),
    });
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Text('🧡', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 16),
              const Text(
                '¿Estás bien?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu familia quiere saber cómo estás.\nResponde con un toque.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _respond(context, 'ok'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  minimumSize: const Size.fromHeight(74),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('✅  ESTOY BIEN',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _respond(context, 'help'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size.fromHeight(74),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('🆘  NECESITO AYUDA',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
