import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/providers/schedule_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/assigned_by_badge.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';
import 'package:edutrack_family/core/shared/widgets/no_student_gate.dart';

// ═══════════════════════════════════════════════════════════════
// HORARIO DE CLASES — EduTrack Family 2.0 (data-driven)
// Visor para el estudiante; los adultos además editan bloques.
// ═══════════════════════════════════════════════════════════════

class ClassScheduleScreen extends ConsumerStatefulWidget {
  const ClassScheduleScreen({super.key});

  @override
  ConsumerState<ClassScheduleScreen> createState() =>
      _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends ConsumerState<ClassScheduleScreen> {
  late int _selectedDay;

  static const _dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now().weekday;
    _selectedDay = today > 5 ? 1 : today; // fin de semana → lunes
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authProvider);
    final canEdit = user?.isAdult ?? false;
    final schedule = ref.watch(scheduleProvider);
    final notifier = ref.read(scheduleProvider.notifier);
    final student = ref.watch(activeStudentProvider);
    // Padre/profesor sin ningún estudiante vinculado: no hay a quién
    // agregarle clases — bloquear en vez de dejar que "Agregar clase"
    // no haga nada en silencio (createBlock ya lo rechaza internamente).
    final noStudents = canEdit && ref.watch(linkedStudentsProvider).isEmpty;

