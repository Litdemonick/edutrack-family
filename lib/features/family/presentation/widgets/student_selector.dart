import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'student_avatar.dart';

// ═══════════════════════════════════════════════════════════════
// SELECTOR DE ESTUDIANTE — chip del AppBar de las shells de
// padre/profesor: muestra el hijo activo y despliega la lista
// para cambiar de estudiante o ir a "Mi familia".
// ═══════════════════════════════════════════════════════════════

class StudentSelector extends ConsumerWidget {
  /// true → estilo compacto para AppBar oscuro
  final bool onDarkBackground;

  const StudentSelector({super.key, this.onDarkBackground = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(linkedStudentsProvider);
    final active = ref.watch(activeStudentProvider);

    if (students.isEmpty) {
      return TextButton.icon(
        onPressed: () => context.push(AppRoutes.family),
        icon: Icon(Icons.person_add,
            size: 18, color: onDarkBackground ? Colors.white : null),
        label: Text(
          'Agregar hijo/a',
          style: TextStyle(color: onDarkBackground ? Colors.white : null),
        ),
      );
    }

    if (active == null) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      tooltip: 'Cambiar de estudiante',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        if (value == '_family') {
          context.push(AppRoutes.family);
        } else {
          ref.read(activeStudentIdProvider.notifier).select(value);
        }
      },
      itemBuilder: (context) => [
        for (final s in students)
          PopupMenuItem(
            value: s.id,
            child: Row(
              children: [
                StudentAvatar(student: s, radius: 14),
                const SizedBox(width: 10),
                Expanded(child: Text(s.name, overflow: TextOverflow.ellipsis)),
                if (s.id == active.id)
                  const Icon(Icons.check, size: 18, color: Colors.green),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '_family',
          child: Row(
            children: [
              Icon(Icons.family_restroom, size: 20),
              SizedBox(width: 10),
              Text('Gestionar familia'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onDarkBackground
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StudentAvatar(student: active, radius: 13),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                active.name.split(' ').first,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onDarkBackground ? Colors.white : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: onDarkBackground ? Colors.white : null),
          ],
        ),
      ),
    );
  }
}
