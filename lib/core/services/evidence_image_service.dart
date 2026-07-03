import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../firebase/firestore_paths.dart';

// ═══════════════════════════════════════════════════════════════
// EVIDENCE IMAGE SERVICE — EduTrack Family 2.0
// Fotos de evidencia/referencia por Firebase Storage (reemplaza el
// canal base64 de la v1 que quemaba la cuota de Firestore).
//
// Rutas del bucket (protegidas por storage.rules):
//   evidence/{studentId}/{taskId}/evidence_N.jpg   (sube el hijo)
//   reference/{studentId}/{taskId}/reference_N.jpg (sube el adulto)
//
// Cache local: <docs>/EduTrack/images/<taskId>/<kind>_N.jpg
// ═══════════════════════════════════════════════════════════════

class EvidenceImageService {
  EvidenceImageService._();
  static final EvidenceImageService instance = EvidenceImageService._();

  final _storage = FirebaseStorage.instance;

  static const int _maxBytes = 300 * 1024; // ≤300 KB por foto

  String _bucketDir(String kind, String studentId, String taskId) =>
      kind == 'reference'
          ? FirestorePaths.referenceStoragePath(studentId, taskId, '')
          : FirestorePaths.evidenceStoragePath(studentId, taskId, '');

  // ─────────────────────────────────────────────────────────────
  // SUBIDA
  // ─────────────────────────────────────────────────────────────

  /// Comprime y sube las imágenes. Reemplaza las previas del mismo tipo.
  /// [kind]: 'evidence' | 'reference'
  Future<bool> uploadImages({
    required String studentId,
    required String taskId,
    required String kind,
    required List<String> localPaths,
  }) async {
    if (studentId.isEmpty || localPaths.isEmpty) return false;
    try {
      // Borrar las previas de este tipo (re-subida limpia)
      await _deleteAll(studentId, taskId, kind);

      for (var i = 0; i < localPaths.length; i++) {
        final bytes = await _compress(localPaths[i]);
        if (bytes == null) continue;

        final ref = _storage
            .ref()
            .child('${_bucketDir(kind, studentId, taskId)}${kind}_$i.jpg');
        await ref.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }
      debugPrint('[EvidenceImg] ✓ ${localPaths.length} $kind subidas ($taskId)');
      return true;
    } catch (e) {
      debugPrint('[EvidenceImg] ✗ upload $kind ($taskId): $e');
      return false;
    }
  }

  Future<Uint8List?> _compress(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

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
    try {
      final list = await _storage
          .ref()
          .child(_bucketDir(kind, studentId, taskId))
          .listAll();
      for (final item in list.items) {
        if (item.name.startsWith(kind)) {
          await item.delete().catchError((_) {});
        }
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // DESCARGA
  // ─────────────────────────────────────────────────────────────

  /// Descarga las imágenes de un tipo al cache local y devuelve las rutas.
  Future<List<String>> downloadImages({
    required String studentId,
    required String taskId,
    required String kind,
  }) async {
    if (studentId.isEmpty) return const [];
    try {
      final dir = await _localDir(taskId);
      final list = await _storage
          .ref()
          .child(_bucketDir(kind, studentId, taskId))
          .listAll();

      final paths = <String>[];
      for (final item in list.items) {
        if (!item.name.startsWith(kind)) continue;
        final localFile = File(p.join(dir.path, item.name));
        if (!await localFile.exists()) {
          await item.writeToFile(localFile);
        }
        paths.add(localFile.path);
      }
      paths.sort();
      return paths;
    } catch (e) {
      debugPrint('[EvidenceImg] ✗ download $kind ($taskId): $e');
      return const [];
    }
  }

  /// Imágenes ya cacheadas localmente (sin ir a la red).
  Future<List<String>> getLocalPaths(String taskId, String kind) async {
    try {
      final dir = await _localDir(taskId);
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

  Future<Directory> _localDir(String taskId) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'EduTrack', 'images', taskId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
