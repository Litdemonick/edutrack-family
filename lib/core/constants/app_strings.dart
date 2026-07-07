// ═══════════════════════════════════════════════════════════════
// APP STRINGS — EduTrack Family
// Todos los textos de la UI en un solo lugar.
// Si en el futuro se quiere agregar inglés, se hace aquí.
// ═══════════════════════════════════════════════════════════════

class AppStrings {
  AppStrings._();

  // ─────────────────────────────────────────────────────────────
  // NOMBRE DE LA APP
  // ─────────────────────────────────────────────────────────────
  static const String appName = 'EduTrack Family';
  static const String appTagline = 'Organiza. Aprende. Logra.';
  static const String appVersion = '1.0.1';

  // ─────────────────────────────────────────────────────────────
  // AUTH — PANTALLA DE LOGIN
  // ─────────────────────────────────────────────────────────────
  static const String loginTitle = 'Bienvenido';
  static const String loginSubtitle = 'Selecciona tu cuenta para continuar';
  static const String loginUsername = 'Usuario';
  static const String loginUsernameHint = 'Escribe tu usuario';
  static const String loginPassword = 'Contraseña';
  static const String loginPasswordHint = 'Escribe tu contraseña';
  static const String loginButton = 'Iniciar sesión';
  static const String loginLoading = 'Entrando...';
  static const String loginError = 'Usuario o contraseña incorrectos';
  static const String loginSelectAccount = 'O selecciona una cuenta:';

  // ─────────────────────────────────────────────────────────────
  // ROLES
  // ─────────────────────────────────────────────────────────────
  static const String roleAdmin = 'Administrador';
  static const String roleStudent = 'Estudiante';
  static const String adminWelcome = 'Panel de Control';
  static const String studentWelcome = '¡Hola'; // se concatena el nombre

  // ─────────────────────────────────────────────────────────────
  // NAVEGACIÓN INFERIOR — ESTUDIANTE
  // ─────────────────────────────────────────────────────────────
  static const String navHome = 'Inicio';
  static const String navCalendar = 'Calendario';
  static const String navSchedule = 'Horario';
  static const String navHistory = 'Historial';

  // ─────────────────────────────────────────────────────────────
  // NAVEGACIÓN INFERIOR — ADMIN
  // ─────────────────────────────────────────────────────────────
  static const String navDashboard = 'Panel';
  static const String navTasks = 'Tareas';
  static const String navEvents = 'Eventos';
  static const String navReport = 'Reporte';

  // ─────────────────────────────────────────────────────────────
  // DASHBOARD ESTUDIANTE
  // ─────────────────────────────────────────────────────────────
  static const String dashboardToday = 'Hoy';
  static const String dashboardUpcoming = 'Próximamente';
  static const String dashboardPending = 'Pendientes';
  static const String dashboardCompleted = 'Completadas';
  static const String dashboardNoTasks = 'No tienes tareas pendientes 🎉';
  static const String dashboardNoTasksSubtitle =
      'Estás al día con todo. ¡Buen trabajo!';
  static const String dashboardFirstTask = '¡Empieza con esta!';

  // ─────────────────────────────────────────────────────────────
  // DASHBOARD ADMIN
  // ─────────────────────────────────────────────────────────────
  static const String adminOverview = 'Resumen';
  static const String adminPendingAlert = 'Tareas sin hacer';
  static const String adminNoPending = 'Todo al día ✓';
  static const String adminAddTask = 'Agregar tarea';
  static const String adminAddEvent = 'Agregar evento';
  static const String adminViewAll = 'Ver todo';
  static const String adminEvidenceTitle = 'Evidencias entregadas';
  static const String adminNoEvidence = 'Aún no hay evidencias';

  // ─────────────────────────────────────────────────────────────
  // TAREAS
  // ─────────────────────────────────────────────────────────────
  static const String taskTitle = 'Título de la tarea';
  static const String taskTitleHint = 'Ej: Ejercicio de matemáticas';
  static const String taskSubject = 'Materia';
  static const String taskSubjectHint = 'Ej: Matemáticas';
  static const String taskDescription = 'Descripción (opcional)';
  static const String taskDescriptionHint = 'Detalles adicionales...';
  static const String taskCategory = 'Categoría';
  static const String taskDueDate = 'Fecha de entrega';
  static const String taskDueTime = 'Hora límite (opcional)';
  static const String taskPriority = 'Prioridad';
  static const String taskCreate = 'Crear tarea';
  static const String taskEdit = 'Editar tarea';
  static const String taskDelete = 'Eliminar tarea';
  static const String taskDeleteConfirm =
      '¿Estás seguro de que quieres eliminar esta tarea?';
  static const String taskDeleteConfirmSub =
      'Esta acción no se puede deshacer. La tarea se moverá al historial.';
  static const String taskMarkDone = 'Marcar como hecha';
  static const String taskMarkDoneBtn = '✓ Hecha';
  static const String taskTakePhoto = 'Tomar foto de evidencia';
  static const String taskPhotoSaved = 'Evidencia guardada ✓';
  static const String taskSaved = 'Tarea guardada';
  static const String taskUpdated = 'Tarea actualizada';
  static const String taskDeleted = 'Tarea eliminada';

