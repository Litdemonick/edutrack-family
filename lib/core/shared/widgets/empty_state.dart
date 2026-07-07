import 'package:flutter/material.dart';
import 'package:edutrack_family/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// EMPTY STATE — EduTrack Family
// Widget genérico para pantallas vacías con emoji, título y subtítulo.
// ═══════════════════════════════════════════════════════════════

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontSize: 14,
              color: isDark ? Colors.white54 : AppColors.grey,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    // LayoutBuilder + ConstrainedBox(minHeight) en vez de un Center
    // simple: si hay espacio de sobra (caso normal) el contenido
    // queda centrado igual que antes; si la ventana es corta
    // (celular en horizontal, teclado abierto, etc.) se desliza en
    // vez de desbordar — nunca overflow, automático en cualquier alto.
    // Cuando el alto NO está acotado (p. ej. este widget vive dentro
    // de un Sliver/ListView que le da altura infinita a propósito)
    // un minHeight infinito rompe el layout — ahí un Center normal
    // ya es seguro porque el padre scrollea por su cuenta.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Center(child: content);
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
