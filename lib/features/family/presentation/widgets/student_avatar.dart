import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/providers/profile_photo_provider.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT AVATAR — círculo con foto, o iniciales sobre su color.
// La foto sale de profilePhotoProvider (mismo sistema que Ajustes,
// sincronizado vía el Worker/R2) — no del viejo campo
// student.photoPath, que nunca tuvo una pantalla para configurarlo y
// se quedó sin usar.
// ═══════════════════════════════════════════════════════════════

/// Paleta de colores de avatar para elegir al crear el perfil.
const List<Color> kAvatarColors = [
  Color(0xFF2196F3), // azul
  Color(0xFF4CAF50), // verde
  Color(0xFFFF9800), // naranja
  Color(0xFF9C27B0), // morado
  Color(0xFFE91E63), // rosa
  Color(0xFF00BCD4), // cian
  Color(0xFF795548), // café
  Color(0xFF3F51B5), // índigo
];

class StudentAvatar extends ConsumerWidget {
  final StudentProfile student;
  final double radius;

  const StudentAvatar({super.key, required this.student, this.radius = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoProvider(student.id)) ?? student.photoPath;
    if (photo != null && photo.isNotEmpty && File(photo).existsSync()) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(photo)),
      );
    }

    final color = student.avatarColor != null
        ? Color(student.avatarColor!)
        : AppColors.accentBlue;

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        student.initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.72,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }
}
