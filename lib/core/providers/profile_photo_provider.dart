import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:edutrack_family/core/features/profile/profile_crop_screen.dart';

// ═══════════════════════════════════════════════════════════════
// PROFILE PHOTO PROVIDER — EduTrack Family
// Persiste la foto de perfil de cada usuario (admin / yordan).
// Flujo: galería → ProfileCropScreen (Flutter puro) → profiles/profile_<userId>.png
// ═══════════════════════════════════════════════════════════════

class ProfilePhotoNotifier extends StateNotifier<String?> {
  ProfilePhotoNotifier(this._userId) : super(null) {
    _load();
  }

  final String _userId;
  final _picker = ImagePicker();

  String get _key => 'profile_photo_$_userId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_key);
    if (path != null && File(path).existsSync()) {
      state = path;
    }
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

      // 3. Verificar que el archivo existe y persistir
      if (!File(destPath).existsSync()) return;

      // Evict del cache de Flutter para que Image.file cargue los bytes nuevos
      await FileImage(File(destPath)).evict();

      // Forzar notificación a Riverpod aunque el path sea idéntico
      // (segunda o tercera foto: mismo nombre de archivo, contenido diferente)
      if (state == destPath) state = null;
      state = destPath;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, destPath);
    } catch (e) {
      debugPrint('[ProfilePhoto] Error picking/cropping image: $e');
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
    await prefs.remove(_key);
  }
}

final profilePhotoProvider = StateNotifierProvider.family<
    ProfilePhotoNotifier, String?, String>(
  (ref, userId) => ProfilePhotoNotifier(userId),
);
