import 'dart:io';

import 'package:flutter/material.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT AVATAR — círculo con foto, o iniciales sobre su color.
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

class StudentAvatar extends StatelessWidget {
  final StudentProfile student;
  final double radius;

  const StudentAvatar({super.key, required this.student, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final photo = student.photoPath;
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
