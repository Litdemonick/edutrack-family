

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/services/camera_service.dart';
import 'package:edutrack_family/core/shared/widgets/cached_local_image.dart';
import 'package:edutrack_family/core/shared/widgets/fullscreen_image_viewer.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';

// ═══════════════════════════════════════════════════════════════
// COMPLETE TASK SCREEN — EduTrack Family
// Yordan marca tarea como completada: múltiples fotos + comentario.
// Máx 12 fotos. Mínimo 1 recomendado (no obligatorio).
// ═══════════════════════════════════════════════════════════════

const int _maxPhotos = 12;

class CompleteTaskScreen extends ConsumerStatefulWidget {
  final TaskModel task;
  const CompleteTaskScreen({super.key, required this.task});

  @override
  ConsumerState<CompleteTaskScreen> createState() => _CompleteTaskScreenState();
}

class _CompleteTaskScreenState extends ConsumerState<CompleteTaskScreen> {
  final List<String> _photos = [];
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // ── Cámara ──────────────────────────────────────────────────
  Future<void> _takePhoto() async {
    if (_photos.length >= _maxPhotos) return;
    final path =
        await CameraService.instance.takePhoto(taskId: widget.task.id);
    if (path != null && mounted) setState(() => _photos.add(path));
  }

  Future<void> _pickFromGallery() async {
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) return;

