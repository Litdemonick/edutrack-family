import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// PROFILE CROP SCREEN — EduTrack Family
// Pantalla Flutter pura para recortar foto de perfil en círculo.
// Usa SafeArea para respetar status bar y nav bar en todo Android.
// Adapta colores al tema claro/oscuro de la app.
// ═══════════════════════════════════════════════════════════════

class ProfileCropScreen extends StatefulWidget {
  final String imagePath;
  final String userId;

  const ProfileCropScreen({
    super.key,
    required this.imagePath,
    required this.userId,
  });

  @override
  State<ProfileCropScreen> createState() => _ProfileCropScreenState();
}

class _ProfileCropScreenState extends State<ProfileCropScreen> {
  final _repaintKey = GlobalKey();
  final _controller = TransformationController();
  double _rotationAngle = 0.0;
  bool _saving = false;

  // La imagen arranca con este zoom (no en 1.0): a escala exacta la
  // foto ya llena el círculo (boundaryMargin: cero), así que no hay
  // margen para arrastrarla hasta agrandar. Empezar ya zoomeada
  // garantiza que SIEMPRE se pueda mover con el mouse/dedo desde el
  // principio, sin depender de tocar un botón de zoom primero.
  static const _initialScale = 1.4;
  double _scale = _initialScale;

  Matrix4 _scaleMatrix(double scale) =>
      Matrix4.identity()..scaleByDouble(scale, scale, scale, 1);

  @override
  void initState() {
    super.initState();
    _controller.value = _scaleMatrix(_initialScale);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _rotate() => setState(() => _rotationAngle += pi / 2);

  void _resetView() {
    setState(() {
      _scale = _initialScale;
      _rotationAngle = 0.0;
    });
    _controller.value = _scaleMatrix(_initialScale);
  }

  // Botones de zoom explícitos: en escritorio no hay gesto de
  // pellizcar; con estos (o la rueda del mouse, que InteractiveViewer
  // ya soporta) siempre se puede agrandar más además del zoom inicial.
  void _zoom(double factor) {
    setState(() => _scale = (_scale * factor).clamp(1.0, 6.0));
    _controller.value = _scaleMatrix(_scale);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _saving = false);
        return;
      }

      // Recomprimir a JPEG con el paquete "image" (Dart puro, corre
      // igual en Windows/Linux/Android/iOS sin plugin nativo). El PNG
      // crudo del recorte (pixelRatio 3.0) puede superar los 2MB que
      // exige storage.rules — en Windows/Linux no hay
      // flutter_image_compress para bajarlo después de subir, así
      // que sin este paso la subida quedaba rechazada en silencio.
      final rawPng = byteData.buffer.asUint8List();
      final decoded = img.decodePng(rawPng)!;
      final resized =
          decoded.width > 640 ? img.copyResize(decoded, width: 640) : decoded;
      final jpgBytes = img.encodeJpg(resized, quality: 85);

      final appDir = await getApplicationDocumentsDirectory();
      final profileDir = Directory(p.join(appDir.path, 'profiles'));
      if (!profileDir.existsSync()) profileDir.createSync(recursive: true);

      final destPath =
          p.join(profileDir.path, 'profile_${widget.userId}.jpg');
      await File(destPath).writeAsBytes(jpgBytes);

      if (mounted) Navigator.pop(context, destPath);
    } catch (e) {
      AppLog.d('[ProfileCrop] Error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fondo de la zona de recorte
    final bgColor = isDark ? Colors.black : const Color(0xFFE8ECF0);
    // Borde del círculo guía
    final circleBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : AppColors.navyBlue.withValues(alpha: 0.40);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Toolbar ───────────────────────────────────────────
            _Toolbar(
              saving: _saving,
              onCancel: () => Navigator.pop(context, null),
              onDone: _save,
            ),

            // ── Imagen con overlay circular ───────────────────────
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cropSize =
                      min(constraints.maxWidth, constraints.maxHeight) - 48;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Zona interactiva capturada por RepaintBoundary
                      RepaintBoundary(
                        key: _repaintKey,
                        child: ClipOval(
                          child: SizedBox(
                            width: cropSize,
                            height: cropSize,
                            child: InteractiveViewer(
                              transformationController: _controller,
                              minScale: 1.0,
                              maxScale: 10.0,
                              boundaryMargin: EdgeInsets.zero,
                              child: Transform.rotate(
                                angle: _rotationAngle,
                                child: Image.file(
                                  File(widget.imagePath),
                                  fit: BoxFit.cover,
                                  width: cropSize,
                                  height: cropSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Borde del círculo guía
                      IgnorePointer(
                        child: SizedBox(
                          width: cropSize + 4,
                          height: cropSize + 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: circleBorderColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // ── Barra de controles inferior ───────────────────────
            _BottomControls(
              isDark: isDark,
              onRotate: _rotate,
              onReset: _resetView,
              onZoomIn: () => _zoom(1.25),
              onZoomOut: () => _zoom(0.8),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOOLBAR — siempre navyBlue (color de marca), texto blanco
// ─────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onDone;

  const _Toolbar({
    required this.saving,
    required this.onCancel,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      color: AppColors.navyBlue,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: onCancel,
            tooltip: 'Cancelar',
          ),
          const Expanded(
            child: Text(
              'Ajustar foto de perfil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          saving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.check_rounded,
                      color: AppColors.accentBlue, size: 26),
                  onPressed: onDone,
                  tooltip: 'Guardar',
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BARRA DE CONTROLES INFERIOR — se adapta al tema
// ─────────────────────────────────────────────────────────────

class _BottomControls extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRotate;
  final VoidCallback onReset;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _BottomControls({
    required this.isDark,
    required this.onRotate,
    required this.onReset,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final barColor =
        isDark ? const Color(0xFF111111) : const Color(0xFFDDE2E8);
    final iconColor = isDark ? Colors.white70 : Colors.black87;
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.50);
    final btnBg = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      color: barColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CtrlBtn(
            icon: Icons.rotate_90_degrees_ccw_rounded,
            label: 'Rotar',
            iconColor: iconColor,
            labelColor: labelColor,
            bgColor: btnBg,
            onTap: onRotate,
          ),
          // Botones de zoom explícitos: en escritorio no hay gesto de
          // pellizcar; con estos (o la rueda del mouse) siempre se
          // puede agrandar antes de arrastrar la imagen.
          _CtrlBtn(
            icon: Icons.zoom_out_rounded,
            label: 'Alejar',
            iconColor: iconColor,
            labelColor: labelColor,
            bgColor: btnBg,
            onTap: onZoomOut,
          ),
          _CtrlBtn(
            icon: Icons.zoom_in_rounded,
            label: 'Acercar',
            iconColor: iconColor,
            labelColor: labelColor,
            bgColor: btnBg,
            onTap: onZoomIn,
          ),
          _CtrlBtn(
            icon: Icons.center_focus_strong_rounded,
            label: 'Resetear',
            iconColor: iconColor,
            labelColor: labelColor,
            bgColor: btnBg,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final Color bgColor;
  final VoidCallback onTap;

  const _CtrlBtn({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 11,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
