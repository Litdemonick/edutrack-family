
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/services/image_transfer_service.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';
import 'package:edutrack_family/core/shared/widgets/cached_local_image.dart';
import 'package:edutrack_family/core/shared/widgets/fullscreen_image_viewer.dart';

// ═══════════════════════════════════════════════════════════════
// TASK DETAIL SCREEN — EduTrack Family
// Detalle completo de una tarea para el estudiante Yordan.
// Al abrirse, descarga imágenes de referencia del Admin si no
// están ya guardadas localmente.
// ═══════════════════════════════════════════════════════════════

class TaskDetailScreen extends ConsumerStatefulWidget {
  final TaskModel task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late TaskModel _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _downloadImagesIfNeeded();
  }

  Future<void> _downloadImagesIfNeeded() async {
    if (!_task.hasReference) return;

    // Verificar que los paths actuales realmente existen en ESTE dispositivo.
    // Si el Celular B recibió paths del Celular A, no existirán localmente.
    final validPaths = await _filterValidLocalPaths(_task.referenceImagePaths);
    if (validPaths.length == _task.referenceImagePaths.length && validPaths.isNotEmpty) {
      // Todas las imágenes ya están en el filesystem local — nada que hacer
      return;
    }

    // Buscar en caché local del sistema de archivos
    final cached = await ImageTransferService.instance.getLocalPaths(
      _task.id,
      'reference',
    );
    if (cached.isNotEmpty) {
      if (mounted) {
        setState(() => _task = _task.copyWith(referenceImagePaths: cached));
      }
      return;
    }

    // Descargar de Firestore (primer acceso en este dispositivo)
    final paths = await ImageTransferService.instance.downloadImages(
      taskId: _task.id,
      type: 'reference',
    );
    if (paths.isNotEmpty && mounted) {
      setState(() => _task = _task.copyWith(referenceImagePaths: paths));
      await DatabaseHelper.instance.update(
        DatabaseHelper.tableTask,
        _task.toMap(),
        _task.id,
      );
    }
  }

  /// Devuelve solo los paths que realmente existen en el filesystem local.
  Future<List<String>> _filterValidLocalPaths(List<String> paths) async {
    if (paths.isEmpty) return [];
    final valid = <String>[];
    for (final p in paths) {
      if (p.startsWith('http') || await File(p).exists()) {
        valid.add(p);
      }
    }
    return valid;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forDaysLeft(_task.daysLeft, isCompleted: _task.isCompleted, isOverdue: _task.isUrgent);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _task.subject,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              title: Text(
                _task.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado + badge
                  Row(
                    children: [
                      TrafficLightBadge(task: _task),
                      const Spacer(),
                      _InfoChip(
                        icon: Icons.label_outline_rounded,
                        label: _task.category,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Fecha de entrega
                  _DetailCard(
                    isDark: isDark,
                    child: _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha de entrega',
                      value: EduDateUtils.fullDateLabel(_task.dueDate),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Materia + días restantes
                  _DetailCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _DetailRow(
                          icon: Icons.school_outlined,
                          label: 'Materia',
                          value: _task.subject,
                          isDark: isDark,
                        ),
                        Divider(
                          color: isDark ? Colors.white12 : AppColors.lightGrey,
                          height: 16,
                        ),
                        _DetailRow(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Tiempo restante',
                          value: _task.isCompleted
                              ? AppStrings.statusDone
                              : AppStrings.daysLeftLabel(_task.daysLeft),
                          isDark: isDark,
                          valueColor: color,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Imágenes de referencia (adjuntadas por admin)
                  if (_task.hasReference) ...[
                    _DetailCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _task.referenceImagePaths.length > 1
                                ? 'Imágenes de referencia (${_task.referenceImagePaths.length})'
                                : 'Imagen de referencia',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_task.referenceImagePaths.length == 1)
                            GestureDetector(
                              onTap: () => FullscreenImageViewer.open(
                                context,
                                paths: _task.referenceImagePaths,
                                title: _task.title,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedLocalImage(
                                  path: _task.referenceImagePaths.first,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 110,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: _task.referenceImagePaths.length,
                                separatorBuilder: (_, _) => const SizedBox(width: 8),
                                itemBuilder: (_, i) => GestureDetector(
                                  onTap: () => FullscreenImageViewer.open(
                                    context,
                                    paths: _task.referenceImagePaths,
                                    title: _task.title,
                                    initialIndex: i,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedLocalImage(
                                      path: _task.referenceImagePaths[i],
                                      width: 100,
                                      height: 110,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Descripción
                  if (_task.description != null && _task.description!.isNotEmpty) ...[
                    _DetailCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Descripción',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _task.description!,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Evidencia fotográfica
                  if (_task.hasEvidence) ...[
                    _DetailCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _task.evidencePhotoPaths.length > 1
                                ? 'Evidencia fotográfica (${_task.evidencePhotoPaths.length})'
                                : 'Evidencia fotográfica',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white54 : AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_task.evidencePhotoPaths.length == 1)
                            GestureDetector(
                              onTap: () => FullscreenImageViewer.open(
                                context,
                                paths: _task.evidencePhotoPaths,
                                title: _task.title,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedLocalImage(
                                  path: _task.evidencePhotoPaths.first,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisSpacing: 6,
                                crossAxisSpacing: 6,
                              ),
                              itemCount: _task.evidencePhotoPaths.length,
                              itemBuilder: (_, i) => GestureDetector(
                                onTap: () => FullscreenImageViewer.open(
                                  context,
                                  paths: _task.evidencePhotoPaths,
                                  title: _task.title,
                                  initialIndex: i,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedLocalImage(
                                    path: _task.evidencePhotoPaths[i],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Fecha completada
                  if (_task.isCompleted && _task.completedAt != null) ...[
                    _DetailCard(
                      isDark: isDark,
                      child: _DetailRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Completada el',
                        value: EduDateUtils.dateTimeLabel(_task.completedAt!),
                        isDark: isDark,
                        valueColor: AppColors.statusGreen,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  const SizedBox(height: 16),

                  // Botones de acción
                  if (!_task.isCompleted)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.studentCompleteTaskPath(_task.id),
                          extra: _task,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Marcar como completada'),
                      ),
                    ),

                  if (_task.isCompleted && !_task.hasEvidence) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.studentCompleteTaskPath(_task.id),
                          extra: _task,
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('Agregar evidencia'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNOS
// ─────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _DetailCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18,
            color: isDark ? Colors.white38 : AppColors.grey),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: isDark ? Colors.white54 : AppColors.grey,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? (isDark ? Colors.white : AppColors.navyBlue),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : AppColors.offWhite,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white54 : AppColors.grey),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: isDark ? Colors.white54 : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
