import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_family/core/features/profile/profile_crop_screen.dart';
import 'package:edutrack_family/core/firebase/firestore_paths.dart';
import 'package:edutrack_family/core/firebase/firestore_service.dart';
import 'package:edutrack_family/core/services/evidence_image_service.dart';
import 'package:edutrack_family/core/utils/app_log.dart';

// ═══════════════════════════════════════════════════════════════
// PROFILE PHOTO PROVIDER — EduTrack Family
// Flujo: galería → ProfileCropScreen (Flutter puro) → cache local +
// sube a R2 vía el Worker (profiles/{uid}/photo.jpg). El Worker
// también marca photoUpdatedAt en Firestore (en students/{uid} si el
// uid es un estudiante, o en users/{uid} si es adulto) — el CLIENTE
// ya no escribe eso directo, porque un estudiante no puede: no tiene
// doc en users/{uid}, y storage.rules tampoco lo deja tocar su propio
// students/{uid} (solo el guardián puede). El Worker usa el service
// account, que ignora esa restricción.
//
// El provider ESCUCHA ambos documentos posibles en vivo (watchRawDoc:
// streaming real de Firestore en Android/iOS, polling en Windows/
// Linux) — cualquiera que exista para este uid tendrá el campo real,
// el otro simplemente nunca trae photoUpdatedAt y no hace nada — así
// que un cambio hecho en otro dispositivo de la misma cuenta (sea
// padre, profesor o estudiante) se descarga solo, sin reabrir la app.
// ═══════════════════════════════════════════════════════════════

class ProfilePhotoNotifier extends StateNotifier<String?> {
  ProfilePhotoNotifier(this._userId) : super(null) {
    _load();
  }

  final String _userId;
  final _picker = ImagePicker();
  StreamSubscription<Map<String, dynamic>?>? _userDocSub;
  StreamSubscription<Map<String, dynamic>?>? _studentDocSub;

  String get _pathKey => 'profile_photo_$_userId';
  String get _updatedAtKey => 'profile_photo_updated_$_userId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final localPath = prefs.getString(_pathKey);

    // Mostrar de inmediato lo que haya en cache local (offline-first).
    if (localPath != null && File(localPath).existsSync()) {
      state = localPath;
    }

    _userDocSub = FirestoreService.instance
        .watchRawDoc(FirestorePaths.user(_userId))
        .listen(
          _onRemoteDocChanged,
          onError: (e) =>
              AppLog.d('[ProfilePhoto] Error escuchando users/$_userId: $e'),
        );
    _studentDocSub = FirestoreService.instance
        .watchRawDoc(FirestorePaths.student(_userId))
        .listen(
          _onRemoteDocChanged,
          onError: (e) =>
              AppLog.d('[ProfilePhoto] Error escuchando students/$_userId: $e'),
        );
  }

  Future<void> _onRemoteDocChanged(Map<String, dynamic>? doc) async {
    try {
      final remoteUpdatedAt = doc?['photoUpdatedAt'] as String?;
      if (remoteUpdatedAt == null) return; // nunca se subió foto (o es el doc que no aplica)

      final prefs = await SharedPreferences.getInstance();
      final localUpdatedAt = prefs.getString(_updatedAtKey);
      if (localUpdatedAt == remoteUpdatedAt) return; // ya tenemos la última

      final destPath = await _localFilePath();
      final ok = await EvidenceImageService.instance
          .downloadProfilePhoto(_userId, destPath);
      if (!ok) return;

      await FileImage(File(destPath)).evict();
      if (state == destPath) state = null;
      state = destPath;

      await prefs.setString(_pathKey, destPath);
      await prefs.setString(_updatedAtKey, remoteUpdatedAt);
    } catch (e) {
      AppLog.d('[ProfilePhoto] Error aplicando foto remota: $e');
    }
  }

  @override
  void dispose() {
    _userDocSub?.cancel();
    _studentDocSub?.cancel();
    super.dispose();
  }

  Future<String> _localFilePath() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'profiles'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return p.join(dir.path, 'profile_$_userId.jpg');
  }

  // Abre galería → ProfileCropScreen (Flutter, SafeArea) → guarda resultado
  Future<void> pickFromGallery(BuildContext context) async {
    try {
      // 1. Elegir imagen de galería
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (xFile == null) return;

      // 2. Abrir recortador circular Flutter puro
      if (!context.mounted) return;
      final destPath = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileCropScreen(
            imagePath: xFile.path,
            userId: _userId,
          ),
          fullscreenDialog: true,
        ),
      );
      if (destPath == null) return; // usuario canceló

      // 3. Verificar que el archivo existe y persistir localmente
      if (!File(destPath).existsSync()) return;

      // Evict del cache de Flutter para que Image.file cargue los bytes nuevos
      await FileImage(File(destPath)).evict();

      // Forzar notificación a Riverpod aunque el path sea idéntico
      // (segunda o tercera foto: mismo nombre de archivo, contenido diferente)
      if (state == destPath) state = null;
      state = destPath;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pathKey, destPath);

      // 4. Subir para que otros dispositivos de la misma cuenta la vean.
      // El Worker marca photoUpdatedAt del lado correcto (students o
      // users) y nos devuelve el valor exacto que guardó — lo usamos
      // tal cual en vez de generar el nuestro, para que coincida con
      // lo que compara _onRemoteDocChanged al recibir el eco de este
      // mismo cambio.
      final updatedAt = await EvidenceImageService.instance
          .uploadProfilePhoto(_userId, destPath);
      if (updatedAt != null) {
        await prefs.setString(_updatedAtKey, updatedAt);
      } else if (context.mounted) {
        // Antes esto fallaba en silencio (sin conexión, permisos,
        // etc.) y parecía que "no sincronizaba" sin ninguna pista.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo sincronizar la foto — se guardó solo en '
              'este dispositivo. Revisa tu conexión e intenta de nuevo.',
              style: TextStyle(fontFamily: 'Nunito'),
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      AppLog.d('[ProfilePhoto] Error picking/cropping image: $e');
    }
  }

  Future<void> remove() async {
    if (state != null) {
      try {
        File(state!).deleteSync();
      } catch (_) {}
    }
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
    await prefs.remove(_updatedAtKey);
    // Best-effort: para un estudiante esto falla en silencio (mismas
    // reglas que antes) — la foto igual se borró localmente. Quitar
    // la foto es una acción rara; no vale la pena pasarla por el
    // Worker solo para este caso todavía.
    try {
      await FirestoreService.instance
          .setRawDoc(FirestorePaths.user(_userId), {'photoUpdatedAt': null});
    } catch (_) {}
  }
}

final profilePhotoProvider = StateNotifierProvider.family<
    ProfilePhotoNotifier, String?, String>(
  (ref, userId) => ProfilePhotoNotifier(userId),
);
