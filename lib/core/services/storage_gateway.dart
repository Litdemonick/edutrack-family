// ═══════════════════════════════════════════════════════════════
// STORAGE GATEWAY — EduTrack Family 2.0
// Interfaz para las fotos de evidencia/referencia y de perfil, vía
// el Worker de Cloudflare (R2) — ver evidence_image_service.dart. Es
// HTTP normal (TaskImageRemote/ProfilePhotoRemote), así que la misma
// implementación sirve para Android/iOS/Windows/Linux por igual.
// ═══════════════════════════════════════════════════════════════

abstract class StorageGateway {
  /// Sube las imágenes (comprimidas cuando la plataforma lo soporta).
  /// [version] (opcional, solo tiene efecto con kind='evidence'): sube
  /// a una carpeta propia de ESE envío en vez de reemplazar el
  /// anterior — cada reenvío a revisión pasa su propio timestamp
  /// (`completedAt`) para que el Historial de conversación pueda
  /// seguir mostrando las fotos de envíos previos en cualquier
  /// dispositivo. Sin [version] (o con kind='reference'), reemplaza
  /// las previas del mismo [kind] como antes.
  Future<bool> uploadImages({
    required String studentId,
    required String taskId,
    required String kind,
    required List<String> localPaths,
    String? version,
  });

  /// Descarga las imágenes de un tipo (y opcionalmente [version], ver
  /// [uploadImages]) al cache local y devuelve las rutas.
  /// [forceRefresh]: vuelve a bajar y sobrescribir aunque ya exista un
  /// archivo local con ese nombre — relevante solo para descargas SIN
  /// [version] (evidencia/referencia "actual", que si puede cambiar de
  /// contenido bajo el mismo nombre); las descargas versionadas nunca
  /// cambian de contenido, así que no lo necesitan.
  Future<List<String>> downloadImages({
    required String studentId,
    required String taskId,
    required String kind,
    String? version,
    bool forceRefresh = false,
  });

  /// Imágenes ya cacheadas localmente (sin ir a la red).
  Future<List<String>> getLocalPaths(String taskId, String kind, {String? version});

  /// Borra TODAS las fotos de una tarea en R2 — evidencia (todas las
  /// carpetas versionadas, cada envío/reenvío) Y referencia. Se usa
  /// al aprobar/completar una tarea (ya no hace falta el Historial de
  /// idas y vueltas ni la imagen de referencia original) o al
  /// eliminarla, para que el storage remoto no quede con nada huérfano.
  Future<void> deleteAllTaskImages({
    required String studentId,
    required String taskId,
  });

  /// Sube la foto de perfil del usuario, reemplazando la anterior.
  /// Devuelve el `photoUpdatedAt` que puso el servidor (para que el
  /// caller lo guarde localmente y compare sin generar el suyo propio
  /// — el marcado en Firestore ahora lo hace el Worker, no el
  /// cliente), o null si la subida falló.
  Future<String?> uploadProfilePhoto(String uid, String localPath);

  /// Descarga la foto de perfil de [uid] a un archivo en [destPath].
  /// Devuelve true si se descargó (o false si el usuario no tiene
  /// foto subida o la descarga falló).
  Future<bool> downloadProfilePhoto(String uid, String destPath);
}
