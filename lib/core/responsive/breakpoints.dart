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
  double get _width => MediaQuery.sizeOf(this).width;

  WindowSize get windowSize {
    final w = _width;
    if (w < 600) return WindowSize.compact;
    if (w < 1024) return WindowSize.medium;
    return WindowSize.expanded;
  }

  bool get isCompact => windowSize == WindowSize.compact;
  bool get isMedium => windowSize == WindowSize.medium;
  bool get isExpanded => windowSize == WindowSize.expanded;

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
