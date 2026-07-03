import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/features/family/data/family_repository.dart';
import 'widgets/child_form_sheet.dart';
import 'widgets/link_code_dialog.dart';
import 'widgets/student_avatar.dart';

// ═══════════════════════════════════════════════════════════════
// MI FAMILIA — EduTrack Family 2.0
// Padre: lista de hijos, crear/editar perfil, generar códigos de
// vinculación (dispositivo del hijo / profesor).
// Profesor: sus estudiantes vinculados + canjear código.
// ═══════════════════════════════════════════════════════════════

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final students = ref.watch(linkedStudentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isParent = user?.isParent ?? false;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        title: Text(isParent ? 'Mi familia' : 'Mis estudiantes'),
      ),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              onPressed: () => _addChild(context, ref),
              icon: const Icon(Icons.person_add),
              label: const Text('Agregar hijo/a'),
            )
          : FloatingActionButton.extended(
              onPressed: () => _redeemTeacherCode(context, ref),
              icon: const Icon(Icons.qr_code),
              label: const Text('Canjear código'),
            ),
      body: students.isEmpty
          ? EmptyState(
              emoji: isParent ? '👨‍👩‍👧' : '🏫',
              title: isParent ? 'Aún no tienes hijos registrados' : 'Sin estudiantes vinculados',
              subtitle: isParent
                  ? 'Agrega el perfil de tu hijo/a para empezar a asignarle tareas.'
                  : 'Pide al padre/tutor un código de vinculación de profesor.',
            )
          : CenteredConstrained(
              maxWidth: 720,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: students.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _StudentCard(
                  student: students[i],
                  isParent: isParent,
                ),
              ),
            ),
    );
  }

  Future<void> _addChild(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final data = await showChildFormSheet(context);
    if (data == null) return;

    try {
      final student = await FamilyRepository.instance.createChild(
        parentUid: user.uid,
        name: data.name,
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
    if (code == null || code.trim().isEmpty) return;

    final result = await FamilyRepository.instance.redeemTeacherCode(code);
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

class _StudentCard extends ConsumerWidget {
  final StudentProfile student;
  final bool isParent;

  const _StudentCard({required this.student, required this.isParent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    ],
                  ),
                ),
                if (isParent)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar perfil',
                    onPressed: () => _editChild(context, ref),
                  ),
              ],
            ),
            if (isParent) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _generateCode(context, 'child-device'),
                    icon: const Icon(Icons.phone_android, size: 18),
                    label: const Text('Vincular su celular'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _generateCode(context, 'teacher'),
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('Vincular profesor'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editChild(BuildContext context, WidgetRef ref) async {
    final data = await showChildFormSheet(context, existing: student);
    if (data == null) return;
    final updated = student.copyWith(
      name: data.name,
      grade: data.grade,
      avatarColor: data.avatarColor,
    );
    await FamilyRepository.instance.updateChild(updated);
    await ref.read(linkedStudentsProvider.notifier).upsertLocal(updated);
  }

  Future<void> _generateCode(BuildContext context, String kind) async {
    // Loading dialog mientras la Cloud Function responde
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    final result = await FamilyRepository.instance
        .generateLinkCode(studentId: student.id, kind: kind);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // cerrar loading

    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.error!),
        backgroundColor: Colors.red.shade700,
      ));
      return;
    }

    final shared = await showLinkCodeDialog(
      context,
      code: result.code!,
      studentName: student.name,
      isTeacherCode: kind == 'teacher',
    );
    if (shared == true) {
      final msg = kind == 'teacher'
          ? 'Código para vincularte como profesor/a de ${student.name} en '
              'EduTrack Family: ${result.code} (vence en 24 h)'
          : 'Código para entrar a EduTrack Family en el celular de '
              '${student.name}: ${result.code} (vence en 24 h)';
      await SharePlus.instance.share(ShareParams(text: msg));
    }
  }
}
