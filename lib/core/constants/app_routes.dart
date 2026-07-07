// ═══════════════════════════════════════════════════════════════
// APP ROUTES — EduTrack Family
// Todas las rutas de go_router en un solo lugar.
// ═══════════════════════════════════════════════════════════════

class AppRoutes {
  AppRoutes._();

  // ─────────────────────────────────────────────────────────────
  // RUTAS RAÍZ
  // ─────────────────────────────────────────────────────────────

  /// Splash screen — pantalla de carga inicial
  static const String splash = '/';

  /// Login — pantalla de inicio de sesión
  static const String login = '/login';

  // ─────────────────────────────────────────────────────────────
  // AUTENTICACIÓN 2.0
  // ─────────────────────────────────────────────────────────────

  /// Registro de adulto (padre/tutor o profesor)
  static const String register = '/register';

  /// Verificación de email (bloqueante hasta confirmar)
  static const String verifyEmail = '/verify-email';

  /// Completar perfil (primer login con Google: rol + edad)
  static const String completeProfile = '/complete-profile';

  /// Recuperar contraseña
  static const String forgotPassword = '/forgot-password';

  /// Entrada de estudiante con código de vinculación
  static const String studentCode = '/student-code';

  /// Gate biométrico (huella/Face ID) con sesión viva
  static const String biometricGate = '/biometric-gate';

  /// Configuración OBLIGATORIA de huella/Windows Hello (una sola vez,
  /// tras verificar el correo o completar el perfil) para padres/
  /// profesores — luego se puede desactivar desde Ajustes.
  static const String biometricSetup = '/biometric-setup';

  /// Gestión de familia: hijos, códigos, vínculos
  static const String family = '/family';

  /// Mapa de ubicación del hijo (padres)
  static const String locationMap = '/location-map';

  // ─────────────────────────────────────────────────────────────
  // RUTAS DEL ESTUDIANTE (el estudiante)
  // ─────────────────────────────────────────────────────────────

  /// Home del estudiante — dashboard principal
  static const String student = '/student';

  /// Calendario del estudiante
  static const String studentCalendar = '/student/calendar';

  /// Horario de clases del estudiante
  static const String studentSchedule = '/student/schedule';

  /// Historial de tareas del estudiante
  static const String studentHistory = '/student/history';

  /// Detalle de una tarea (estudiante)
  /// Parámetro: :taskId
  static const String studentTaskDetail = '/student/task/:taskId';

  /// Pantalla para completar tarea + tomar foto
  /// Parámetro: :taskId
  static const String studentCompleteTask = '/student/task/:taskId/complete';

  // ─────────────────────────────────────────────────────────────
  // RUTAS DEL ADMINISTRADOR
  // ─────────────────────────────────────────────────────────────

  /// Home del admin — panel de control
  static const String admin = '/admin';

  /// Lista completa de tareas (admin)
  static const String adminTasks = '/admin/tasks';

  /// Crear nueva tarea (admin)
  static const String adminCreateTask = '/admin/tasks/new';

  /// Editar tarea existente (admin)
  /// Parámetro: :taskId
  static const String adminEditTask = '/admin/tasks/:taskId/edit';

  /// Lista de eventos (admin)
  static const String adminEvents = '/admin/events';

  /// Crear nuevo evento (admin)
  static const String adminCreateEvent = '/admin/events/new';

  /// Editar evento existente (admin)
  /// Parámetro: :eventId
  static const String adminEditEvent = '/admin/events/:eventId/edit';

  /// Ver historial completo (admin)
  static const String adminHistory = '/admin/history';

  /// Ver evidencias de el estudiante (admin)
  static const String adminEvidence = '/admin/evidence';

  /// Ver evidencia específica de una tarea (admin)
  /// Parámetro: :taskId
  static const String adminTaskEvidence = '/admin/evidence/:taskId';

  /// Reporte / estadísticas de el estudiante (admin)
  static const String adminReport = '/admin/report';

  // ─────────────────────────────────────────────────────────────
  // CONFIGURACIÓN (compartida entre roles)
  // ─────────────────────────────────────────────────────────────

  /// Pantalla de configuración y ajustes
  static const String settings = '/settings';

  /// Pantalla de permisos — bloqueante al primer arranque
  static const String permissions = '/permissions';

  /// Historial de notificaciones internas
  static const String notifications = '/notifications';

  // ─────────────────────────────────────────────────────────────
  // HELPERS — construir rutas con parámetros
  // ─────────────────────────────────────────────────────────────

  /// Construye la ruta de detalle de tarea para el estudiante
  static String studentTaskDetailPath(String taskId) => '/student/task/$taskId';

  /// Construye la ruta para completar una tarea
  static String studentCompleteTaskPath(String taskId) =>
      '/student/task/$taskId/complete';

  /// Construye la ruta para editar una tarea (admin)
  static String adminEditTaskPath(String taskId) => '/admin/tasks/$taskId/edit';

  /// Construye la ruta para editar un evento (admin)
  static String adminEditEventPath(String eventId) =>
      '/admin/events/$eventId/edit';

  /// Construye la ruta para ver evidencia de una tarea (admin)
  static String adminTaskEvidencePath(String taskId) =>
      '/admin/evidence/$taskId';

  // ─────────────────────────────────────────────────────────────
  // VISTAS DE DETALLE (compartidas admin + estudiante)
  // ─────────────────────────────────────────────────────────────

  /// Vista completa de tarea (solo lectura/visualizar)
  static const String taskView = '/task-view';

  /// Vista completa de evento (solo lectura/visualizar)
  static const String eventView = '/event-view';
}
