import 'package:flutter/widgets.dart';

// ═══════════════════════════════════════════════════════════════
// BREAKPOINTS — EduTrack Family 2.0
// Clases de tamaño Material 3:
//   compact  < 600   (teléfono vertical)
//   medium   600–1023 (teléfono horizontal / tablet chica)
//   expanded ≥ 1024  (tablet horizontal / escritorio)
// ═══════════════════════════════════════════════════════════════

enum WindowSize { compact, medium, expanded }

extension ResponsiveContext on BuildContext {
  WindowSize get windowSize {
    final size = MediaQuery.sizeOf(this);
    final w = size.width;
    // Un teléfono en horizontal tiene ancho de tablet (≥600) pero una
    // altura de teléfono (~350-420) — insuficiente para un sidebar
    // pensado para tablet/escritorio (varios destinos con label).
    // Umbral 480 = "compact height" oficial de Android; por debajo de
    // eso, se queda en compact sin importar el ancho.
    if (size.height < 480) return WindowSize.compact;
    if (w < 600) return WindowSize.compact;
    if (w < 1024) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

  /// Altura de ventana corta (celular en horizontal). Útil para
  /// widgets que se abren/apilan hacia arriba (speed dial, menús) y
  /// necesitan una variante horizontal cuando no hay suficiente alto.
  bool get isShortHeight => MediaQuery.sizeOf(this).height < 480;

  /// Ancho máximo estándar para formularios centrados.
  static const double formMaxWidth = 560;
}

/// Elige un layout distinto según el tamaño de ventana.
/// medium/expanded caen al inmediato inferior si no se especifican.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    switch (context.windowSize) {
      case WindowSize.expanded:
        return (expanded ?? medium ?? compact)(context);
      case WindowSize.medium:
        return (medium ?? compact)(context);
      case WindowSize.compact:
        return compact(context);
    }
  }
}

/// Centra y limita el ancho del contenido (formularios, listas).
class CenteredConstrained extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const CenteredConstrained({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveContext.formMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
