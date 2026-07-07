import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';

// ═══════════════════════════════════════════════════════════════
// REVOCATION GATE — EduTrack Family 2.0
// El código de vinculación del hijo ahora es permanente (sirve para
// volver a entrar tras cerrar sesión) hasta que el padre/tutor lo
// regenera a propósito. Firebase no ofrece un "desconectar ya mismo"
// instantáneo vía REST (eso es del SDK de administrador, que no corre
// en el Worker de Cloudflare) — en cambio, este widget invisible
// vigila en vivo (streaming real en Android/iOS, sondeo ~15-20s en
// Windows/Linux, ver watchRawDoc) si childLinkVersion cambió, y si es
// así cierra la sesión sola con un aviso. No es un corte instantáneo
// de milisegundo, pero para el caso real (nadie debería seguir usando
// el código viejo) el efecto práctico es el mismo.
// ═══════════════════════════════════════════════════════════════

String _versionKey(String studentId) => 'child_link_version_$studentId';

/// Llamar justo después de un signInAsChild exitoso (canje de código)
/// — guarda con qué versión de código quedó autorizado este
/// dispositivo, para poder detectar más adelante si se regeneró.
Future<void> saveAuthorizedLinkVersion(String studentId) async {
  try {
    final doc =
        await FirestoreService.instance.getRawDoc(FirestorePaths.student(studentId));
    final version = (doc?['childLinkVersion'] as num?)?.toInt() ?? 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_versionKey(studentId), version);
  } catch (_) {
    // Best-effort: si falla, la próxima verificación en vivo lo
    // tratará como versión 0 — peor caso, un false-positive de
    // "revocado" que se resuelve canjeando el código de nuevo.
  }
}

class RevocationGate extends ConsumerStatefulWidget {
  const RevocationGate({super.key});

  @override
  ConsumerState<RevocationGate> createState() => _RevocationGateState();
}

class _RevocationGateState extends ConsumerState<RevocationGate> {
  StreamSubscription<Map<String, dynamic>?>? _sub;
  bool _handled = false;
  // Evita un falso positivo de "perfil eliminado" si la primerísima
  // lectura (justo al abrir la app) llega vacía por una carrera de
  // red — solo se trata un doc null como "eliminado" DESPUÉS de haber
  // visto al menos una vez el doc real.
  bool _sawValidDoc = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    if (user == null || !user.isStudent) return;
    final studentId = user.uid;
    _sub = FirestoreService.instance
        .watchRawDoc(FirestorePaths.student(studentId))
        .listen((doc) => _check(studentId, doc));
  }

  Future<void> _check(String studentId, Map<String, dynamic>? doc) async {
    if (_handled) return;

    if (doc == null) {
      if (_sawValidDoc) {
        _handled = true;
        await _forceLogout(deleted: true);
      }
      return;
    }
    _sawValidDoc = true;

    final remoteVersion = (doc['childLinkVersion'] as num?)?.toInt() ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final authorizedVersion = prefs.getInt(_versionKey(studentId)) ?? 0;
    if (remoteVersion > authorizedVersion) {
      _handled = true;
      await _forceLogout(deleted: false);
    }
  }

  Future<void> _forceLogout({required bool deleted}) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesión finalizada'),
        content: Text(
          deleted
              ? 'Tu padre/tutor eliminó tu perfil de EduTrack Family.'
              : 'Tu padre/tutor regeneró tu código de acceso. Pídele el '
                  'nuevo código para volver a entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
