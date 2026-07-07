import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/providers/event_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/responsive/breakpoints.dart';
import 'package:edutrack_family/core/shared/widgets/no_student_gate.dart';

// ═══════════════════════════════════════════════════════════════
// CREATE EVENT SCREEN — EduTrack Family
// Formulario para que el admin cree un evento del calendario.
// ═══════════════════════════════════════════════════════════════

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  EventType _type = EventType.other;
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  DateTime? _endDate;
  bool _isAllDay = true;
  bool _isSaving = false;
  int _reminderMinutesBefore = 60; // default: 1 hora antes

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({bool isEnd = false}) async {
    final initial = isEnd ? (_endDate ?? _date) : _date;
    final first = isEnd ? _date : DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: EduDateUtils.clampPickerTextScale,
    );
    if (picked == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: isEnd
          ? TimeOfDay.fromDateTime(_endDate ?? _date)
          : TimeOfDay.fromDateTime(_date),
      helpText: 'Hora del evento (opcional)',
      cancelText: 'Todo el día',
      confirmText: 'Aceptar',
      builder: EduDateUtils.clampPickerTextScale,
    );

    setState(() {
      final useTime = pickedTime != null;
      final hour = pickedTime?.hour ?? 0;
      final minute = pickedTime?.minute ?? 0;
      final dt = DateTime(picked.year, picked.month, picked.day, hour, minute);

      if (isEnd) {
        _endDate = dt;
      } else {
        _date = dt;
        _isAllDay = !useTime;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = dt;
        }
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    await ref.read(eventProvider.notifier).createEvent(
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          type: _type,
          date: _date,
          endDate: _endDate,
          isAllDay: _isAllDay,
          reminderMinutesBefore: _isAllDay ? 0 : _reminderMinutesBefore,
        );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Sin ningún estudiante vinculado no hay a quién asignarle el
    // evento — bloquear con un mensaje claro en vez de dejar que
    // "Guardar" no haga nada en silencio.
    final noStudents = ref.watch(linkedStudentsProvider).isEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nuevo evento',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!noStudents)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: const Text('Guardar',
                  style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: noStudents
          ? const NoStudentGateBody()
          : CenteredConstrained(
        maxWidth: 640,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _card(
              isDark: isDark,
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Título del evento',
                      hintText: 'Ej. Reunión de padres',
                      prefixIcon: Icon(Icons.event_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? AppStrings.errorRequired : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      prefixIcon: Icon(Icons.notes_rounded),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _card(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Tipo de evento', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: EventType.values.map((type) {
                      final isSelected = _type == type;
                      return GestureDetector(
                        onTap: () => setState(() => _type = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accentBlue
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accentBlue
                                  : AppColors.lightGrey,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(type.emoji,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                type.label,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            _card(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Fecha', isDark),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.accentBlue),
                    title: Text(
                      EduDateUtils.fullDateLabel(_date),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    subtitle: _isAllDay
                        ? const Text('Todo el día',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 12))
                        : Text(EduDateUtils.timeLabel(_date),
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              color: AppColors.accentBlue,
                            )),
                    trailing: TextButton(
                        onPressed: () => _pickDate(),
                        child: const Text('Cambiar')),
                  ),
                  if (_endDate != null) ...[
                    const Divider(height: 8),
                    _label('Fecha fin', isDark),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_available_outlined,
                          color: AppColors.statusGreen),
                      title: Text(
                        EduDateUtils.fullDateLabel(_endDate!),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppColors.navyBlue,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                              onPressed: () => _pickDate(isEnd: true),
                              child: const Text('Cambiar')),
                          IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppColors.statusRed),
                            onPressed: () => setState(() => _endDate = null),
                          ),
                        ],
                      ),
                    ),
                  ] else
                    TextButton.icon(
                      onPressed: () => _pickDate(isEnd: true),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Agregar fecha fin'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Selector de recordatorio (solo si tiene hora) ──────
            if (!_isAllDay)
              _card(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Recordatorio', isDark),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _reminderChip(0, 'Sin recordatorio', isDark),
                        _reminderChip(30, '30 min antes', isDark),
                        _reminderChip(60, '1 hora antes', isDark),
                        _reminderChip(1440, '1 día antes', isDark),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Crear evento'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 8,
            ),
          ],
        ),
        child: child,
      );

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      );

  Widget _reminderChip(int minutes, String label, bool isDark) {
    final selected = _reminderMinutesBefore == minutes;
    return GestureDetector(
      onTap: () => setState(() => _reminderMinutesBefore = minutes),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accentBlue
              : (isDark ? Colors.white10 : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.accentBlue
                : (isDark ? Colors.white24 : AppColors.lightGrey),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              minutes == 0
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
              size: 14,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white54 : AppColors.grey),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white54 : AppColors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