  // ─────────────────────────────────────────────────────────────
  // CATEGORÍAS DE TAREAS
  // ─────────────────────────────────────────────────────────────
  static const String catTarea = 'Tarea';
  static const String catExamen = 'Examen';
  static const String catEjercicio = 'Ejercicio';
  static const String catParcial = 'Parcial';
  static const String catProyecto = 'Proyecto';
  static const String catReunion = 'Reunión';
  static const String catEvento = 'Evento';

  static const List<String> allCategories = [
    catTarea,
    catEjercicio,
    catParcial,
    catExamen,
    catProyecto,
    catReunion,
    catEvento,
  ];

  // ─────────────────────────────────────────────────────────────
  // ESTADOS DE TAREA
  // ─────────────────────────────────────────────────────────────
  static const String statusPending = 'Pendiente';
  static const String statusDone = 'Completada';
  static const String statusOverdue = 'Vencida';
  static const String statusUrgent = 'Urgente';

  // ─────────────────────────────────────────────────────────────
  // FECHAS Y TIEMPOS
  // ─────────────────────────────────────────────────────────────
  static const String dueToday = 'Vence hoy';
  static const String dueTomorrow = 'Vence mañana';
  static const String dueYesterday = 'Venció ayer';
  static const String dueOverdue = 'Vencida';
  static const String dueIn = 'En '; // se concatena "X días"
  static const String days = ' días';
  static const String day = ' día';

  static String daysLeftLabel(int days) {
    if (days < 0) {
      return 'Vencida hace ${days.abs()} día${days.abs() == 1 ? "" : "s"}';
    }
    if (days == 0) return dueToday;
    if (days == 1) return dueTomorrow;
    return '$dueIn$days${AppStrings.days}';
  }

  // ─────────────────────────────────────────────────────────────
  // HORARIO DE CLASES
  // ─────────────────────────────────────────────────────────────
  static const String scheduleTitle = 'Mi Horario';
  static const String scheduleEmpty = 'No hay clases este día';
  static const String scheduleSubject = 'Materia';
  static const String scheduleRoom = 'Salón';
  static const String scheduleTeacher = 'Profesor';
  static const String scheduleTime = 'Horario';

  // Días de la semana en español (índices 0-6 = Lun-Dom; weekday-1)
  static const List<String> weekDays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  static const List<String> weekDaysShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  // Meses en español
  static const List<String> months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static const List<String> monthsShort = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  // ─────────────────────────────────────────────────────────────
  // CALENDARIO
  // ─────────────────────────────────────────────────────────────
  static const String calendarTitle = 'Calendario';
  static const String calendarNoEvents = 'Sin tareas este día';
  static const String calendarTodayBtn = 'Hoy';

  // ─────────────────────────────────────────────────────────────
  // HISTORIAL
  // ─────────────────────────────────────────────────────────────
  static const String historyTitle = 'Historial';
  static const String historyEmpty = 'El historial está vacío';
  static const String historyEmptySub =
      'Las tareas completadas o eliminadas aparecerán aquí';
  static const String historyClearAll = 'Limpiar historial';
  static const String historyClearConfirm = '¿Limpiar todo el historial?';
  static const String historyClearConfirmSub =
      'Se eliminarán permanentemente todas las tareas del historial. '
      'Esta acción no se puede deshacer.';
  static const String historyCleared = 'Historial limpiado';
  static const String historyAutoClean = 'Limpieza automática: cada 30 días';

  // ─────────────────────────────────────────────────────────────
  // NOTIFICACIONES
  // ─────────────────────────────────────────────────────────────
  static const String notifTaskDue = '⚠ Tarea próxima a vencer';
  static const String notifTaskOverdue = '🔴 ¡Tarea vencida!';
  static String notifTaskNotDone(String linkedPersonWord) =>
      '📌 Tu $linkedPersonWord no ha completado una tarea';
  static const String notifReminderTitle = '📚 Recordatorio EduTrack';

