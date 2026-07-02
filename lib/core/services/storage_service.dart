import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

// ═══════════════════════════════════════════════════════════════
// STORAGE SERVICE — EduTrack Family
// Subida de archivos a Firebase Storage y obtención de URLs.
// ═══════════════════════════════════════════════════════════════

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  /// Garantiza que haya una sesión anónima activa antes de subir.
  Future<void> _ensureAuth() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      debugPrint('[Storage] Sin sesión — iniciando auth anónima...');
      await auth.signInAnonymously();
      debugPrint('[Storage] Auth anónima OK: ${auth.currentUser?.uid}');
    }
  }

  /// Sube un archivo local a Firebase Storage y retorna la URL pública.
  /// Retorna null si el archivo no existe o si el upload falla.
  Future<String?> uploadFile({
    required String localPath,
    required String folderPath,
  }) async {
    try {
      // 1. Verificar que el archivo existe localmente
      final file = File(localPath);
      if (!await file.exists()) {
        debugPrint('[Storage] ⚠ Archivo local no existe: $localPath');
        return null;
      }

      // 2. Garantizar autenticación antes de subir
      await _ensureAuth();

      // 3. Construir ruta en el bucket y subir
      final ext = p.extension(localPath);
      final filename = '${_uuid.v4()}$ext';
      final storagePath = '$folderPath/$filename';
      debugPrint('[Storage] Subiendo archivo → gs://$storagePath');

      final ref = _storage.ref().child(storagePath);
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: _mimeFor(ext)),
      );

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('[Storage] ✓ URL obtenida: $downloadUrl');
      return downloadUrl;
    } on FirebaseException catch (e) {
      debugPrint('[Storage] ✗ FirebaseException (${e.code}): ${e.message}');
      return null;
    } catch (e, st) {
      debugPrint('[Storage] ✗ Error inesperado: $e\n$st');
      return null;
    }
  }

  String _mimeFor(String ext) {
    switch (ext.toLowerCase()) {
      case '.jpg':
      case '.jpeg': return 'image/jpeg';
      case '.png':  return 'image/png';
      case '.webp': return 'image/webp';
      default:      return 'application/octet-stream';
    }
  }
}
