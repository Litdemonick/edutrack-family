import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';

// ═══════════════════════════════════════════════════════════════
// DIÁLOGO DE CÓDIGO DE VINCULACIÓN — el código queda OCULTO por
// defecto (por si alguien más está mirando la pantalla) — un botón
// de ojo lo revela, y "Copiar" siempre copia el código real sin
// necesidad de mostrarlo primero. Devuelve true si pidió compartir.
// ═══════════════════════════════════════════════════════════════

Future<bool?> showLinkCodeDialog(
  BuildContext context, {
  required String code,
  required String studentName,
  required bool isTeacherCode,
  bool permanent = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final codeTextColor = isDark ? Colors.white : AppColors.navyBlue;
      final descColor = isDark ? Colors.white70 : Colors.grey.shade700;
      final hintColor = isDark ? Colors.white54 : Colors.grey.shade600;

      // Vive en el closure del builder externo (corre una sola vez
      // por diálogo) — así persiste entre los rebuilds internos del
      // StatefulBuilder, sin necesitar un StatefulWidget aparte.
      var visible = false;

      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
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
                  style: TextStyle(fontSize: 14, color: descColor),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => setState(() => visible = !visible),
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withValues(alpha: isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.accentBlue.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              visible ? code : '•' * code.length,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 4,
                                fontFamily: 'Poppins',
                                color: codeTextColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: codeTextColor.withValues(alpha: 0.7),
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  visible
                      ? 'Toca para ocultarlo de nuevo'
                      : 'Oculto por seguridad — toca para verlo',
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
                const SizedBox(height: 4),
                Text(
                  permanent
                      ? 'Ya canjeado — sigue sirviendo para volver a entrar '
                          'hasta que lo regeneres'
                      : 'Vence en 24 horas si no se usa · luego sigue '
                          'sirviendo hasta que lo regeneres',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: hintColor),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  // La confirmación se muestra en el llamador (ver
                  // showLinkCodeDialog en family_screen.dart) DESPUÉS
                  // de cerrar este diálogo — mostrarla desde acá
                  // quedaba oculta detrás (mismo problema que la hoja
                  // del horario: el Scaffold real está debajo del
                  // modal, no encima).
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
          );
        },
      );
    },
  );
}
