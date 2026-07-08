import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// CAMERA SERVICE — EduTrack Family
// Captura fotos de evidencia de tareas completadas.
// Guarda la foto en el directorio local del dispositivo.
// ═══════════════════════════════════════════════════════════════

class CameraService {
  CameraService._();
  static final CameraService instance = CameraService._();

  final _picker = ImagePicker();

  // ─────────────────────────────────────────────────────────────
  // CAPTURAR FOTO (cámara)
  // ─────────────────────────────────────────────────────────────

  Future<String?> takePhoto({required String taskId}) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null) return null;
      return await _saveToLocal(xFile, taskId);
    } catch (e) {
      AppLog.d('[Camera] Error tomando foto: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ELEGIR DE GALERÍA
  // ─────────────────────────────────────────────────────────────

  Future<String?> pickFromGallery({required String taskId}) async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (xFile == null) return null;
      return await _saveToLocal(xFile, taskId);
    } catch (e) {
      AppLog.d('[Camera] Error eligiendo foto: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // ELEGIR MÚLTIPLES DE GALERÍA (hasta [maxCount] fotos)
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> pickMultipleFromGallery({
    required String taskId,
    int maxCount = 12,
  }) async {
    try {
      final xFiles = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
        limit: maxCount,
      );
      if (xFiles.isEmpty) return [];

      final paths = <String>[];
      for (final xFile in xFiles.take(maxCount)) {
        final path = await _saveToLocal(xFile, taskId);
        paths.add(path);
      }
      return paths;
    } catch (e) {
      AppLog.d('[Camera] Error eligiendo múltiples fotos: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // GUARDAR EN DIRECTORIO LOCAL DE LA APP
  // ─────────────────────────────────────────────────────────────

  Future<String> _saveToLocal(XFile xFile, String taskId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory(p.join(appDir.path, 'evidences'));
    if (!evidenceDir.existsSync()) {
      evidenceDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'evidence_${taskId}_$timestamp.jpg';
    final destPath = p.join(evidenceDir.path, fileName);

    await File(xFile.path).copy(destPath);
    return destPath;
  }

  // ─────────────────────────────────────────────────────────────
  // ELIMINAR FOTO LOCAL
  // ─────────────────────────────────────────────────────────────

  Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (e) {
      AppLog.d('[Camera] Error eliminando foto: $e');
    }
  }

  bool fileExists(String path) => File(path).existsSync();
}
