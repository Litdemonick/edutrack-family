import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/firebase/platform/firebase_backend.dart';
import 'package:edutrack_family/core/firebase/rest/polling_stream.dart';
import 'package:edutrack_family/core/constants/utils/notification_utils.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/notification_provider.dart';
import 'package:edutrack_family/core/services/push_queue_service.dart';
import 'package:edutrack_family/core/services/ringtone_service.dart';
import 'safety_alert_coordinator.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

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

  final checkId = const Uuid().v4();
  await FirestoreService.instance.setRawDoc(
    FirestorePaths.wellnessCheck(studentId, checkId),
    {
      'status': 'pending',
      'requestedBy': user.uid,
      // Timestamp.now() en vez de FieldValue.serverTimestamp(): el
      // gateway REST no soporta sentinels de transform, y este campo
      // no participa en la lógica de timeout (esa usa expiresAt,
      // calculado en el cliente de todas formas).
      'requestedAt': Timestamp.now(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(wellnessTimeout)),
    },
  );

  // Push urgente al dispositivo del hijo — channelId explícito para
  // que, con la app en background/cerrada, Android la muestre por el
  // canal de seguridad (sonido fuerte fijo) en vez de caer al canal
  // por defecto ('edutrack_system', sin vibración y con el sonido
  // general del usuario, que puede estar apagado).
  await PushQueueService.instance.sendToUids(
    [studentId],
    title: '🧡 ¿Estás bien?',
    body: 'Tu familia quiere saber cómo estás. Responde con un toque.',
    data: {'type': 'wellness_check', 'checkId': checkId},
    channelId: 'edutrack_safety',
  );

  if (!context.mounted) return;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ParentWaitingDialog(
      studentId: studentId,
      studentName: studentName,
      checkId: checkId,
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
  StreamSubscription? _sub;
  String _status = 'pending';

  @override
  void initState() {
    super.initState();
    final relPath = FirestorePaths.wellnessCheck(widget.studentId, widget.checkId);
    // Ventana acotada de 3 min y el padre está mirando la cuenta
    // regresiva — vale la pena un polling corto en escritorio para
    // que se sienta responsivo (ver plan de paridad de escritorio).
    final stream = useDesktopRestBackend
        ? PollingDocStream<Map<String, dynamic>?>(
            fetch: () => FirestoreService.instance.getRawDoc(relPath),
            interval: const Duration(seconds: 4),
          ).watch()
        : FirebaseFirestore.instance.doc(relPath).snapshots().map((s) => s.data());
    _sub = stream.listen((data) {
      final status = (data?['status'] ?? 'pending') as String;
      if (mounted && status != _status) setState(() => _status = status);
    });
  }

  @override
  void dispose() {
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
          '${widget.studentName} recibió el aviso y no ha respondido '
              'todavía. Esta ventana espera sin límite de tiempo — si la '
              'cierras, te avisaremos igual apenas responda.',
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
            SizedBox(
              height: 3,
              child: LinearProgressIndicator(color: color),
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
    // La alerta sísmica tiene prioridad: si está en pantalla ahora
    // mismo, este check-in espera a que el usuario la acepte primero
    // — dos alertas de seguridad a pantalla completa a la vez serían
    // confusas para un niño.
    await SafetyAlertCoordinator.instance.waitUntilSeismicClear();
    if (!mounted) {
      _showing = false;
      return;
    }
    // Antes solo vibraba (RingtoneService.vibrate) — nunca pasaba por
    // el sistema de notificaciones, así que jamás sonaba nada con la
    // app abierta, sin importar ninguna configuración de sonido.
    await NotificationUtils.showSafetyAlert(
      title: '🧡 ¿Estás bien?',
      body: 'Tu familia quiere saber cómo estás. Responde con un toque.',
      requireConfirm: true,
    );
    if (!mounted) return;
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
/// Suena en bucle (alarma, ignora el silencio) hasta que el
/// estudiante responde o cierra esta pantalla — antes solo vibraba
/// una vez al aparecer y quedaba en silencio total el resto del
/// tiempo, aunque el niño no hubiera respondido.
class WellnessResponseScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String checkId;

  const WellnessResponseScreen({
    super.key,
    required this.studentId,
    required this.checkId,
  });

  @override
  ConsumerState<WellnessResponseScreen> createState() =>
      _WellnessResponseScreenState();
}

class _WellnessResponseScreenState
    extends ConsumerState<WellnessResponseScreen> {
  @override
  void initState() {
    super.initState();
    RingtoneService.instance.startAlarmLoop();
  }

  @override
  void dispose() {
    RingtoneService.instance.stopAlarmLoop();
    super.dispose();
  }

  Future<void> _respond(BuildContext context, String status) async {
    await RingtoneService.instance.stopAlarmLoop();
    await FirebaseFirestore.instance
        .doc(FirestorePaths.wellnessCheck(widget.studentId, widget.checkId))
        .update({
      'status': status,
      'respondedAt': DateTime.now().toIso8601String(),
    });
    ref.read(notificationProvider.notifier).dispatchFull(
          title: status == 'help' ? '🆘 Pediste ayuda' : '✅ Respondiste que estás bien',
          body: 'Se avisó a tu padre/tutor.',
          type: NotificationType.wellnessCheck,
        );
    unawaited(_notifyGuardians(status));
    if (context.mounted) Navigator.of(context).pop();
  }

  // Push directo a los padres/tutores — antes solo se enteraban si
  // tenían el diálogo de espera abierto en primer plano (el listener
  // de Firestore se cancelaba al cerrar el diálogo o poner la app en
  // segundo plano). Con esto llega igual aunque hayan cerrado el
  // diálogo o la app: "Cloudflare Workers no tiene triggers de
  // Firestore" (no hay Cloud Functions), así que el propio cliente
  // dispara el push al responder, mismo patrón que el resto de
  // notificaciones cliente→Worker en la app.
  Future<void> _notifyGuardians(String status) async {
    try {
      final studentDoc = await FirestoreService.instance
          .getRawDoc(FirestorePaths.student(widget.studentId));
      final parentIds =
          (studentDoc?['parentIds'] as List?)?.cast<String>() ?? const [];
      if (parentIds.isEmpty) return;
      final name = (studentDoc?['name'] as String?) ?? 'Tu hijo/a';
      final help = status == 'help';
      await PushQueueService.instance.sendToUids(
        parentIds,
        title: help ? '🆘 $name pide ayuda' : '✅ $name está bien',
        body: help
            ? '$name respondió que NECESITA AYUDA al check-in "¿Estás bien?". Llámale y revisa su ubicación.'
            : '$name respondió que está bien al check-in "¿Estás bien?".',
        data: {
          'type': 'wellness_response',
          'studentId': widget.studentId,
          'status': status,
        },
        channelId: help ? 'edutrack_safety' : null,
      );
    } catch (e) {
      AppLog.d('[WellnessResponse] notify guardians error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navyBlue,
      // SingleChildScrollView + ConstrainedBox(minHeight) en vez de
      // Column con Spacer(): en horizontal (poca altura) el emoji +
      // título + los 2 botones grandes no entraban y desbordaba.
      // Spacer() tampoco funciona dentro de un scroll (necesita alto
      // acotado), así que se reemplazó por gaps fijos — en pantallas
      // altas igual se ve centrado gracias al minHeight; en
      // horizontal simplemente se puede deslizar en vez de romperse.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
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
                  const SizedBox(height: 32),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
