import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO DE CÓDIGO DE VINCULACIÓN — muestra el código en grande,
// permite copiarlo o compartirlo. Devuelve true si pidió compartir.
// ═══════════════════════════════════════════════════════════════

Future<bool?> showLinkCodeDialog(
  BuildContext context, {
  required String code,
  required String studentName,
  required bool isTeacherCode,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isTeacherCode ? 'Código para profesor/a' : 'Código de vinculación',
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isTeacherCode
                ? 'Compártelo con el/la profesor/a de $studentName. '
                    'Lo canjea desde su app en "Mis estudiantes".'
                : 'Escríbelo en el celular de $studentName al abrir la app '
                    'y tocar "Soy estudiante".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Código copiado ✓')),
              );
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.accentBlue.withValues(alpha: 0.4)),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  fontFamily: 'Poppins',
                  color: AppColors.navyBlue,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Vence en 24 horas · un solo uso',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.pop(ctx, false);
          },
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('Copiar'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Compartir'),
        ),
      ],
    ),
  );
}
