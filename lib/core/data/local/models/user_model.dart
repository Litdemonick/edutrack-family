import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════
// USER MODEL — EduTrack Family
// Representa los 2 usuarios preinstalados de la app.
// ═══════════════════════════════════════════════════════════════

enum UserRole { admin, student }

class AppUser extends Equatable {
  final String id;
  final String username;
  final String displayName;
  final String password;
  final UserRole role;
  final String avatarEmoji;

  const AppUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.password,
    required this.role,
    required this.avatarEmoji,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isStudent => role == UserRole.student;

  @override
  List<Object?> get props => [id, username, role];
}

// ─────────────────────────────────────────────────────────────
// CUENTAS FIJAS — no hay registro, solo estas 2
// ─────────────────────────────────────────────────────────────
class AppUsers {
  AppUsers._();

  static const AppUser admin = AppUser(
    id: 'admin_001',
    username: 'admin',
    displayName: 'Administrador',
    password: 'admin2024',
    role: UserRole.admin,
    avatarEmoji: '👩‍💼',
  );

  static const AppUser student = AppUser(
    id: 'student_001',
    username: 'yordan',
    displayName: 'Yordan',
    password: 'yordan2024',
    role: UserRole.student,
    avatarEmoji: '🎒',
  );

  static List<AppUser> get all => [admin, student];

  static AppUser? authenticate(String username, String password) {
    try {
      return all.firstWhere(
        (u) =>
            u.username.toLowerCase() == username.toLowerCase() &&
            u.password == password,
      );
    } catch (_) {
      return null;
    }
  }
}
