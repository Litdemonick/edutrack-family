import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// ═══════════════════════════════════════════════════════════════
// IMAGE TRANSFER SERVICE — EduTrack Family
//
// Transfiere imágenes entre dispositivos usando Firestore como
// canal de transporte (base64). No usa Firebase Storage.
//
// Flujo:
//   SUBIDA   → comprime JPEG a ≤ 600KB → base64 → colección `task_images`
//   DESCARGA → base64 → decodifica → guarda en carpeta local
//
// Límites Firestore:
//   - Documento máx 1MB (string base64 ≈ 133% del binario)
//   - Máx 600KB binario → ~800KB base64 → seguro dentro del límite
//
// Compresión:
//   - Usa flutter_image_compress (JPEG nativo, no PNG)
//   - Resolución máx 1280px → máxima calidad posible
//   - Estrategia de calidad: 85 → 70 → 55 (adaptativa por tamaño)
//
// Carpeta local:
//   <appDocuments>/EduTrack/images/<taskId>/
//     ref_0.jpg, ref_1.jpg       ← referencias del Admin
//     evidence_0.jpg, ...        ← evidencias del Estudiante
// ═══════════════════════════════════════════════════════════════

class ImageTransferService {
  ImageTransferService._();
  static final ImageTransferService instance = ImageTransferService._();

  final _uuid = const Uuid();
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _images =>
      _db.collection('task_images');

  // Tamaño máximo del binario antes de base64.
  // 600KB × 1.333 (base64 overhead) ≈ 800KB → bien dentro del límite de 1MB
  static const int _maxBinaryBytes = 600 * 1024;

  // ─────────────────────────────────────────────────────────────
  // CARPETA LOCAL
  // ─────────────────────────────────────────────────────────────

  Future<Directory> _taskDir(String taskId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/EduTrack/images/$taskId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // Devuelve los paths locales existentes para un tipo dado (ordenados)
  Future<List<String>> getLocalPaths(String taskId, String type) async {
    try {
      final dir = await _taskDir(taskId);
      if (!await dir.exists()) return [];

      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('${type}_'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

      return files.map((f) => f.path).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // SUBIDA — comprime y sube a Firestore
  // ─────────────────────────────────────────────────────────────

  Future<void> uploadImages({
    required String taskId,
    required String type,
    required List<String> localPaths,
  }) async {
    // 1. Eliminar documentos previos del mismo tipo para esta tarea
    try {
      final existing = await _images
          .where('task_id', isEqualTo: taskId)
          .get();
      for (final doc in existing.docs) {
        if ((doc.data()['type'] as String?) == type) {
          await doc.reference.delete();
        }
      }
    } catch (_) {}

    // 2. Subir cada imagen comprimida en JPEG
    for (int i = 0; i < localPaths.length; i++) {
      final path = localPaths[i];
      try {
        final file = File(path);
        if (!await file.exists()) continue;

        final bytes = await _compressToJpeg(path);
        if (bytes == null || bytes.isEmpty) continue;

        // Verificar límite (no debería fallar, _compressToJpeg ya lo garantiza)
        if (bytes.lengthInBytes > _maxBinaryBytes) continue;

        final b64 = base64Encode(bytes);

        await _images.doc(_uuid.v4()).set({
          'task_id': taskId,
          'type': type,
          'index': i,
          'data': b64,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Error en imagen individual → continuar con las demás
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DESCARGA — trae de Firestore y guarda local
  // ─────────────────────────────────────────────────────────────

  Future<List<String>> downloadImages({
    required String taskId,
    required String type,
  }) async {
    try {
      final snap = await _images
          .where('task_id', isEqualTo: taskId)
          .get();

      final matchingDocs = snap.docs
          .where((d) => (d.data()['type'] as String?) == type)
          .toList();

      if (matchingDocs.isEmpty) return [];

      final dir = await _taskDir(taskId);
      final entries = <MapEntry<int, String>>[];

      for (final doc in matchingDocs) {
        try {
          final data = doc.data();
          final index = (data['index'] as int?) ?? 0;
          final b64   = data['data'] as String? ?? '';
          if (b64.isEmpty) continue;

          final bytes    = base64Decode(b64);
          final filePath = '${dir.path}/${type}_$index.jpg';

          await File(filePath).writeAsBytes(bytes, flush: true);
          entries.add(MapEntry(index, filePath));
        } catch (_) {}
      }

      if (entries.isEmpty) return [];
      entries.sort((a, b) => a.key.compareTo(b.key));
      return entries.map((e) => e.value).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────
  // COMPRESIÓN JPEG — usa flutter_image_compress (nativo)
  //
  // Estrategia adaptativa de calidad:
  //   1. Intenta calidad 85 con resolución 1280px (máxima calidad)
  //   2. Si supera 600KB → intenta calidad 70
  //   3. Si sigue grande → intenta calidad 55
  //   4. Si sigue grande → prueba con 960px + calidad 70
  //   5. Falla → descarta la imagen
  // ─────────────────────────────────────────────────────────────

  Future<Uint8List?> _compressToJpeg(String path) async {
    try {
      // Intento 1: calidad 85, resolución 1280px
      var result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 0,
        minHeight: 0,
        quality: 85,
        format: CompressFormat.jpeg,
      );

      if (result != null && result.lengthInBytes <= _maxBinaryBytes) {
        return result;
      }

      // Intento 2: calidad 70, misma resolución
      result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 0,
        minHeight: 0,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (result != null && result.lengthInBytes <= _maxBinaryBytes) {
        return result;
      }

      // Intento 3: calidad 55 — mínimo aceptable de calidad visual
      result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 0,
        minHeight: 0,
        quality: 55,
        format: CompressFormat.jpeg,
      );

      if (result != null && result.lengthInBytes <= _maxBinaryBytes) {
        return result;
      }

      // Intento 4: reducir resolución a 960px + calidad 70
      // Para fotos extremadamente grandes (ej. cámara 48MP sin comprimir)
      result = await FlutterImageCompress.compressWithFile(
        path,
        minWidth: 0,
        minHeight: 0,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      // Último fallback: usar original si ya es pequeño
      if (result == null) {
        final original = await File(path).readAsBytes();
        return original.lengthInBytes <= _maxBinaryBytes ? original : null;
      }

      return result.lengthInBytes <= _maxBinaryBytes ? result : null;
    } catch (_) {
      return null;
    }
  }
}
