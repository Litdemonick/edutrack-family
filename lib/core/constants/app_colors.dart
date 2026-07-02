import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// APP COLORS — EduTrack Family
// Todos los colores de la app en un solo lugar.
// Importa este archivo donde necesites colores.
// ═══════════════════════════════════════════════════════════════

class AppColors {
  AppColors._();

  // ─────────────────────────────────────────────────────────────
  // COLORES PRIMARIOS DE MARCA
  // ─────────────────────────────────────────────────────────────

  /// Azul marino oscuro — color principal de la app, AppBar, botones
  static const Color navyBlue = Color(0xFF0F2744);

  /// Azul royal — variante más clara del primario, fondos de sección
  static const Color royalBlue = Color(0xFF1A3C5E);

  /// Azul acento — botones secundarios, links, FAB
  static const Color accentBlue = Color(0xFF2196F3);

  /// Azul cielo — fondos de chips, badges, highlights suaves
  static const Color skyBlue = Color(0xFF64B5F6);

  /// Azul muy claro — fondos de tarjetas de información
  static const Color lightBlue = Color(0xFFE3F2FD);

  // ─────────────────────────────────────────────────────────────
  // SISTEMA SEMÁFORO DE TAREAS
  // Verde = hecha, Amarillo = próxima a vencer, Rojo = urgente/vencida
  // ─────────────────────────────────────────────────────────────

  /// Verde — tarea completada ✓
  static const Color statusGreen = Color(0xFF4CAF50);

  /// Verde claro — fondo de badge completado
  static const Color statusGreenLight = Color(0xFFE8F5E9);

  /// Ámbar — tarea próxima a vencer (≤ 2 días) ⚠
  static const Color statusAmber = Color(0xFFFFC107);

  /// Ámbar claro — fondo de badge advertencia
  static const Color statusAmberLight = Color(0xFFFFF8E1);

  /// Rojo — tarea que vence hoy o ya venció ✗
  static const Color statusRed = Color(0xFFF44336);

  /// Rojo claro — fondo de badge urgente
  static const Color statusRedLight = Color(0xFFFFEBEE);

  // ─────────────────────────────────────────────────────────────
  // CATEGORÍAS DE TAREAS / EVENTOS
  // Cada tipo tiene su color principal y su versión claro (fondo)
  // ─────────────────────────────────────────────────────────────

  /// Tarea regular — azul
  static const Color categoryTask = Color(0xFF2196F3);
  static const Color categoryTaskLight = Color(0xFFE3F2FD);

  /// Examen — rojo
  static const Color categoryExam = Color(0xFFF44336);
  static const Color categoryExamLight = Color(0xFFFFEBEE);

  /// Ejercicio / Quiz / Parcial — naranja
  static const Color categoryQuiz = Color(0xFFFF9800);
  static const Color categoryQuizLight = Color(0xFFFFF3E0);

  /// Reunión de padres — morado
  static const Color categoryMeeting = Color(0xFF9C27B0);
  static const Color categoryMeetingLight = Color(0xFFF3E5F5);

  /// Evento especial — teal/verde azulado
  static const Color categoryEvent = Color(0xFF009688);
  static const Color categoryEventLight = Color(0xFFE0F2F1);

  /// Proyecto — índigo
  static const Color categoryProject = Color(0xFF3F51B5);
  static const Color categoryProjectLight = Color(0xFFE8EAF6);

