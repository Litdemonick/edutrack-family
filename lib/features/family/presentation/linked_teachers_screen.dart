import 'package:flutter/material.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/features/family/data/family_repository.dart';

// ═══════════════════════════════════════════════════════════════
// LINKED TEACHERS SCREEN — EduTrack Family
// Lista (con scroll) de los profesores vinculados a un hijo/a ahora
// mismo, para que el padre/tutor sepa quién tiene acceso. Solo
// lectura: para quitar acceso hay que regenerar el código de
// profesor desde "Mi familia" (eso limpia la lista entera de una).
// ═══════════════════════════════════════════════════════════════

class LinkedTeachersScreen extends StatefulWidget {
  final StudentProfile student;

  const LinkedTeachersScreen({super.key, required this.student});

  @override
  State<LinkedTeachersScreen> createState() => _LinkedTeachersScreenState();
}

class _LinkedTeachersScreenState extends State<LinkedTeachersScreen> {
  late Future<LinkedTeachersResult> _future;

  @override
  void initState() {
    super.initState();
    _future = FamilyRepository.instance.getLinkedTeachers(widget.student.id);
  }

  Future<void> _refresh() async {
    final result = await FamilyRepository.instance
        .getLinkedTeachers(widget.student.id);
    if (mounted) setState(() => _future = Future.value(result));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF15151F) : AppColors.background,
      appBar: AppBar(
        title: Text('Profesores de ${widget.student.name}'),
      ),
      body: CenteredConstrained(
        maxWidth: 960,
        child: FutureBuilder<LinkedTeachersResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            final result = snapshot.data!;
            if (result.error != null) {
              return EmptyState(
                emoji: '⚠️',
                title: 'No se pudo cargar',
                subtitle: result.error!,
                actionLabel: 'Reintentar',
                onAction: _refresh,
              );
            }

            if (result.teachers.isEmpty) {
              return EmptyState(
                emoji: '🧑‍🏫',
                title: 'Sin profesores vinculados',
                subtitle:
                    'Cuando un profesor canjee el código de vinculación de '
                    '${widget.student.name}, aparecerá aquí.',
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: result.teachers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _TeacherTile(teacher: result.teachers[i], isDark: isDark),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TeacherTile extends StatelessWidget {
  final LinkedTeacher teacher;
  final bool isDark;

  const _TeacherTile({required this.teacher, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final name = (teacher.displayName?.trim().isNotEmpty ?? false)
        ? teacher.displayName!.trim()
        : 'Profesor/a';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Card(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white12 : AppColors.lightGrey,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.accentBlue,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (teacher.email != null && teacher.email!.isNotEmpty)
                    Text(
                      teacher.email!,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
