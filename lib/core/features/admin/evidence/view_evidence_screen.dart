
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/constants/app_routes.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

import 'package:edutrack_family/core/providers/task_provider.dart';
import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';
import 'package:edutrack_family/core/shared/widgets/empty_state.dart';

import 'package:edutrack_family/core/shared/widgets/cached_local_image.dart';
import 'package:edutrack_family/core/shared/widgets/loading_widget.dart';
import 'package:edutrack_family/core/shared/widgets/fullscreen_image_viewer.dart';

// ═══════════════════════════════════════════════════════════════
// VIEW EVIDENCE SCREEN — EduTrack Family
// Zona de Revisión del admin: tareas pendientes + aprobadas.
// ═══════════════════════════════════════════════════════════════

class ViewEvidenceScreen extends ConsumerWidget {
  const ViewEvidenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: NestedScrollView(
          headerSliverBuilder: (_, _) => [
            SliverAppBar(
              automaticallyImplyLeading: false,
              pinned: true,
              title: const Text(
                'Zona de Revisión',
                style: TextStyle(
                    fontFamily: 'Poppins', fontWeight: FontWeight.w600),
              ),
              bottom: TabBar(
                tabs: const [
                  Tab(text: 'Por revisar'),
                  Tab(text: 'Aprobadas'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicator: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(20),
                labelStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          body: const TabBarView(
            children: [
              _PendingReviewTab(),
              _ApprovedTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PESTAÑA 1 — Tareas pendientes de revisión
// ─────────────────────────────────────────────────────────────

class _PendingReviewTab extends ConsumerWidget {
  const _PendingReviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return tasksAsync.when(
      data: (tasks) {
        final pending = tasks
            .where((t) => t.isInReview)
            .toList()
          ..sort((a, b) {
            final ca = a.completedAt ?? a.updatedAt;
            final cb = b.completedAt ?? b.updatedAt;
            return cb.compareTo(ca);
          });

        if (pending.isEmpty) {
          return EmptyState(
            emoji: '✅',
            title: 'Sin pendientes',
            subtitle:
                'Cuando Yordan envíe una tarea aparecerá aquí para revisarla.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: pending.length,
          itemBuilder: (_, i) =>
              _ReviewCard(task: pending[i], isDark: isDark),
        );
      },
      loading: () => const LoadingList(),
      error: (e, _) =>
          EmptyState(emoji: '⚠️', title: 'Error', subtitle: e.toString()),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CARD DE REVISIÓN — multi-foto + comentario + botones
// ─────────────────────────────────────────────────────────────

class _ReviewCard extends ConsumerStatefulWidget {
  final TaskModel task;
  final bool isDark;

  const _ReviewCard({required this.task, required this.isDark});

  @override
  ConsumerState<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends ConsumerState<_ReviewCard> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    await ref.read(taskProvider.notifier).acceptTask(widget.task.id);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reject() async {
    final reason = await _showRejectDialog();
    if (reason == null) return;

    setState(() => _busy = true);
    await ref.read(taskProvider.notifier).rejectTask(widget.task.id, reason: reason);

    // Doble capa: Admin ve confirmación interna, Estudiante recibe push + FCM
    await NotificationBus.dispatch(
      ref: ref,
      title: '❌ Tarea rechazada',
      body: reason.isEmpty
          ? '"${widget.task.title}" fue rechazada. Corrígela y reenvíala.'
          : '"${widget.task.title}" fue rechazada: $reason',
      internalType: NotificationType.taskRejected,
      channel: NotificationChannel.system,
      taskId: widget.task.id,
      payload: 'task:${widget.task.id}',
      targetRole: 'student',
    );

    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _showRejectDialog() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rechazar tarea',
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Rechazar "${widget.task.title}"?\nYordan deberá corregirla y volver a enviarla.',
              style: const TextStyle(fontFamily: 'Nunito'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: 'Explica qué debe corregir...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Rechazar',
                style: TextStyle(color: AppColors.statusRed)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    return reason;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final photos = task.evidencePhotoPaths;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Galería de fotos ─────────────────────────────────
          if (photos.isNotEmpty)
            _PhotoGallery(
              photos: photos,
              taskTitle: task.title,
              isDark: isDark,
            )
          else
            _NoPhotoHeader(isDark: isDark),

          // ── Contenido ────────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(AppRoutes.taskView, extra: {
              'task': task,
              'isAdmin': true,
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge + materia
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF7C4DFF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⏳ En revisión',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7C4DFF),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (photos.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.photo_library_outlined,
                                  size: 11, color: AppColors.accentBlue),
                              const SizedBox(width: 3),
                              Text(
                                '${photos.length} foto${photos.length > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  fontFamily: 'Nunito',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      Text(
                        task.subject,
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          color: isDark ? Colors.white38 : AppColors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Título
                  Text(
                    task.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                  ),

                  // Fecha y hora de envío
                  if (task.completedAt != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12,
                            color: isDark ? Colors.white38 : AppColors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Enviada el ${EduDateUtils.dateTimeLabel(task.completedAt!)}',
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            color: isDark ? Colors.white38 : AppColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Comentario de Yordan
                  if (task.completionNote != null &&
                      task.completionNote!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : AppColors.lightGrey,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 14, color: AppColors.accentBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task.completionNote!,
                              style: TextStyle(
                                fontFamily: 'Nunito',
                                fontSize: 13,
                                color: isDark ? Colors.white70 : AppColors.navyBlue,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Detalles de la tarea original (colapsable) ──
                  if (task.description != null && task.description!.isNotEmpty ||
                      task.referenceImagePaths.isNotEmpty)
                    _TaskDetailsExpansion(task: task, isDark: isDark),

                  const SizedBox(height: 14),

                  // Botones Aceptar / Rechazar
                  if (_busy)
                    const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _reject,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.statusRed,
                              side: const BorderSide(
                                  color: AppColors.statusRed),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Rechazar',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _accept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Aceptar',
                                style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
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
// GALERÍA DE FOTOS — horizontal scrollable
// ─────────────────────────────────────────────────────────────

class _PhotoGallery extends StatefulWidget {
  final List<String> photos;
  final String taskTitle;
  final bool isDark;

  const _PhotoGallery(
      {required this.photos, required this.taskTitle, required this.isDark});

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Stack(
        children: [
          // Imágenes
          SizedBox(
            height: 200,
            child: PageView.builder(
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openGallery(context, i),
                child: CachedLocalImage(
                  path: widget.photos[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),

          // Indicadores de página
          if (widget.photos.length > 1)
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.photos.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _current == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _current == i
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

          // Botones acción (superior derecho)
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                // Compartir por WhatsApp
                _GalleryActionButton(
                  icon: Icons.share_rounded,
                  onTap: () => _shareWhatsApp(context),
                ),
                const SizedBox(width: 6),
                // Ver en pantalla completa
                _GalleryActionButton(
                  icon: Icons.fullscreen_rounded,
                  onTap: () => _openGallery(context, _current),
                ),
              ],
            ),
          ),

          // Contador
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_current + 1} / ${widget.photos.length}',
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    FullscreenImageViewer.open(
      context,
      paths: widget.photos,
      initialIndex: initialIndex,
      title: widget.taskTitle,
    );
  }

  void _shareWhatsApp(BuildContext context) {
    final text =
        '📚 Tarea completada: "${widget.taskTitle}"\n✅ Enviada para revisión en EduTrack Family';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Texto copiado al portapapeles. Ábrelo en WhatsApp manualmente.',
          style: TextStyle(fontFamily: 'Nunito'),
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class _GalleryActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GalleryActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

class _NoPhotoHeader extends StatelessWidget {
  final bool isDark;
  const _NoPhotoHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : AppColors.offWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 18, color: AppColors.grey),
            SizedBox(width: 6),
            Text('Sin fotos de evidencia',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 12,
                    color: AppColors.grey)),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────
// PESTAÑA 2 — Tareas aprobadas con evidencias
// ─────────────────────────────────────────────────────────────

class _ApprovedTab extends ConsumerWidget {
  const _ApprovedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return tasksAsync.when(
      data: (tasks) {
        final withEvidence = tasks
            .where((t) => t.hasEvidence && t.isCompleted)
            .toList()
          ..sort((a, b) {
            final ca = a.completedAt ?? a.createdAt;
            final cb = b.completedAt ?? b.createdAt;
            return cb.compareTo(ca);
          });

        if (withEvidence.isEmpty) {
          return EmptyState(
            emoji: '📷',
            title: 'Sin evidencias',
            subtitle: 'Las fotos de tareas aprobadas aparecerán aquí.',
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: withEvidence.length,
          itemBuilder: (_, i) =>
              _EvidenceCard(task: withEvidence[i], isDark: isDark),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, _) =>
          EmptyState(emoji: '⚠️', title: 'Error', subtitle: e.toString()),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  final TaskModel task;
  final bool isDark;

  const _EvidenceCard({required this.task, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final photos = task.evidencePhotoPaths;

    return GestureDetector(
      onTap: () => FullscreenImageViewer.open(
        context,
        paths: photos,
        initialIndex: 0,
        title: task.title,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedLocalImage(
                    path: photos.first,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                  if (photos.length > 1)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.photo_library_rounded,
                                size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              '${photos.length}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.subject,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 10,
                      color: isDark ? Colors.white38 : AppColors.grey,
                    ),
                  ),
                  Text(
                    task.title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.navyBlue,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.completedAt != null)
                    Text(
                      EduDateUtils.shortDateLabel(task.completedAt!),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 10,
                        color: isDark ? Colors.white38 : AppColors.grey,
                      ),
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

// ─────────────────────────────────────────────────────────────
// WIDGET: DETALLES DE TAREA COLAPSABLE
// Muestra descripción + imágenes de referencia dentro de la review card.
// ─────────────────────────────────────────────────────────────

class _TaskDetailsExpansion extends StatefulWidget {
  final TaskModel task;
  final bool isDark;

  const _TaskDetailsExpansion({required this.task, required this.isDark});

  @override
  State<_TaskDetailsExpansion> createState() => _TaskDetailsExpansionState();
}

class _TaskDetailsExpansionState extends State<_TaskDetailsExpansion> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final isDark = widget.isDark;

    return Column(
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.lightGrey,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_outlined,
                  size: 15,
                  color: isDark ? Colors.white38 : AppColors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Detalles de la tarea',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : AppColors.grey,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: isDark ? Colors.white38 : AppColors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white10 : AppColors.lightGrey,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría y fecha
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.category,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.calendar_today_outlined,
                        size: 12,
                        color: isDark ? Colors.white38 : AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      EduDateUtils.fullDateLabel(task.dueDate),
                      style: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: isDark ? Colors.white54 : AppColors.grey,
                      ),
                    ),
                  ],
                ),

                // Descripción
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description!,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppColors.navyBlue,
                    ),
                  ),
                ],

                // Imágenes de referencia
                if (task.referenceImagePaths.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '📷 Imágenes de referencia (${task.referenceImagePaths.length})',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white38 : AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: task.referenceImagePaths.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (ctx, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedLocalImage(
                          path: task.referenceImagePaths[i],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }
}
