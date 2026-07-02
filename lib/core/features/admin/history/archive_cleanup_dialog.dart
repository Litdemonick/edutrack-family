import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';

// ═══════════════════════════════════════════════════════════════
// ARCHIVE CLEANUP DIALOG — EduTrack Family
// Diálogo para limpiar el historial de tareas archivadas.
// ═══════════════════════════════════════════════════════════════

class ArchiveCleanupDialog extends ConsumerStatefulWidget {
  const ArchiveCleanupDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const ArchiveCleanupDialog(),
    );
  }

  @override
  ConsumerState<ArchiveCleanupDialog> createState() =>
      _ArchiveCleanupDialogState();
}

class _ArchiveCleanupDialogState extends ConsumerState<ArchiveCleanupDialog> {
  int _keepDays = 30;
  bool _isDeleting = false;

  Future<void> _confirm() async {
    setState(() => _isDeleting = true);
    // Archive old completed tasks via provider
    final tasks = ref.read(taskProvider).maybeWhen(
          data: (t) => t,
          orElse: () => [],
        );
    final cutoff = DateTime.now().subtract(Duration(days: _keepDays));
    for (final t in tasks) {
      if (t.isCompleted &&
          t.completedAt != null &&
          t.completedAt!.isBefore(cutoff)) {
        await ref.read(taskProvider.notifier).archiveTask(t.id);
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      title: Column(
        children: [
          const Text('🧹', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            'Limpiar historial',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Archiva las tareas completadas con más de:',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.darkGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [15, 30, 60, 90].map((d) {
              final isSelected = _keepDays == d;
              return GestureDetector(
                onTap: () => setState(() => _keepDays = d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.accentBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.accentBlue : AppColors.lightGrey,
                    ),
                  ),
                  child: Text(
                    '$d d',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Las tareas archivadas no aparecerán en el historial.',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isDeleting ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusAmber,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Limpiar',
                        style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
