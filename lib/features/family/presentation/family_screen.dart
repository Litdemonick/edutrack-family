import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/utils/input_sanitizer.dart';
import 'package:edutrack_family/features/family/data/family_repository.dart';
import 'linked_teachers_screen.dart';
import 'widgets/child_form_sheet.dart';
import 'widgets/link_code_dialog.dart';
import 'widgets/student_avatar.dart';

// ═══════════════════════════════════════════════════════════════
// MI FAMILIA — EduTrack Family 2.0
// Padre: lista de hijos, crear/editar perfil, generar códigos de
// vinculación (dispositivo del hijo / profesor).
// Profesor: sus estudiantes vinculados + canjear código.
// ═══════════════════════════════════════════════════════════════

class FamilyScreen extends ConsumerStatefulWidget {
  const FamilyScreen({super.key});

  @override
  ConsumerState<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends ConsumerState<FamilyScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Compara sin distinguir mayúsculas ni guiones — así buscar
  /// "88888888" encuentra a alguien con cédula "8-888-8888" y
  /// viceversa, sin obligar a escribirla con el formato exacto.
  bool _matches(StudentProfile student, String query) {
    final q = query.toLowerCase().replaceAll('-', '');
    if (q.isEmpty) return true;
    final name = student.name.toLowerCase();
    final cedula = student.cedula.toLowerCase().replaceAll('-', '');
    return name.contains(query.toLowerCase()) || cedula.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final allStudents = ref.watch(linkedStudentsProvider);
    final students = allStudents.where((s) => _matches(s, _query)).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isParent = user?.isParent ?? false;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        title: Text(isParent ? 'Mi familia' : 'Mis estudiantes'),
        actions: [
          IconButton(
            icon: Icon(isParent ? Icons.person_add : Icons.pin_rounded),
            tooltip: isParent ? 'Agregar hijo/a' : 'Canjear código',
            onPressed: () => isParent
                ? _addChild(context, ref)
                : _redeemTeacherCode(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
            onPressed: () => _refresh(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(context, ref, showSnackBar: false),
        child: allStudents.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: EmptyState(
                      emoji: isParent ? '👨‍👩‍👧' : '🏫',
                      title: isParent
                          ? 'Aún no tienes hijos registrados'
                          : 'Sin estudiantes vinculados',
                      subtitle: isParent
                          ? 'Agrega el perfil de tu hijo/a para empezar a asignarle tareas.'
                          : 'Pide al padre/tutor un código de vinculación de profesor.',
                    ),
                  ),
                ],
              )
            : CenteredConstrained(
                maxWidth: 720,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: TextField(
                        controller: _searchCtrl,
                        maxLength: 80,
                        decoration: InputDecoration(
                          isDense: true,
                          counterText: '',
                          hintText: 'Buscar por nombre o cédula…',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onChanged: (v) =>
                            setState(() => _query = InputSanitizer.clean(v)),
                      ),
                    ),
                    Expanded(
                      child: students.isEmpty
                          ? EmptyState(
                              emoji: '🔍',
                              title: 'Sin resultados',
                              subtitle:
                                  'Ningún estudiante coincide con "$_query".',
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(16),
                              itemCount: students.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) => _StudentCard(
                                student: students[i],
                                isParent: isParent,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _refresh(BuildContext context, WidgetRef ref,
      {bool showSnackBar = true}) async {
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(linkedStudentsProvider.notifier).refreshForAdult(user.uid);
    if (showSnackBar && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Actualizado ✓'),
        duration: Duration(seconds: 2),
      ));
    }
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final data = await showChildFormSheet(context);
    if (data == null) return;

    // Solo advertencia, no bloquea — un padre puede tener de verdad
    // dos hijos con el mismo nombre (mellizos, etc.). Cada uno queda
    // con su propio ID interno igual, nunca se cruzan datos.
    final students = ref.read(linkedStudentsProvider);
    final nameExists = students.any(
      (s) => s.name.trim().toLowerCase() == data.name.trim().toLowerCase(),
    );
    if (nameExists) {
      if (!context.mounted) return;
      final confirmed = await ConfirmationDialog.show(
        context,
        emoji: '⚠️',
        title: 'Ya tienes un hijo/a llamado ${data.name}',
        message: '¿Seguro que quieres crear otro perfil con el mismo nombre? '
            'Podrás distinguirlos por el grado o el color del avatar.',
        confirmLabel: 'Crear igual',
        cancelLabel: 'Cancelar',
      );
      if (!confirmed) return;
    }

    if (!context.mounted) return;
    try {
      final student = await FamilyRepository.instance.createChild(
        parentUid: user.uid,
        name: data.name,
        cedula: data.cedula,
        grade: data.grade,
        avatarColor: data.avatarColor,
      );
      await ref.read(linkedStudentsProvider.notifier).upsertLocal(student);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${student.name} agregado/a ✓'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'No se pudo crear el perfil. Revisa tu conexión.'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  Future<void> _redeemTeacherCode(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Canjear código'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código del padre/tutor',
              hintText: 'ABC123',
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Canjear')),
          ],
        );
      },
    );
    final cleanCode = InputSanitizer.clean(code ?? '').toUpperCase();
    if (cleanCode.isEmpty) return;

    final result = await FamilyRepository.instance.redeemTeacherCode(cleanCode);
    if (!context.mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: Colors.red.shade700,
      ));
    } else {
      await ref.read(linkedStudentsProvider.notifier).refreshForAdult(user.uid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Estudiante vinculado ✓'),
          backgroundColor: Colors.green.shade700,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de estudiante con acciones
// ─────────────────────────────────────────────────────────────

class _StudentCard extends ConsumerStatefulWidget {
  final StudentProfile student;
  final bool isParent;

  const _StudentCard({required this.student, required this.isParent});

  @override
  ConsumerState<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends ConsumerState<_StudentCard> {
  StudentProfile get student => widget.student;
  bool get isParent => widget.isParent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Cacheado en el provider (sin autoDispose): no se vuelve a
    // consultar cada vez que se entra a esta pantalla, así que el
    // botón no "salta" de "Vincular..." a "Ver código" cada vez.
    final status = isParent
        ? ref.watch(linkCodeStatusProvider(student.id)).valueOrNull
        : null;

    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StudentAvatar(student: student, radius: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(student.name,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      if (student.grade != null &&
                          student.grade!.isNotEmpty)
                        Text(student.grade!,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                      if (student.cedula.isNotEmpty)
                        Text('Cédula: ${student.cedula}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (isParent) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar perfil',
                    onPressed: () => _editChild(context),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade400),
                    tooltip: 'Eliminar hijo/a',
                    onPressed: () => _deleteChild(context),
                  ),
                ] else
                  IconButton(
                    icon: Icon(Icons.link_off_rounded,
                        color: Colors.red.shade400),
                    tooltip: 'Dejar de ver este estudiante',
                    onPressed: () => _leaveStudent(context),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _viewAchievements(context),
                icon: const Icon(Icons.emoji_events_outlined, size: 18),
                label: const Text('Ver logros'),
              ),
            ),
            if (isParent) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Códigos de vinculación',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    tooltip: 'Cómo funcionan los códigos',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _showLinkCodeInfo(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LinkCodeButtons(
                    icon: Icons.phone_android,
                    label: (status?.childActive ?? false)
                        ? 'Ver código'
                        : 'Vincular su celular',
                    onTap: () => _generateCode(context, 'child-device'),
                    onRegenerate: () =>
                        _generateCode(context, 'child-device', forceNew: true),
                  ),
                  _LinkCodeButtons(
                    icon: Icons.school_outlined,
                    label: (status?.teacherActive ?? false)
                        ? 'Ver código'
                        : 'Vincular profesor',
                    onTap: () => _generateCode(context, 'teacher'),
                    onRegenerate: () =>
                        _generateCode(context, 'teacher', forceNew: true),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LinkedTeachersScreen(student: student),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined, size: 18),
                  label: const Text('Ver profesores vinculados'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showLinkCodeInfo(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: const Text(
          '¿Cómo funcionan los códigos?',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Una vez que se canjea, el código sigue sirviendo para volver '
          'a entrar tras cerrar sesión — queda oculto hasta que lo '
          'muestres. Si crees que alguien más lo vio, regeneralo: el '
          'anterior deja de servir al instante. Si era el del hijo/a, se '
          'le cierra la sesión sola; si era el del profesor, pierde el '
          'acceso a este hijo/a de inmediato.',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  /// Cambia el estudiante activo a este y deja pendiente en AdminHome
  /// que salte a la pestaña de Estadísticas (que ya muestra Logros +
  /// progreso scoped al estudiante activo) — mismo mecanismo que usa
  /// el selector de "Mi familia"/dashboard en cualquier otra pantalla,
  /// solo que iniciado desde esta tarjeta.
  ///
  /// context.go() (no context.pop()) a propósito: "Mi familia" se
  /// puede abrir desde el speed-dial de AdminHome (1 nivel) O desde
  /// Ajustes → Mi familia (2 niveles: Family → Ajustes → AdminHome).
  /// Con pop() solo se deshacía UN nivel — entrando desde Ajustes, el
  /// usuario quedaba de vuelta en Ajustes (no en Estadísticas) y
  /// parecía que "no pasó nada". go() lleva directo a AdminHome sin
  /// importar cuántos niveles de por medio hubiera.
  void _viewAchievements(BuildContext context) {
    ref.read(activeStudentIdProvider.notifier).select(student.id);
    ref.read(pendingAdminTabProvider.notifier).state = 6;
    context.go(AppRoutes.admin);
  }

  Future<void> _editChild(BuildContext context) async {
    final data = await showChildFormSheet(context, existing: student);
    if (data == null) return;
    final updated = student.copyWith(
      name: data.name,
      cedula: data.cedula,
      grade: data.grade,
      avatarColor: data.avatarColor,
    );
    await FamilyRepository.instance.updateChild(updated);
    await ref.read(linkedStudentsProvider.notifier).upsertLocal(updated);
  }

  Future<void> _deleteChild(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      emoji: '⚠️',
      title: '¿Eliminar a ${student.name}?',
      message:
          'Se borrarán para siempre su perfil, tareas, eventos, horario, '
          'evidencias, ubicación y códigos de vinculación pendientes. '
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (!confirmed || !context.mounted) return;

    // Paso 2: correo de confirmación — un borrado es irreversible, así
    // que además del diálogo de arriba, se exige probar acceso a la
    // bandeja de entrada de la cuenta antes de dejar continuar.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final req = await FamilyRepository.instance.requestDeleteConfirmation(student.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar loading

    if (req.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(req.error!),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final emailConfirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _WaitForEmailConfirmDialog(
        requestId: req.requestId!,
        email: req.email,
      ),
    );
    if (emailConfirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await FamilyRepository.instance
        .deleteChild(student.id, requestId: req.requestId!);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar loading

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    await ref.read(linkedStudentsProvider.notifier).removeLocal(student.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${student.name} fue eliminado/a'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  Future<void> _leaveStudent(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
      context,
      emoji: '🔗',
      title: '¿Dejar de ver a ${student.name}?',
      message:
          'Perderás acceso a sus tareas, eventos y evidencias. El padre/'
          'tutor recibirá un aviso. Si necesitas volver a entrar, te van '
          'a tener que compartir el código de vinculación de nuevo.',
      confirmLabel: 'Dejar de ver',
      isDangerous: true,
    );
    if (!confirmed || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final error = await FamilyRepository.instance.leaveStudent(student.id);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar loading

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }
    await ref.read(linkedStudentsProvider.notifier).removeLocal(student.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Ya no ves a ${student.name}'),
        backgroundColor: Colors.green.shade700,
      ));
    }
  }

  Future<void> _generateCode(
    BuildContext context,
    String kind, {
    bool forceNew = false,
  }) async {
    if (forceNew) {
      final confirmed = await ConfirmationDialog.show(
        context,
        emoji: '🔄',
        title: '¿Regenerar código?',
        message: 'El código anterior (si alguien todavía lo tiene) dejará '
            'de funcionar de inmediato. Vas a necesitar compartir el nuevo.',
        confirmLabel: 'Regenerar',
        isDangerous: true,
      );
      if (!confirmed || !context.mounted) return;
    }

    // Si ya había un código activo de este tipo, "Ver código" solo
    // está MOSTRANDO el mismo de siempre — no hace falta invalidar el
    // estado cacheado después. Sin este chequeo, cada vez que el
    // padre solo quería mirar/compartir de nuevo el código ya
    // existente, se invalidaba igual y el botón parpadeaba a
    // "Vincular" mientras la consulta se repetía (o si esa consulta
    // fallaba, se quedaba mostrando "Vincular" por error).
    final wasActive = kind == 'teacher'
        ? (ref.read(linkCodeStatusProvider(student.id)).valueOrNull?.teacherActive ?? false)
        : (ref.read(linkCodeStatusProvider(student.id)).valueOrNull?.childActive ?? false);

    // Loading dialog mientras la Cloud Function responde
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final result = await FamilyRepository.instance.generateLinkCode(
      studentId: student.id,
      kind: kind,
      forceNew: forceNew,
    );
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar loading

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    if (forceNew || !wasActive) {
      ref.invalidate(linkCodeStatusProvider(student.id));
    }
    if (!context.mounted) return;

    final shared = await showLinkCodeDialog(
      context,
      code: result.code!,
      studentName: student.name,
      isTeacherCode: kind == 'teacher',
      permanent: result.permanent,
    );
    if (shared == true) {
      final validity = result.permanent
          ? '(sigue sirviendo hasta que se regenere)'
          : '(vence en 24 h si no se usa)';
      final msg = kind == 'teacher'
          ? 'Código para vincularte como profesor/a de ${student.name} en '
              'EduTrack Family: ${result.code} $validity'
          : 'Código para entrar a EduTrack Family en el celular de '
              '${student.name}: ${result.code} $validity';
      await SharePlus.instance.share(ShareParams(text: msg));
    } else if (shared == false && context.mounted) {
      // "Copiar" — el diálogo ya se cerró acá, así que el SnackBar
      // usa el Scaffold real de esta pantalla (mostrarlo desde
      // dentro del diálogo quedaba oculto detrás de él).
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Código copiado ✓'),
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────
// BOTÓN DE VINCULACIÓN + REGENERAR — el botón principal reutiliza el
// código vigente (o pide uno si no hay); el ícono de al lado invalida
// el actual y crea uno nuevo (para cuando se sospecha una filtración).
// ─────────────────────────────────────────────────────────────

class _LinkCodeButtons extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onRegenerate;

  const _LinkCodeButtons({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
        IconButton(
          onPressed: onRegenerate,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          tooltip: 'Regenerar código (invalida el anterior)',
        ),
      ],
    );
  }
}

/// Espera (con polling) a que se confirme el correo de borrado — se
/// cierra sola al detectar la confirmación. No se puede cerrar con el
/// botón atrás/gesto para no perder de vista que hay un borrado
/// pendiente; solo "Cancelar" o la confirmación real la cierran.
class _WaitForEmailConfirmDialog extends StatefulWidget {
  final String requestId;
  final String? email;
  const _WaitForEmailConfirmDialog({required this.requestId, this.email});

  @override
  State<_WaitForEmailConfirmDialog> createState() =>
      _WaitForEmailConfirmDialogState();
}

class _WaitForEmailConfirmDialogState
    extends State<_WaitForEmailConfirmDialog> {
  Timer? _timer;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    final ok = await FamilyRepository.instance
        .checkDeleteConfirmed(widget.requestId);
    if (!mounted || _confirmed) return;
    if (ok) {
      _timer?.cancel();
      setState(() => _confirmed = true);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: Text(
          _confirmed ? '¡Confirmado!' : 'Revisa tu correo',
          style: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_confirmed)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.green, size: 48)
            else
              const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _confirmed
                  ? 'Continuando con el borrado…'
                  : 'Te mandamos un enlace de confirmación a '
                      '${widget.email ?? 'tu correo'}. Ábrelo desde '
                      'cualquier dispositivo para confirmar que de verdad '
                      'quieres eliminar a este hijo/a — esta ventana se '
                      'cierra sola apenas lo confirmes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        actions: _confirmed
            ? null
            : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ],
      ),
    );
  }
}
