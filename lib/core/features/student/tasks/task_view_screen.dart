import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/app_strings.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';
import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/services/evidence_image_service.dart';
import 'package:edutrack_family/core/shared/widgets/confirmation_dialog.dart';
import 'package:edutrack_family/core/features/student/dashboard/widgets/traffic_light_badge.dart';
import 'package:edutrack_family/core/shared/widgets/cached_local_image.dart';
import 'package:edutrack_family/core/shared/widgets/fullscreen_image_viewer.dart';

// ═══════════════════════════════════════════════════════════════
// TASK VIEW SCREEN — EduTrack Family
// Visualización completa de una tarea. Funciona para admin y estudiante.
// Al abrirse, descarga imágenes faltantes (referencia o evidencia).
// ═══════════════════════════════════════════════════════════════

class TaskViewScreen extends ConsumerStatefulWidget {
  final TaskModel task;
  final bool isAdmin;

  const TaskViewScreen({super.key, required this.task, this.isAdmin = false});

  @override
  ConsumerState<TaskViewScreen> createState() => _TaskViewScreenState();
}

class _TaskViewScreenState extends ConsumerState<TaskViewScreen> {
  late TaskModel _task;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _downloadImagesIfNeeded();
  }

  Future<void> _downloadImagesIfNeeded() async {
    final imgSvc = EvidenceImageService.instance;
    bool changed = false;

    // Imágenes de referencia
    if (_task.hasReference) {
      final needsRefresh = await _imagesNeedRefresh(_task.referenceImagePaths);
      if (needsRefresh) {
        // Forzar re-descarga desde Firestore (Admin editó o primer acceso)
        final paths = await imgSvc.downloadImages(studentId: _task.studentId, taskId: _task.id, kind: 'reference');
        if (paths.isNotEmpty) {
          _task = _task.copyWith(referenceImagePaths: paths);
          changed = true;
        } else {
          // Firestore vacío — intentar caché local
          final cached = await imgSvc.getLocalPaths(_task.id, 'reference');
          if (cached.isNotEmpty) {
            _task = _task.copyWith(referenceImagePaths: cached);
            changed = true;
          }
        }
      }
    }

    // Evidencias
    if (_task.hasEvidence) {
      final needsRefresh = await _imagesNeedRefresh(_task.evidencePhotoPaths);
      if (needsRefresh) {
        final paths = await imgSvc.downloadImages(studentId: _task.studentId, taskId: _task.id, kind: 'evidence');
        if (paths.isNotEmpty) {
          _task = _task.copyWith(evidencePhotoPaths: paths);
          changed = true;
        } else {
          final cached = await imgSvc.getLocalPaths(_task.id, 'evidence');
          if (cached.isNotEmpty) {
            _task = _task.copyWith(evidencePhotoPaths: cached);
            changed = true;
          }
        }
      }
    }

    if (changed && mounted) {
      setState(() {});
      await DatabaseHelper.instance.update(
        DatabaseHelper.tableTask,
        _task.toMap(),
        _task.id,
      );
    }
  }

  /// Devuelve true si se necesita descargar:
  ///   - No hay paths, O
  ///   - Al menos un archivo no existe en el filesystem local
  Future<bool> _imagesNeedRefresh(List<String> paths) async {
    if (paths.isEmpty) return true;
    for (final p in paths) {
      if (p.startsWith('http')) continue;
      if (!await File(p).exists()) return true;
    }
    return false; // todos los archivos existen
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.forDaysLeft(_task.daysLeft, isCompleted: _task.isCompleted, isOverdue: _task.isUrgent);
    final chipsTop = MediaQuery.of(context).padding.top + kToolbarHeight + 10;


    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF12121E) : AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar con gradiente ─────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => context.pop(),
            ),
            actions: const [],
            backgroundColor: color,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.fromSTEB(56, 0, 16, 14),
              title: Text(
                _task.title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black38)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.95),
                      color.withValues(alpha: 0.70),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      bottom: -20,
                      child: Icon(
                        Icons.assignment_rounded,
                        size: 160,
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    // Badges en la zona SUPERIOR — el título animado nunca llega aquí
                    Positioned(
                      left: 20,
                      right: 20,
                      top: chipsTop,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _HeaderChip(_task.subject),
                          if (_task.category.isNotEmpty)
                            _HeaderChip(_task.category, opacity: 0.15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16, 16, 16,
                MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estado + categoría (Wrap previene overflow con cualquier tamaño)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TrafficLightBadge(task: _task),
                      if (_task.category.isNotEmpty)
                        _InfoBadge(
                          icon: Icons.label_outline_rounded,
                          label: _task.category,
                          isDark: isDark,
                        ),
                      _InfoBadge(
                        icon: Icons.notifications_outlined,
                        label: '${_task.notificationDaysBefore}d antes',
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Fecha + tiempo restante
                  _InfoCard(
                    isDark: isDark,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Fecha de entrega',
                          value: EduDateUtils.fullDateLabel(_task.dueDate),
                          isDark: isDark,
                        ),
                        _Divider(isDark: isDark),
                        _InfoRow(
                          icon: Icons.access_time_rounded,
                          label: 'Hora de entrega',
                          value: EduDateUtils.timeLabel(_task.dueDate),
                          isDark: isDark,
                        ),
                        _Divider(isDark: isDark),
                        _InfoRow(
                          icon: Icons.hourglass_bottom_rounded,
                          label: 'Tiempo restante',
                          value: _task.isCompleted
                              ? AppStrings.statusDone
                              : _task.isInReview
                                  ? 'En revisión'
                                  : AppStrings.daysLeftLabel(_task.daysLeft),
                          isDark: isDark,
                          valueColor: _task.isCompleted
                              ? AppColors.statusGreen
                              : _task.isInReview
                                  ? const Color(0xFF7C4DFF)
                                  : color,
                        ),
                        _Divider(isDark: isDark),
                        _InfoRow(
                          icon: Icons.school_outlined,
                          label: 'Materia',
                          value: _task.subject,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  // Descripción
                  if (_task.description != null && _task.description!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Descripción', isDark: isDark),
                          const SizedBox(height: 8),
                          Text(
                            _task.description!,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              height: 1.55,
                              color: isDark ? Colors.white : AppColors.navyBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Imágenes de referencia
                  if (_task.hasReference) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            _task.referenceImagePaths.length == 1
                                ? 'Imagen de referencia'
                                : 'Imágenes de referencia (${_task.referenceImagePaths.length})',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _ImageGrid(
                            paths: _task.referenceImagePaths,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Nota del estudiante
                  if (_task.completionNote != null && _task.completionNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Nota de Yordan', isDark: isDark),
                          const SizedBox(height: 8),
                          Text(
                            _task.completionNote!,
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 14,
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white70 : AppColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Evidencia fotográfica
                  if (_task.hasEvidence) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(
                            _task.evidencePhotoPaths.length == 1
                                ? 'Evidencia fotográfica'
                                : 'Evidencias (${_task.evidencePhotoPaths.length})',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 10),
                          _ImageGrid(
                            paths: _task.evidencePhotoPaths,
                            isDark: isDark,
                            borderColor: AppColors.statusGreen,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Historial de conversación ─────────────────
                  if (_task.conversationHistory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel('Historial', isDark: isDark),
                          const SizedBox(height: 8),
                          for (final entry in _task.conversationHistory)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ConversationBubble(
                                entry: entry,
                                isDark: isDark,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Fecha completada
                  if (_task.isCompleted && _task.completedAt != null) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      isDark: isDark,
                      child: _InfoRow(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Completada el',
                        value: EduDateUtils.dateTimeLabel(_task.completedAt!),
                        isDark: isDark,
                        valueColor: AppColors.statusGreen,
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),

                  // ── Botones de acción ────────────────────────
                  if (widget.isAdmin) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusRed,
                          side: const BorderSide(color: AppColors.statusRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => _confirmDelete(context),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text(
                          'Eliminar tarea',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ] else if (!_task.isCompleted && !_task.isInReview) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.studentCompleteTaskPath(_task.id),
                          extra: _task,
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text(
                          'Marcar como completada',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ] else if (_task.isInReview) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top_rounded,
                              size: 18, color: Color(0xFF7C4DFF)),
                          SizedBox(width: 8),
                          Text(
                            'Esperando revisión del admin',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7C4DFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_task.isCompleted && !_task.hasEvidence) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(
                          AppRoutes.studentCompleteTaskPath(_task.id),
                          extra: _task,
                        ),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text(
                          'Agregar evidencia fotográfica',
                          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await ConfirmationDialog.show(
      context,
      title: 'Eliminar tarea',
      message:
          '¿Ocultar "${_task.title}" de las listas? La información se conservará para rachas, historial y estadísticas.',
      confirmLabel: 'Eliminar',
      isDangerous: true,
    );
    if (ok == true) {
      await ref.read(taskProvider.notifier).deleteTask(_task.id);
      if (context.mounted) context.pop();
    }
  }
}

// ─────────────────────────────────────────────────────────────
// GRID DE IMÁGENES — tapping abre visor a pantalla completa
// ─────────────────────────────────────────────────────────────
class _ImageGrid extends StatelessWidget {
  final List<String> paths;
  final bool isDark;
  final Color? borderColor;

  const _ImageGrid({required this.paths, required this.isDark, this.borderColor});

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    if (paths.length == 1) {
      return GestureDetector(
        onTap: () => _openFullscreen(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 150,
            width: double.infinity,
            child: _ImageTile(path: paths[0], isDark: isDark, borderColor: borderColor),
          ),
        ),
      );
    }

    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (_, idx) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _openFullscreen(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 100,
              height: 110,
              child: _ImageTile(path: paths[i], isDark: isDark, borderColor: borderColor),
            ),
          ),
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context, int index) {
    FullscreenImageViewer.open(context, paths: paths, initialIndex: index);
  }
}

class _ImageTile extends StatelessWidget {
  final String path;
  final bool isDark;
  final Color? borderColor;

  const _ImageTile({required this.path, required this.isDark, this.borderColor});

  @override
  Widget build(BuildContext context) {
    if (!path.startsWith('http')) {
      final file = File(path);
      if (!file.existsSync()) {
        return Container(
          color: isDark ? Colors.white10 : AppColors.offWhite,
          child: const Icon(Icons.broken_image_outlined, color: AppColors.grey),
        );
      }
    }
    return Container(
      decoration: borderColor != null
          ? BoxDecoration(border: Border.all(color: borderColor!.withValues(alpha: 0.35), width: 1.5))
          : null,
      child: CachedLocalImage(path: path, fit: BoxFit.cover),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNOS
// ─────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _InfoCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;

  const _InfoRow({
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
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: (valueColor ?? AppColors.accentBlue).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: valueColor ?? AppColors.accentBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  color: isDark ? Colors.white38 : AppColors.grey,
                ),
              ),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? (isDark ? Colors.white : AppColors.navyBlue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;

  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white54 : AppColors.grey,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 20,
      color: isDark ? Colors.white10 : AppColors.lightGrey,
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final double opacity;

  const _HeaderChip(this.label, {this.opacity = 0.20});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30), width: 0.8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _InfoBadge({required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : AppColors.offWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : AppColors.lightGrey),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: isDark ? Colors.white54 : AppColors.grey),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : AppColors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BURBUJA DE CONVERSACIÓN — historial de la tarea
// ═══════════════════════════════════════════════════════════════

class _ConversationBubble extends StatelessWidget {
  final ConversationEntry entry;
  final bool isDark;

  const _ConversationBubble({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (entry.author == 'system') {
      return _buildSystemMessage();
    }
    return entry.isFromAdmin ? _buildAdminBubble() : _buildStudentBubble();
  }

  Widget _buildSystemMessage() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            entry.text ?? '',
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white38 : AppColors.grey,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildAdminBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(icon: Icons.admin_panel_settings_outlined, color: AppColors.statusAmber),
        const SizedBox(width: 8),
        Expanded(child: _buildBody(AppColors.statusAmber)),
      ],
    );
  }

  Widget _buildStudentBubble() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildBody(AppColors.accentBlue)),
        const SizedBox(width: 8),
        _Avatar(icon: Icons.person_outline_rounded, color: AppColors.accentBlue),
      ],
    );
  }

  Widget _buildBody(Color accent) {
    return Column(
      crossAxisAlignment: entry.isFromAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.15 : 0.08),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(entry.isFromAdmin ? 4 : 14),
              bottomRight: Radius.circular(entry.isFromAdmin ? 14 : 4),
            ),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          child: Column(
            crossAxisAlignment: entry.isFromAdmin ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              if (entry.text != null && entry.text!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.text!,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),
                ),
              if (entry.photoPaths.isNotEmpty)
                _ImageGrid(
                  paths: entry.photoPaths,
                  isDark: isDark,
                  borderColor: accent,
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatTime(entry.timestamp),
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 10,
            color: isDark ? Colors.white30 : Colors.black38,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.day == now.day && dt.month == now.month && dt.year == now.year;
    if (isToday) {
      return 'Hoy ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.day == yesterday.day && dt.month == yesterday.month && dt.year == yesterday.year;
    if (isYesterday) return 'Ayer ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Avatar extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _Avatar({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}
