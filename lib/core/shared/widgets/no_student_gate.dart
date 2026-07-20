import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/utils/role_copy.dart';
import 'empty_state.dart';

// ═══════════════════════════════════════════════════════════════
// NO STUDENT GATE — EduTrack Family
// El padre/tutor es el centro del flujo: crea y vincula a su hijo/a
// primero; un profesor recién puede crear/editar algo una vez que un
// padre lo vinculó a un estudiante. Sin ningún estudiante vinculado,
// no hay a quién asignarle una tarea/evento — bloquear la pantalla de
// creación con un mensaje claro en vez de dejar que el botón
// "Guardar" no haga nada en silencio.
// ═══════════════════════════════════════════════════════════════

/// Pantallas de creación: `if (ref.watch(linkedStudentsProvider).isEmpty)`
/// para decidir si mostrar esto en vez del formulario real.
class NoStudentGateBody extends ConsumerWidget {
  const NoStudentGateBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider)?.role ?? UserRole.parent;
    return EmptyState(
      emoji: '🔒',
      title: RoleCopy.noStudentsTitle(role),
      subtitle: RoleCopy.noStudentsSubtitle(role),
      actionLabel: RoleCopy.noStudentsActionLabel(role),
      onAction: () => context.push(AppRoutes.family),
    );
  }
}