    final paths = await CameraService.instance.pickMultipleFromGallery(
      taskId: widget.task.id,
      maxCount: remaining,
    );
    if (paths.isNotEmpty && mounted) setState(() => _photos.addAll(paths));
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  // ── Enviar ───────────────────────────────────────────────────
  Future<void> _confirm() async {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, agrega al menos una foto de evidencia para completar la tarea.'),
          backgroundColor: AppColors.statusRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    await ref.read(taskProvider.notifier).submitForReview(
          widget.task.id,
          photoPaths: _photos,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Mostrar overlay de motivación
    await _showMotivationOverlay();

    if (mounted) {
      context.pop(); // sale de complete
      context.pop(); // sale de detail
    }
  }

  Future<void> _showMotivationOverlay() async {
    HapticFeedback.heavyImpact();
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (_, anim, _, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      ),
      pageBuilder: (ctx, _, _) => _MotivationOverlay(
        taskTitle: widget.task.title,
        onDone: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAddMore = _photos.length < _maxPhotos;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Enviar para revisión',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info de tarea ──────────────────────────────────
            _TaskInfoCard(task: widget.task, isDark: isDark),

            const SizedBox(height: 24),

            // ── Referencia del admin ───────────────────────────
            if (widget.task.hasReference) ...[
              _SectionTitle(
                widget.task.referenceImagePaths.length > 1
                    ? 'Imágenes de referencia del admin (${widget.task.referenceImagePaths.length})'
                    : 'Imagen de referencia del admin',
                isDark,
              ),
              const SizedBox(height: 8),
              if (widget.task.referenceImagePaths.length == 1)
                GestureDetector(
                  onTap: () => _openFullscreen(
                      context, widget.task.referenceImagePaths.first),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedLocalImage(
                      path: widget.task.referenceImagePaths.first,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 160,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: widget.task.referenceImagePaths.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => _openFullscreen(
                          context, widget.task.referenceImagePaths[i]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedLocalImage(
                          path: widget.task.referenceImagePaths[i],
                          width: 140,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // ── Fotos de evidencia ─────────────────────────────
            Row(
              children: [
                _SectionTitle('Fotos de evidencia', isDark),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.statusRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Obligatorio',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusRed,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_photos.length}/$_maxPhotos',
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : AppColors.navyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Agrega al menos 1 foto como evidencia de la tarea completada.',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: isDark ? Colors.white38 : AppColors.grey,
              ),
            ),
            const SizedBox(height: 12),

            // Grid de fotos
            if (_photos.isNotEmpty)
              _PhotoGrid(
                photos: _photos,
                onRemove: _removePhoto,
                onFullscreen: (p) => _openFullscreen(context, p),
                isDark: isDark,
              ),

            if (canAddMore) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _PhotoButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Cámara',
                      isDark: isDark,
                      onTap: _takePhoto,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PhotoButton(
                      icon: Icons.photo_library_outlined,
                      label: 'Galería',
                      isDark: isDark,
                      onTap: _pickFromGallery,
                    ),
                  ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Límite de $_maxPhotos fotos alcanzado',
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppColors.statusAmber,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // ── Comentario ─────────────────────────────────────
            _SectionTitle('Comentario (opcional)', isDark),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white12 : AppColors.lightGrey,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _noteCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Agrega un comentario para el admin sobre esta tarea...',
                  hintStyle: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.navyBlue,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Botón principal ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _confirm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_isSaving ? 'Enviando...' : 'Enviar para revisión'),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, String path) {
    FullscreenImageViewer.open(
      context,
      paths: widget.task.referenceImagePaths.isNotEmpty &&
              widget.task.referenceImagePaths.contains(path)
          ? widget.task.referenceImagePaths
          : _photos.contains(path)
              ? _photos
              : [path],
      initialIndex: widget.task.referenceImagePaths.contains(path)
          ? widget.task.referenceImagePaths.indexOf(path)
          : _photos.contains(path)
              ? _photos.indexOf(path)
              : 0,
      title: widget.task.title,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// GRID DE FOTOS
// ─────────────────────────────────────────────────────────────

class _PhotoGrid extends StatelessWidget {
  final List<String> photos;
  final void Function(int) onRemove;
  final void Function(String) onFullscreen;
  final bool isDark;

  const _PhotoGrid({
    required this.photos,
    required this.onRemove,
    required this.onFullscreen,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        return GestureDetector(
          onTap: () => onFullscreen(photos[i]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedLocalImage(
                  path: photos[i],
                  fit: BoxFit.cover,
                ),
              ),
              // Botón eliminar
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.statusRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4)
                      ],
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// OVERLAY DE MOTIVACIÓN (Feature 10)
// ─────────────────────────────────────────────────────────────

class _MotivationOverlay extends StatefulWidget {
  final String taskTitle;
  final VoidCallback onDone;

  const _MotivationOverlay(
      {required this.taskTitle, required this.onDone});

  @override
  State<_MotivationOverlay> createState() => _MotivationOverlayState();
}

class _MotivationOverlayState extends State<_MotivationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _checkScale;
  late final Animation<double> _textFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _checkScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
    );
    _textFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _ctrl.forward();

    // Auto-dismiss
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDone,
      child: Material(
        color: Colors.transparent,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Círculo de check animado
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.statusGreen,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.statusGreen.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                FadeTransition(
                  opacity: _textFade,
                  child: Column(
                    children: [
                      const Text(
                        '¡Muy bien Yordan! 🎉',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Has completado "${widget.taskTitle}".\nAhora está en pendiente de revisión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.80),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Toca para continuar',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────

class _TaskInfoCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;
  const _TaskInfoCard({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forDaysLeft(task.daysLeft,
        isCompleted: task.isCompleted, isOverdue: task.isUrgent);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: AppColors.accentBlue, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.subject,
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.navyBlue,
                      ),
                    ),
                  ],
                ),
              ),
              TrafficLightBadge(task: task),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 15, color: isDark ? Colors.white38 : AppColors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  EduDateUtils.fullDateLabel(task.dueDate),
                  style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.navyBlue,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.label_outline_rounded,
                  size: 15, color: isDark ? Colors.white38 : AppColors.grey),
              const SizedBox(width: 4),
              Text(
                task.category,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : AppColors.navyBlue,
                ),
              ),
              const Spacer(),
              Icon(Icons.hourglass_bottom_rounded,
                  size: 15, color: color),
              const SizedBox(width: 4),
              Text(
                task.isCompleted
                    ? 'Completada'
                    : AppStrings.daysLeftLabel(task.daysLeft),
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionTitle(this.text, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : AppColors.navyBlue,
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _PhotoButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? Colors.white12 : AppColors.lightGrey),
        ),
        child: Column(
          children: [
            Icon(icon, size: 26, color: AppColors.accentBlue),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.navyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