    final blocks = schedule.maybeWhen(
      data: (_) => notifier.forDay(_selectedDay),
      orElse: () => const <ScheduleBlock>[],
    );
    final current = notifier.currentClass;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Horario de clases'),
            if (student != null)
              Text(
                student.name,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (canEdit && !noStudents)
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Agregar clase',
              onPressed: () => _editBlock(context),
            ),
        ],
      ),
      body:
          noStudents
              ? const NoStudentGateBody()
              : CenteredConstrained(
                maxWidth: 720,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // ── Selector de día ─────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (var d = 1; d <= 7; d++)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_dayNames[d - 1]),
                                selected: _selectedDay == d,
                                onSelected:
                                    (_) => setState(() => _selectedDay = d),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child:
                          blocks.isEmpty
                              ? EmptyState(
                                emoji: '📚',
                                title: 'Sin clases este día',
                                subtitle:
                                    canEdit
                                        ? 'Toca el ➕ de arriba para armar el horario.'
                                        : 'Tu horario aparecerá aquí cuando lo configuren.',
                              )
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  4,
                                  16,
                                  96,
                                ),
                                itemCount: blocks.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final block = blocks[i];
                                  final isCurrent = current?.id == block.id;
                                  return _BlockCard(
                                    block: block,
                                    isCurrent: isCurrent,
                                    isDark: isDark,
                                    onTap:
                                        canEdit
                                            ? () => _editBlock(
                                              context,
                                              existing: block,
                                            )
                                            : null,
                                  );
                                },
                              ),
                    ),
                  ],
                ),
              ),
    );
  }

  Future<void> _editBlock(
    BuildContext context, {
    ScheduleBlock? existing,
  }) async {
    final result = await showModalBottomSheet<_BlockFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => _BlockFormSheet(
            weekday: existing?.weekday ?? _selectedDay,
            existing: existing,
          ),
    );
    if (result == null) return;
    if (!context.mounted) return;

    final notifier = ref.read(scheduleProvider.notifier);
    if (result.delete && existing != null) {
      final confirmed = await ConfirmationDialog.show(
        context,
        emoji: '🗑️',
        title: '¿Eliminar "${existing.subject}"?',
        message:
            'Se quita del horario semanal. Esta acción no se puede deshacer.',
        confirmLabel: 'Eliminar',
        isDangerous: true,
      );
      if (!confirmed) return;
      await notifier.deleteBlock(existing);
    } else if (existing != null) {
      await notifier.updateBlock(
        existing.copyWith(
          weekday: result.weekday,
          startMin: result.startMin,
          endMin: result.endMin,
          subject: result.subject,
          isBreak: result.isBreak,
        ),
      );
    } else {
      await notifier.createBlock(
        weekday: result.weekday,
        startMin: result.startMin,
        endMin: result.endMin,
        subject: result.subject,
        isBreak: result.isBreak,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Tarjeta de bloque
// ─────────────────────────────────────────────────────────────

class _BlockCard extends StatelessWidget {
  final ScheduleBlock block;
  final bool isCurrent;
  final bool isDark;
  final VoidCallback? onTap;

  const _BlockCard({
    required this.block,
    required this.isCurrent,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor =
        block.isBreak
            ? Colors.orange
            : (block.color != null
                ? Color(block.color!)
                : AppColors.accentBlue);

    return Material(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                isCurrent
                    ? Border.all(color: AppColors.statusGreen, width: 2)
                    : null,
          ),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 46,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.isBreak ? '🥪 ${block.subject}' : block.subject,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          block.timeRange,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                        if (block.assignedByRole != null) ...[
                          const SizedBox(width: 6),
                          AssignedByBadge(
                            assignedByRole: block.assignedByRole,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'AHORA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Formulario de bloque (crear/editar)
// ─────────────────────────────────────────────────────────────

class _BlockFormResult {
  final int weekday;
  final int startMin;
  final int endMin;
  final String subject;
  final bool isBreak;
  final bool delete;

  const _BlockFormResult({
    required this.weekday,
    required this.startMin,
    required this.endMin,
    required this.subject,
    required this.isBreak,
    this.delete = false,
  });
}

class _BlockFormSheet extends StatefulWidget {
  final int weekday;
  final ScheduleBlock? existing;
  const _BlockFormSheet({required this.weekday, this.existing});

  @override
  State<_BlockFormSheet> createState() => _BlockFormSheetState();
}

class _BlockFormSheetState extends State<_BlockFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _subjectCtrl = TextEditingController(
    text: widget.existing?.subject ?? '',
  );
  late int _weekday = widget.weekday;
  // Error de horario mostrado inline (no SnackBar): un SnackBar
  // disparado desde dentro de esta misma hoja modal queda oculto
  // detrás de ella (se ve "asomado" en Windows, invisible en
  // celular, porque el modal cubre toda la pantalla ahí).
  String? _timeError;
  late TimeOfDay _start =
      widget.existing != null
          ? TimeOfDay(
            hour: widget.existing!.startMin ~/ 60,
            minute: widget.existing!.startMin % 60,
          )
          : const TimeOfDay(hour: 7, minute: 0);
  late TimeOfDay _end =
      widget.existing != null
          ? TimeOfDay(
            hour: widget.existing!.endMin ~/ 60,
            minute: widget.existing!.endMin % 60,
          )
          : const TimeOfDay(hour: 7, minute: 45);
  late bool _isBreak = widget.existing?.isBreak ?? false;

  static const _dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    super.dispose();
  }

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (_toMin(_end) <= _toMin(_start)) {
      setState(() => _timeError = 'La hora de fin debe ser después del inicio');
      return;
    }
    if (_timeError != null) setState(() => _timeError = null);

    final subject = _subjectCtrl.text.trim();
    Navigator.pop(
      context,
      _BlockFormResult(
        weekday: _weekday,
        startMin: _toMin(_start),
        endMin: _toMin(_end),
        subject: subject,
        isBreak: _isBreak,
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
      builder: EduDateUtils.clampPickerTextScale,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
        _timeError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: CenteredConstrained(
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Text(
                isEdit ? 'Editar clase' : 'Nueva clase',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subjectCtrl,
                autofocus: !isEdit,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Materia',
                  prefixIcon: const Icon(Icons.menu_book_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Escribe la materia'
                            : null,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    ChoiceChip(
                      label: Text(_dayNames[d - 1]),
                      selected: _weekday == d,
                      onSelected: (_) => setState(() => _weekday = d),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(true),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Inicio: ${_start.format(context)}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickTime(false),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Fin: ${_end.format(context)}'),
                    ),
                  ),
                ],
              ),
              if (_timeError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _timeError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              SwitchListTile(
                value: _isBreak,
                onChanged: (v) => setState(() => _isBreak = v),
                title: const Text('Es recreo/descanso'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(isEdit ? 'Guardar cambios' : 'Agregar'),
              ),
              if (isEdit)
                TextButton.icon(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        _BlockFormResult(
                          weekday: _weekday,
                          startMin: _toMin(_start),
                          endMin: _toMin(_end),
                          subject: _subjectCtrl.text,
                          isBreak: _isBreak,
                          delete: true,
                        ),
                      ),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text(
                    'Eliminar clase',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
