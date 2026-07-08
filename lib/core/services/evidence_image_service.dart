import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/platform_caps.dart';
import 'profile_photo_remote.dart';
import 'storage_gateway.dart';
import 'task_image_remote.dart';
import '../utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// EVIDENCE IMAGE SERVICE — EduTrack Family 2.0
// Fotos de evidencia/referencia vía el Worker de Cloudflare (R2), no
// Firebase Storage (nunca se activó en la consola del proyecto —
// las subidas fallaban en silencio y las imágenes solo quedaban en
// el dispositivo que las tomó, nunca llegaban a los demás).
//
// 'reference' (imágenes de referencia del padre/tutor/profesor):
// un solo objeto en R2, reference/{studentId}/{taskId}/reference_N.jpg
// — se borran las previas antes de subir las nuevas (el admin las
// edita in-place, no hace falta historial de versiones).
//
// 'evidence' (fotos que sube el estudiante): CADA envío a revisión
// sube a su PROPIA carpeta versionada (usa completedAt como
// [version]) — evidence/{studentId}/{taskId}/{version}/evidence_N.jpg
// — nunca se borra. Antes se sobrescribía siempre el mismo archivo,
// así que el Historial de conversación no podía mostrar las fotos de
// envíos previos en ningún dispositivo que no fuera el que las tomó
// (el archivo remoto ya no existía tras el siguiente reenvío). Las
// llamadas SIN [version] (usadas para "la entrega actual") siguen
// yendo a la carpeta plana de siempre, sin versión, por compatibilidad.
//
// Cache local: <docs>/EduTrack/images/<taskId>/[<version>/]<kind>_N.jpg
//
// Android/iOS Y Windows/Linux usan exactamente el mismo código (a
// diferencia de antes, que necesitaba SDK nativo vs REST porque
// firebase_storage no existe en desktop) — todo es HTTP normal ahora.
// ═══════════════════════════════════════════════════════════════

class EvidenceImageService implements StorageGateway {
  EvidenceImageService._();
  static final StorageGateway instance = EvidenceImageService._();

  static const int _maxBytes = 300 * 1024; // ≤300 KB por foto

  // ─────────────────────────────────────────────────────────────
  // SUBIDA
  // ─────────────────────────────────────────────────────────────

  /// Comprime (si el dispositivo lo soporta) y sube las imágenes.
  /// [kind]: 'evidence' | 'reference'. [version]: ver comentario de
  /// cabecera — sin ella, reemplaza las previas del mismo [kind]
  /// (comportamiento de siempre); con ella, sube a su propia carpeta
  /// sin tocar envíos anteriores.
  @override
  Future<bool> uploadImages({
    required String studentId,
    required String taskId,
    required String kind,
    required List<String> localPaths,
    String? version,
  }) async {
    if (studentId.isEmpty || localPaths.isEmpty) return false;
    try {
      // Re-subida limpia solo quando NO hay versión (evidencia
      // versionada nunca pisa envíos anteriores, no hay nada que
      // borrar).
      if (version == null) {
        await _deleteAll(studentId, taskId, kind);
      }

      var uploaded = 0;
      for (var i = 0; i < localPaths.length; i++) {
        final bytes = await _compress(localPaths[i]);
        if (bytes == null) continue;

        final ok = await TaskImageRemote.instance.upload(
          studentId: studentId,
          taskId: taskId,
          kind: kind,
          name: '${kind}_$i.jpg',
          bytes: bytes,
          version: version,
        );
        if (ok) uploaded++;
      }
      AppLog.d('[EvidenceImg] ✓ $uploaded/${localPaths.length} $kind subidas ($taskId${version != null ? ' v$version' : ''})');
      return uploaded > 0;
    } catch (e) {
      AppLog.d('[EvidenceImg] ✗ upload $kind ($taskId): $e');
      return false;
    }
  }

  Future<Uint8List?> _compress(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    // flutter_image_compress no tiene implementación para Windows/
    // Linux — ahí se sube el archivo tal cual (ya viene acotado a
    // ~2MB por el límite del Worker igual).
    if (!PlatformCaps.isMobile) return file.readAsBytes();

    // Calidad adaptativa hasta caber en _maxBytes
    for (final quality in const [85, 70, 55]) {
      final bytes = await FlutterImageCompress.compressWithFile(
        path,
        quality: quality,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );
      if (bytes == null) return null;
      if (bytes.lengthInBytes <= _maxBytes) return bytes;
    }
    // Último recurso: reducir resolución
    return FlutterImageCompress.compressWithFile(
      path,
      quality: 55,
      minWidth: 960,
      minHeight: 960,
      format: CompressFormat.jpeg,
    );
  }

