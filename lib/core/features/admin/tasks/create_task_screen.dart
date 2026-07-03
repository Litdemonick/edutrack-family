
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/providers/schedule_provider.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/services/camera_service.dart';
import 'package:edutrack_family/core/shared/widgets/cached_local_image.dart';

// ═══════════════════════════════════════════════════════════════
// CREATE TASK SCREEN — EduTrack Family
// Formulario para que el admin cree una nueva tarea de Yordan.
// ═══════════════════════════════════════════════════════════════

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _subject = 'Matemáticas';
  String _category = 'Tarea';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  int _notifDays = 1;
  final List<String> _referenceImagePaths = [];
  bool _isSaving = false;

  static const _subjects = [
    'Matemáticas', 'Español', 'Inglés', 'C. Naturales', 'C. Sociales',
    'Educ. Física', 'Religión', 'Informática', 'Exp. Artísticas',
    'Laboratorio', 'Agropecuaria', 'FDC', 'Otro',
  ];

  static const _categories = ['Tarea', 'Ejercicio', 'Examen', 'Proyecto', 'Otro'];

  int _maxNotifDays(DateTime date) {
    final days = EduDateUtils.daysUntil(date);
    if (days <= 2) return 1;
    return days > 7 ? 7 : days - 1;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
    );
    if (picked == null || !mounted) return;

    // Buscar si el estudiante tiene clase de esta materia ese día
    final entries =
        ref.read(scheduleProvider.notifier).forDay(picked.weekday);
    final match = entries.where((e) => e.subject == _subject).toList();

    if (match.isNotEmpty) {
      // Mostrar sugerencia de hora de clase
      final entry = match.first;
      final accepted = await _showScheduleSuggestion(entry);
      if (!mounted) return;

      if (accepted == true) {
        // Usar la hora de inicio de la clase (minutos desde medianoche)
        final h = entry.startMin ~/ 60;
        final m = entry.startMin % 60;
        setState(() {
          _dueDate = DateTime(
            picked.year, picked.month, picked.day, h, m,
          );
          final maxD = _maxNotifDays(_dueDate);
          if (_notifDays > maxD) _notifDays = maxD;
        });
        return;
      }
      // Si rechaza la sugerencia → abrir time picker normal
    }

    // Sin sugerencia o rechazó → selector de hora manual
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDate),
    );
    setState(() {
      final hour = pickedTime?.hour ?? _dueDate.hour;
      final minute = pickedTime?.minute ?? _dueDate.minute;
      _dueDate = DateTime(picked.year, picked.month, picked.day, hour, minute);
      final maxD = _maxNotifDays(_dueDate);
      if (_notifDays > maxD) _notifDays = maxD;
    });
  }

  Future<bool?> _showScheduleSuggestion(ScheduleBlock entry) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
        final startH = (entry.startMin ~/ 60).toString().padLeft(2, '0');
        final startM = (entry.startMin % 60).toString().padLeft(2, '0');
        final endH = (entry.endMin ~/ 60).toString().padLeft(2, '0');
        final endM = (entry.endMin % 60).toString().padLeft(2, '0');
        return AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('💡', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sugerencia de horario',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: isDark ? Colors.white : AppColors.navyBlue,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Yordan tiene $_subject ese día a las:',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: AppColors.accentBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '$startH:$startM – $endH:$endM',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '¿Usar esa hora o elegir manualmente?',
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12,
                  color: isDark ? Colors.white38 : AppColors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Elegir manualmente',
                  style: TextStyle(fontFamily: 'Nunito')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usar esa hora',
                  style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addReferenceImage() async {
    if (_referenceImagePaths.length >= 12) return;
    final camera = CameraService.instance;
    final tempId = 'ref_${DateTime.now().millisecondsSinceEpoch}';

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Agregar imagen (${_referenceImagePaths.length + 1}/12)',
              style: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.accentBlue,
                child: Icon(Icons.camera_alt_rounded, color: Colors.white),
              ),
              title: const Text('Tomar foto'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final path = await camera.takePhoto(taskId: tempId);
                if (path != null && mounted) {
                  setState(() => _referenceImagePaths.add(path));
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.navyBlue,
                child: Icon(Icons.photo_library_rounded, color: Colors.white),
              ),
              title: const Text('Elegir de galería'),
              onTap: () async {
                Navigator.of(ctx).pop();
                final path = await camera.pickFromGallery(taskId: tempId);
                if (path != null && mounted) {
                  setState(() => _referenceImagePaths.add(path));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(taskProvider.notifier).createTask(
            title: _titleCtrl.text.trim(),
            subject: _subject,
            description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            category: _category,
            dueDate: _dueDate,
            notificationDaysBefore: _notifDays,
            referenceImagePaths: _referenceImagePaths,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear tarea: $e'),
            backgroundColor: AppColors.statusRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysLeft = EduDateUtils.daysUntil(_dueDate);
    final maxNotifDays = _maxNotifDays(_dueDate);
    final notifLocked = daysLeft <= 2;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Nueva tarea',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Guardar',
                style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
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
                      labelText: 'Título de la tarea',
                      hintText: 'Ej. Ejercicios página 45',
                      prefixIcon: Icon(Icons.title_rounded),
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
                      hintText: 'Detalles adicionales...',
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
                  _label('Materia', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _subject,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                    items: _subjects
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _subject = v!),
                  ),
                  const SizedBox(height: 14),
                  _label('Tipo', isDark),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.label_outline_rounded),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _category = v!),
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
                  _label('Fecha de entrega', isDark),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined,
                        color: AppColors.accentBlue),
                    title: Text(
                      EduDateUtils.fullDateLabel(_dueDate),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                    subtitle: Text(
                      '${EduDateUtils.dueDateLabel(_dueDate)}  ·  ${EduDateUtils.timeLabel(_dueDate)}',
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 12,
                        color: AppColors.forDaysLeft(daysLeft),
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: _pickDate,
                      child: const Text('Cambiar'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Días de anticipación — slider inteligente
            _card(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _label('Notificar con anticipación', isDark),
                      const Spacer(),
                      Text(
                        '$_notifDays día${_notifDays > 1 ? 's' : ''} antes',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: notifLocked
                              ? AppColors.statusAmber
                              : AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                  if (notifLocked) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.statusAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.statusAmber.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.statusAmber, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              daysLeft <= 0
                                  ? 'Fecha vencida o de hoy. Notificación inmediata.'
                                  : 'Fecha próxima — notificación fijada a 1 día antes.',
                              style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 12,
                                  color: AppColors.statusAmber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Slider(
                    value: _notifDays.toDouble(),
                    min: 1,
                    max: maxNotifDays.toDouble(),
                    divisions: maxNotifDays > 1 ? maxNotifDays - 1 : null,
                    activeColor: notifLocked
                        ? AppColors.statusAmber
                        : AppColors.accentBlue,
                    inactiveColor: (notifLocked
                            ? AppColors.statusAmber
                            : AppColors.accentBlue)
                        .withValues(alpha: 0.2),
                    onChanged: notifLocked
                        ? null
                        : (v) => setState(() => _notifDays = v.round()),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        maxNotifDays,
                        (i) => Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: isDark ? Colors.white38 : AppColors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Imágenes de referencia (0–12)
            _card(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _label('Imágenes de referencia (opcional)', isDark),
                      const Spacer(),
                      if (_referenceImagePaths.isNotEmpty)
                        Text(
                          '${_referenceImagePaths.length}/12',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: isDark ? Colors.white38 : AppColors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Adjunta hasta 12 fotos para que Yordan sepa cómo debe verse',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      color: isDark ? Colors.white38 : AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (int i = 0; i < _referenceImagePaths.length; i++)
                        _RefImageThumb(
                          path: _referenceImagePaths[i],
                          isDark: isDark,
                          onDelete: () => setState(
                              () => _referenceImagePaths.removeAt(i)),
                        ),
                      if (_referenceImagePaths.length < 12)
                        _AddImageTile(
                          isDark: isDark,
                          onTap: _addReferenceImage,
                        ),
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
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Crear tarea'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, required bool isDark}) {
    return Container(
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
  }

  Widget _label(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white54 : AppColors.grey,
        ),
      );
}

// ─────────────────────────────────────────────────────────────
// REFERENCE IMAGE WIDGETS
// ─────────────────────────────────────────────────────────────

class _RefImageThumb extends StatelessWidget {
  final String path;
  final bool isDark;
  final VoidCallback onDelete;

  const _RefImageThumb({
    required this.path,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedLocalImage(
              path: path,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 3,
            right: 3,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddImageTile extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AddImageTile({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : AppColors.offWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white24
                : AppColors.accentBlue.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 28,
              color: isDark
                  ? Colors.white38
                  : AppColors.accentBlue.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 3),
            Text(
              'Agregar',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 10,
                color: isDark
                    ? Colors.white38
                    : AppColors.accentBlue.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
