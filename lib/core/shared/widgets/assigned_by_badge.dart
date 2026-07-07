import 'package:flutter/material.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/app_user_model.dart';

// ═══════════════════════════════════════════════════════════════
// ASSIGNED BY BADGE — EduTrack Family
// Pastilla "Asignada por: [rol]" para listas/tarjetas — antes este
// dato (assignedByRole/assignedByName) solo se veía al abrir el
// detalle de la tarea/evento, así que en la lista y en la cola de
// revisión no había forma de saber a simple vista si algo lo puso
// el padre/tutor o el profesor.
// ═══════════════════════════════════════════════════════════════

class AssignedByBadge extends StatelessWidget {
  final String? assignedByRole;
  final bool compact;

  const AssignedByBadge({
    super.key,
    required this.assignedByRole,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final roleStr = assignedByRole;
    if (roleStr == null || roleStr.isEmpty) return const SizedBox.shrink();

    // fromName cae a UserRole.student si el valor no se reconoce —
    // una tarea/evento nunca lo asigna un estudiante, así que ese
    // caso es dato corrupto/desconocido y mejor no mostrar nada.
    final role = UserRoleExt.fromName(roleStr);
    if (role == UserRole.student) return const SizedBox.shrink();

    final color =
        role == UserRole.teacher ? AppColors.accentBlue : const Color(0xFFE91E63);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${role.emoji} ${role.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Nunito',
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
