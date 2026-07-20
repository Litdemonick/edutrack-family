import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// STATS CARD — Admin Dashboard
// Chip de estadística con gradiente, marca de agua y barra de
// acento superior. Mismo lenguaje visual que _StatChip del alumno.
// ─────────────────────────────────────────────────────────────

class StatsCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const StatsCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: isDark ? 0.20 : 0.13),
                color.withValues(alpha: isDark ? 0.09 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.24 : 0.20),
            ),
          ),
          child: Stack(
            children: [
              // Barra de acento superior
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.65),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16)),
                  ),
                ),
              ),

              // Icono marca de agua
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(icon, size: 58, color: color.withValues(alpha: 0.09)),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icono pequeño + flecha
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 14, color: color),
                        ),
                        const Spacer(),
                        if (onTap != null)
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 9,
                            color: color.withValues(alpha: 0.50),
                          ),
                      ],
                    ),

                    // Número + etiqueta
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$value',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: color,
                            height: 1,
                          ),
                        ),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Nunito',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color.withValues(alpha: 0.75),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
