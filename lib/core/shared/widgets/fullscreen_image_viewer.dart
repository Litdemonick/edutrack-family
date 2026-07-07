import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// ═══════════════════════════════════════════════════════════════
// FULLSCREEN IMAGE VIEWER — EduTrack Family  v3
//
// FIXES:
//  • Sin pantalla gris: barrierColor negro inmediato + opaque:false
//  • Sin imágenes fantasma: clipBehavior: Clip.hardEdge en InteractiveViewer
//  • Carga suave: frameBuilder con fondo negro garantizado
// ═══════════════════════════════════════════════════════════════

class FullscreenImageViewer extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final String? title;

  const FullscreenImageViewer({
    super.key,
    required this.paths,
    this.initialIndex = 0,
    this.title,
  });

  /// Abre el visor sobre todo el contenido de la app.
  /// showGeneralDialog funciona correctamente con GoRouter + ShellRoute
  /// en cualquier dispositivo (Samsung, Xiaomi, stock Android, etc.)
  static Future<void> open(
    BuildContext context, {
    required List<String> paths,
    int initialIndex = 0,
    String? title,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'image-viewer',
      barrierColor: Colors.black,         // fondo negro inmediato — sin gris
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) => FullscreenImageViewer(
        paths: paths,
        initialIndex: initialIndex,
        title: title,
      ),
      transitionBuilder: (ctx, anim, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      ),
    );
  }

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  late int _current;
  late final PageController _pageCtrl;
  late final AnimationController _uiAnim;
  bool _uiVisible = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _uiAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _uiAnim.dispose();
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _uiVisible = !_uiVisible);
    _uiVisible ? _uiAnim.forward() : _uiAnim.reverse();
  }

  Future<void> _share() async {
    final path = widget.paths[_current];
    if (path.startsWith('http')) {
      await SharePlus.instance.share(ShareParams(text: path));
      return;
    }
    final file = File(path);
    if (!file.existsSync()) {
      _snack('El archivo no existe en este dispositivo.');
      return;
    }
    setState(() => _isSharing = true);
    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        text: widget.title ?? 'EduTrack',
      ));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _showLocation() async {
    final path = widget.paths[_current];
    if (path.startsWith('http')) {
      _snack('Imagen en la nube — sin ruta local.');
      return;
    }
    final dir = File(path).parent.path;
    // El SnackBar de confirmación se muestra DESPUÉS de cerrar la
    // hoja modal (con el context del propio visor, que sí tiene su
    // Scaffold) — mostrarlo desde dentro de la hoja quedaba oculto
    // detrás del modal (visible "asomado" en Windows, invisible del
    // todo en celular, porque el modal cubre toda la pantalla).
    final copied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: _LocationSheet(filePath: path, dir: dir),
      ),
    );
    if (copied == true) _snack('📋 Ruta copiada');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasMultiple = widget.paths.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── Imágenes (PageView con clip para evitar fantasmas) ──
          GestureDetector(
            onTap: _toggleUI,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.paths.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (ctx, i) => _ImagePage(path: widget.paths[i]),
            ),
          ),

          // ── Barra SUPERIOR ──────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _uiAnim,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 8, 20),
                    child: Row(
                      children: [
                        // Botón X
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        // Título + contador
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.title != null)
                                Text(
                                  widget.title!,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              if (hasMultiple)
                                Text(
                                  '${_current + 1} / ${widget.paths.length}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white60),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Dots indicadores ────────────────────────────────────
          if (hasMultiple)
            Positioned(
              bottom: bottomPad + 90,
              left: 0, right: 0,
              child: FadeTransition(
                opacity: _uiAnim,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.paths.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _current == i ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _current == i
                            ? Colors.white
                            : Colors.white38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Barra INFERIOR ──────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: FadeTransition(
              opacity: _uiAnim,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.fromLTRB(20, 28, 20, bottomPad + 16),
                child: Row(
                  children: [
                    Expanded(child: _ActionBtn(
                      icon: _isSharing
                          ? Icons.hourglass_top_rounded
                          : Icons.share_rounded,
                      label: 'Compartir',
                      onTap: _isSharing ? null : _share,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionBtn(
                      icon: Icons.folder_open_rounded,
                      label: 'Ubicación',
                      onTap: _showLocation,
                    )),
                  ],
                ),
              ),
            ),
          ),

          // ── Flechas nav lateral ─────────────────────────────────
          if (hasMultiple) ...[
            if (_current > 0)
              Positioned(
                left: 8, top: 0, bottom: 0,
                child: FadeTransition(
                  opacity: _uiAnim,
                  child: Center(child: _NavArrow(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => _pageCtrl.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  )),
                ),
              ),
            if (_current < widget.paths.length - 1)
              Positioned(
                right: 8, top: 0, bottom: 0,
                child: FadeTransition(
                  opacity: _uiAnim,
                  child: Center(child: _NavArrow(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => _pageCtrl.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    ),
                  )),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PÁGINA DE IMAGEN — fondo negro + Clip.hardEdge
// ─────────────────────────────────────────────────────────────
class _ImagePage extends StatelessWidget {
  final String path;
  const _ImagePage({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,            // fondo siempre negro, sin gris
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 6.0,
        // Clip.hardEdge evita que las imágenes de páginas adyacentes
        // se pinen encima al hacer swipe (el bug del "fantasma")
        clipBehavior: Clip.hardEdge,
        child: Center(child: _buildImage()),
      ),
    );
  }

  Widget _buildImage() {
    if (path.startsWith('http')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _Loading(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
          );
        },
        errorBuilder: (ctx, e, st) => const _BrokenImage(),
      );
    }

    final file = File(path);
    if (!file.existsSync()) return const _BrokenImage();

    return Image.file(
      file,
      fit: BoxFit.contain,
      // frameBuilder: mientras decodifica → spinner negro (no gris)
      frameBuilder: (ctx, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded || frame != null) return child;
        return const _Loading();
      },
      errorBuilder: (ctx2, e2, st2) => const _BrokenImage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────

class _Loading extends StatelessWidget {
  final double? value;
  const _Loading({this.value});

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
          value: value,
          color: Colors.white54,
          strokeWidth: 2,
        ),
      ),
    ),
  );
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.broken_image_outlined, color: Colors.white30, size: 64),
      const SizedBox(height: 12),
      Text('No se pudo cargar la imagen',
          style: TextStyle(color: Colors.white30, fontSize: 13)),
    ],
  );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// BOTTOM SHEET — ubicación del archivo
// ─────────────────────────────────────────────────────────────
class _LocationSheet extends StatelessWidget {
  final String filePath;
  final String dir;
  const _LocationSheet({required this.filePath, required this.dir});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Imagen guardada localmente',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A3C5E),
              )),
          const SizedBox(height: 4),
          Text('Carpeta: $dir',
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: isDark ? Colors.white54 : Colors.black45),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Archivo: ${filePath.split('/').last}',
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  color: isDark ? Colors.white54 : Colors.black45),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: filePath));
                Navigator.of(context).pop(true);
              },
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(
                      color: isDark ? Colors.white24 : Colors.black12)),
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Copiar ruta',
                  style: TextStyle(fontFamily: 'Nunito')),
            ),
          ),
        ],
      ),
    );
  }
}
