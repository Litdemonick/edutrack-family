// ═══════════════════════════════════════════════════════════════
// FIRESTORE PATHS — EduTrack Family 2.0
// Única fuente de verdad de las rutas de colecciones/documentos.
// NUNCA escribas rutas de Firestore a mano fuera de este archivo.
//
// Modelo multi-tenant: todo lo de un estudiante vive bajo
// students/{studentId}/... — un solo get() del doc padre autoriza
// el subárbol completo en las reglas de seguridad.
// ═══════════════════════════════════════════════════════════════

class FirestorePaths {
  FirestorePaths._();

  // ── Usuarios (adultos y estudiantes) ────────────────────────
  static const String users = 'users';
  static String user(String uid) => 'users/$uid';
  static String userDevices(String uid) => 'users/$uid/devices';
  static String userDevice(String uid, String installId) =>
      'users/$uid/devices/$installId';

  // ── Estudiantes (subárbol multi-tenant) ─────────────────────
  static const String students = 'students';
  static String student(String studentId) => 'students/$studentId';

  static String tasks(String studentId) => 'students/$studentId/tasks';
  static String task(String studentId, String taskId) =>
      'students/$studentId/tasks/$taskId';

  static String events(String studentId) => 'students/$studentId/events';
  static String event(String studentId, String eventId) =>
      'students/$studentId/events/$eventId';

  static String scheduleBlocks(String studentId) =>
      'students/$studentId/scheduleBlocks';
  static String scheduleBlock(String studentId, String blockId) =>
      'students/$studentId/scheduleBlocks/$blockId';

  static String evidences(String studentId) =>
      'students/$studentId/evidences';
  static String evidence(String studentId, String evidenceId) =>
      'students/$studentId/evidences/$evidenceId';

  // ── Ubicación ────────────────────────────────────────────────
  static String locationCurrent(String studentId) =>
      'students/$studentId/locations/current';
  static String locationHistory(String studentId) =>
      'students/$studentId/locations/history/points';
  static String locationConsent(String studentId) =>
      'students/$studentId/locations/consent';
  // Última entrada/salida de zona conocida por estudiante (no por
  // dispositivo) — permite que un segundo celular con la misma
  // cuenta arranque sabiendo en qué zonas ya estaba, en vez de
  // duplicar el aviso de "entró/salió" que el otro celular ya mandó.
  static String locationZoneState(String studentId) =>
      'students/$studentId/locations/zoneState';

  static String zones(String studentId) => 'students/$studentId/zones';
  static String zone(String studentId, String zoneId) =>
      'students/$studentId/zones/$zoneId';
  static String zoneEvents(String studentId) =>
      'students/$studentId/zoneEvents';

  // ── Check-in "¿Estás bien?" ─────────────────────────────────
  static String wellnessChecks(String studentId) =>
      'students/$studentId/wellnessChecks';
  static String wellnessCheck(String studentId, String checkId) =>
      'students/$studentId/wellnessChecks/$checkId';

  // ── Alerta sísmica (bitácora por estudiante, la escribe el Worker
  // cada vez que manda push por un sismo) ─────────────────────
  static String seismicAlertLogCollection(String studentId) =>
      'students/$studentId/seismicAlertsLog';
  static String seismicAlertLog(String studentId, String quakeId) =>
      'students/$studentId/seismicAlertsLog/$quakeId';

  // ── Globales ────────────────────────────────────────────────
  static const String linkCodes = 'linkCodes';
  static String linkCode(String code) => 'linkCodes/$code';

  static const String pushQueue = 'push_queue';
  static const String seismicEvents = 'seismicEvents';

  // ── Storage (Firebase Storage, no Firestore) ────────────────
  static String evidenceStoragePath(
          String studentId, String taskId, String fileName) =>
      'evidence/$studentId/$taskId/$fileName';
  static String referenceStoragePath(
          String studentId, String taskId, String fileName) =>
      'reference/$studentId/$taskId/$fileName';
}