  static String notifTaskDueBody(String taskName, int daysLeft) {
    if (daysLeft == 0) return '"$taskName" vence hoy';
    if (daysLeft == 1) return '"$taskName" vence mañana';
    return '"$taskName" vence en $daysLeft días';
  }

  static String notifTaskNotDoneBody(String taskName) =>
      'La tarea "$taskName" está pendiente y próxima a vencer';

  // ─────────────────────────────────────────────────────────────
  // CONECTIVIDAD
  // ─────────────────────────────────────────────────────────────
  static const String offlineBanner = 'Sin conexión — modo offline';
  static const String onlineBanner = 'Conexión restaurada ✓';
  static const String syncingData = 'Sincronizando datos...';
  static const String syncDone = 'Datos sincronizados ✓';

  // ─────────────────────────────────────────────────────────────
  // BOTONES COMUNES
  // ─────────────────────────────────────────────────────────────
  static const String btnSave = 'Guardar';
  static const String btnCancel = 'Cancelar';
  static const String btnDelete = 'Eliminar';
  static const String btnEdit = 'Editar';
  static const String btnClose = 'Cerrar';
  static const String btnConfirm = 'Confirmar';
  static const String btnBack = 'Volver';
  static const String btnAdd = 'Agregar';
  static const String btnCreate = 'Crear';
  static const String btnLogout = 'Cerrar sesión';
  static const String btnLogoutConfirm = '¿Cerrar sesión?';
  static const String btnLogoutConfirmSub =
      'Tendrás que volver a iniciar sesión para entrar.';
  static const String btnYes = 'Sí';
  static const String btnNo = 'No';
  static const String btnRetry = 'Reintentar';

  // ─────────────────────────────────────────────────────────────
  // ERRORES Y VALIDACIONES
  // ─────────────────────────────────────────────────────────────
  static const String errorRequired = 'Este campo es obligatorio';
  static const String errorMinLength = 'Demasiado corto';
  static const String errorInvalidDate = 'Fecha inválida';
  static const String errorPastDate =
      'La fecha de entrega no puede ser en el pasado';
  static const String errorGeneric = 'Algo salió mal. Intenta de nuevo.';
  static const String errorNoPermission = 'Se necesita permiso para continuar';
  static const String errorCameraPermission =
      'Se necesita acceso a la cámara para tomar la foto de evidencia';
  static const String errorStoragePermission =
      'Se necesita acceso al almacenamiento';

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATES (pantallas vacías)
  // ─────────────────────────────────────────────────────────────
  static const String emptyTasksTitle = 'Sin tareas';
  static const String emptyTasksSub =
      'No hay tareas pendientes.\nAgrega una nueva desde el panel de Admin.';
  static const String emptyCalendarTitle = 'Sin eventos';
  static const String emptyCalendarSub =
      'No hay eventos en el calendario todavía.';
  static const String emptyHistoryTitle = 'Historial vacío';
  static const String emptyHistorySub =
      'Las tareas completadas y eliminadas aparecerán aquí.';
  static const String emptyEvidenceTitle = 'Sin evidencias';
  static const String emptyEvidenceSub =
      'Todavía no se han enviado fotos de evidencia.';

  // ─────────────────────────────────────────────────────────────
  // EVIDENCIA / FOTOS
  // ─────────────────────────────────────────────────────────────
  static const String evidenceTitle = 'Foto de evidencia';
  static const String evidenceInstructions =
      'Toma una foto de la tarea completada para registrar que la hiciste.';
  static const String evidenceTakePhoto = '📷 Tomar foto';
  static const String evidenceChooseGallery = '🖼 Elegir de galería';
  static const String evidenceRetake = 'Tomar otra foto';
  static const String evidenceSave = 'Guardar evidencia';
  static const String evidenceSaved = '¡Evidencia guardada! ✓';
  static const String evidenceViewTitle = 'Evidencias entregadas';
  static const String evidenceCompletedOn = 'Completada el';

  // ─────────────────────────────────────────────────────────────
  // MATERIAS (se pueden personalizar más adelante)
  // ─────────────────────────────────────────────────────────────
  static const List<String> subjects = [
    'Matemáticas',
    'Español',
    'Ciencias Naturales',
    'Ciencias Sociales',
    'Inglés',
    'Educación Física',
    'Arte',
    'Religión',
    'Computación',
    'Otra',
  ];
}