  // ─────────────────────────────────────────────────────────────
  // COLORES NEUTROS
  // ─────────────────────────────────────────────────────────────

  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF5F7FA);
  static const Color lightGrey = Color(0xFFE8ECF0);
  static const Color mediumGrey = Color(0xFFCFD8DC);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  static const Color charcoal = Color(0xFF263238);
  static const Color black = Color(0xFF0D0D0D);

  // ─────────────────────────────────────────────────────────────
  // SUPERFICIES Y FONDOS
  // ─────────────────────────────────────────────────────────────

  /// Fondo blanco puro para cards y modals
  static const Color surface = Color(0xFFFFFFFF);

  /// Fondo ligeramente grisáceo para variantes de card
  static const Color surfaceVariant = Color(0xFFF0F4F8);

  /// Fondo de la pantalla principal
  static const Color background = Color(0xFFF5F7FA);

  /// Fondo del header / banner de Admin
  static const Color adminBanner = Color(0xFF0F2744);

  /// Fondo del header / banner de Estudiante
  static const Color studentBanner = Color(0xFF1565C0);

  // ─────────────────────────────────────────────────────────────
  // SOMBRAS
  // ─────────────────────────────────────────────────────────────

  /// Sombra suave para cards (10% opacidad)
  static const Color shadowLight = Color(0x1A000000);

  /// Sombra media para cards elevadas (20% opacidad)
  static const Color shadowMedium = Color(0x33000000);

  /// Sombra del FAB y elementos flotantes (30% opacidad)
  static const Color shadowStrong = Color(0x4D000000);

  // ─────────────────────────────────────────────────────────────
  // COLORES DE ERROR / ÉXITO / INFO / ADVERTENCIA
  // ─────────────────────────────────────────────────────────────

  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);

  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);

  static const Color warning = Color(0xFFFFC107);
  static const Color warningLight = Color(0xFFFFF8E1);

  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─────────────────────────────────────────────────────────────
  // GRADIENTES PREDEFINIDOS
  // Úsalos con BoxDecoration(gradient: AppColors.gradientNavy)
  // ─────────────────────────────────────────────────────────────

  /// Gradiente azul marino — fondos de AppBar extendida, splash
  static const LinearGradient gradientNavy = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2744), Color(0xFF1A3C5E)],
  );

  /// Gradiente azul brillante — banners, headers de sección
  static const LinearGradient gradientBlue = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1565C0), Color(0xFF2196F3)],
  );

  /// Gradiente verde — tarjeta de tarea completada
  static const LinearGradient gradientGreen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF388E3C), Color(0xFF4CAF50)],
  );

  /// Gradiente rojo — tarjeta de tarea urgente
  static const LinearGradient gradientRed = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC62828), Color(0xFFF44336)],
  );

  /// Gradiente ámbar — tarjeta de tarea próxima a vencer
  static const LinearGradient gradientAmber = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8F00), Color(0xFFFFC107)],
  );

  // ─────────────────────────────────────────────────────────────
  // HELPERS — obtener color por categoría
  // ─────────────────────────────────────────────────────────────

  /// Retorna el color principal de una categoría de tarea
  static Color forCategory(String category) {
    switch (category.toLowerCase()) {
      case 'tarea':
        return categoryTask;
      case 'examen':
        return categoryExam;
      case 'ejercicio':
      case 'quiz':
      case 'parcial':
        return categoryQuiz;
      case 'reunion':
      case 'reunión':
        return categoryMeeting;
      case 'evento':
        return categoryEvent;
      case 'proyecto':
        return categoryProject;
      default:
        return categoryTask;
    }
  }

  /// Retorna el color de fondo (claro) de una categoría
  static Color forCategoryLight(String category) {
    switch (category.toLowerCase()) {
      case 'tarea':
        return categoryTaskLight;
      case 'examen':
        return categoryExamLight;
      case 'ejercicio':
      case 'quiz':
      case 'parcial':
        return categoryQuizLight;
      case 'reunion':
      case 'reunión':
        return categoryMeetingLight;
      case 'evento':
        return categoryEventLight;
      case 'proyecto':
        return categoryProjectLight;
      default:
        return categoryTaskLight;
    }
  }

  /// Retorna el color del semáforo según días restantes.
  /// [isOverdue] = true cuando el datetime exacto ya pasó (urgente real).
  /// [daysLeft] < 0 = venció en un día anterior (siempre rojo).
  /// [daysLeft] == 0 sin isOverdue = vence hoy, hora no pasada (ámbar).
  static Color forDaysLeft(int daysLeft, {bool isCompleted = false, bool isOverdue = false}) {
    if (isCompleted) return statusGreen;
    if (isOverdue || daysLeft < 0) return statusRed;
    if (daysLeft <= 2) return statusAmber;
    return statusGreen;
  }

  /// Retorna el color de fondo del semáforo según días restantes.
  static Color forDaysLeftLight(int daysLeft, {bool isCompleted = false, bool isOverdue = false}) {
    if (isCompleted) return statusGreenLight;
    if (isOverdue || daysLeft < 0) return statusRedLight;
    if (daysLeft <= 2) return statusAmberLight;
    return statusGreenLight;
  }
}