  Future<void> _deleteAll(String studentId, String taskId, String kind) async {
    await TaskImageRemote.instance
        .deleteAll(studentId: studentId, taskId: taskId, kind: kind);
  }

  /// Sin [version], el Worker borra TODO lo que empiece con ese
  /// prefijo — como cada carpeta versionada es un sub-prefijo de
  /// `evidence/{studentId}/{taskId}/`, esto borra todas las
  /// versiones (todos los envíos) de una sola vez. La referencia no
  /// tiene versiones (un solo objeto), se borra igual.
  @override
  Future<void> deleteAllTaskImages({
    required String studentId,
    required String taskId,
  }) async {
    await _deleteAll(studentId, taskId, 'evidence');
    await _deleteAll(studentId, taskId, 'reference');
  }

  // ─────────────────────────────────────────────────────────────
  // DESCARGA
  // ─────────────────────────────────────────────────────────────

  /// Descarga las imágenes de un tipo (y opcionalmente [version]) al
  /// cache local y devuelve las rutas.
  @override
  Future<List<String>> downloadImages({
    required String studentId,
    required String taskId,
    required String kind,
    String? version,
    bool forceRefresh = false,
  }) async {
    if (studentId.isEmpty) return const [];
    try {
      final dir = await _localDir(taskId, version: version);
      final names = await TaskImageRemote.instance.listNames(
        studentId: studentId,
        taskId: taskId,
        kind: kind,
        version: version,
      );

      final paths = <String>[];
      for (final name in names) {
        if (!name.startsWith(kind)) continue;
        final localFile = File(p.join(dir.path, name));
        // Una descarga versionada nunca cambia de contenido (cada
        // envío tiene su propia carpeta fija) — solo se re-verifica
        // forceRefresh/existencia para la "actual" (sin versión), que
        // sí puede quedar desactualizada bajo el mismo nombre.
        if (version != null ? !await localFile.exists() : (forceRefresh || !await localFile.exists())) {
          final bytes = await TaskImageRemote.instance.download(
            studentId: studentId,
            taskId: taskId,
            kind: kind,
            name: name,
            version: version,
          );
          if (bytes == null) continue;
          await localFile.writeAsBytes(bytes);
        }
        paths.add(localFile.path);
      }
      paths.sort();
      return paths;
    } catch (e) {
      AppLog.d('[EvidenceImg] ✗ download $kind ($taskId): $e');
      return const [];
    }
  }

  /// Imágenes ya cacheadas localmente (sin ir a la red).
  @override
  Future<List<String>> getLocalPaths(String taskId, String kind, {String? version}) async {
    try {
      final dir = await _localDir(taskId, version: version);
      if (!await dir.exists()) return const [];
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => p.basename(f.path).startsWith(kind))
          .map((f) => f.path)
          .toList()
        ..sort();
      return files;
    } catch (_) {
      return const [];
    }
  }

  Future<Directory> _localDir(String taskId, {String? version}) async {
    final docs = await getApplicationDocumentsDirectory();
    final segments = [docs.path, 'EduTrack', 'images', taskId];
    if (version != null) segments.add(version);
    final dir = Directory(p.joinAll(segments));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ─────────────────────────────────────────────────────────────
  // FOTO DE PERFIL — vía el Worker (Cloudflare R2), no Firebase
  // Storage (nunca se activó en la consola del proyecto).
  // ─────────────────────────────────────────────────────────────

  @override
  Future<String?> uploadProfilePhoto(String uid, String localPath) async {
    if (uid.isEmpty) return null;
    final bytes = await _compress(localPath);
    if (bytes == null) return null;
    return ProfilePhotoRemote.instance.upload(bytes);
  }

  @override
  Future<bool> downloadProfilePhoto(String uid, String destPath) async {
    if (uid.isEmpty) return false;
    final bytes = await ProfilePhotoRemote.instance.download(uid);
    if (bytes == null) return false;
    await File(destPath).writeAsBytes(bytes);
    return true;
  }
}
