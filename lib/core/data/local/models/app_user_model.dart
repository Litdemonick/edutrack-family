import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════
// APP USER — EduTrack Family 2.0
// Usuario autenticado con Firebase Auth (adulto o estudiante).
// Reemplaza al antiguo AppUsers hardcodeado (admin/yordan).
//
// - parent / teacher: cuenta real email+password o Google
// - student: el uid ES el studentId (sesión por custom token,
//   creada al canjear un código de vinculación)
// ═══════════════════════════════════════════════════════════════

enum UserRole { parent, teacher, student }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.parent:
        return 'Padre / Tutor';
      case UserRole.teacher:
        return 'Profesor/a';
      case UserRole.student:
        return 'Estudiante';
    }
  }

  String get emoji {
    switch (this) {
      case UserRole.parent:
        return '👨‍👩‍👧';
      case UserRole.teacher:
        return '👩‍🏫';
      case UserRole.student:
        return '🎒';
    }
  }

  static UserRole fromName(String? name) {
    switch (name) {
      case 'parent':
        return UserRole.parent;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
        return UserRole.student;
      default:
        // Rol desconocido → tratar como el de menos privilegios
        return UserRole.student;
    }
  }
}

class SessionUser extends Equatable {
  /// uid de Firebase Auth. Para estudiantes, uid == studentId.
  final String uid;
  final UserRole role;
  final String displayName;
  final String? email;
  final bool emailVerified;
  final String? photoUrl;

  /// Año de nacimiento declarado (verificación ≥18 para adultos).
  final int? dobYear;

  /// Proveedores vinculados: 'password', 'google.com'
  final List<String> providers;

  const SessionUser({
    required this.uid,
    required this.role,
    required this.displayName,
    this.email,
    this.emailVerified = false,
    this.photoUrl,
    this.dobYear,
    this.providers = const [],
  });

  bool get isParent => role == UserRole.parent;
  bool get isTeacher => role == UserRole.teacher;
  bool get isStudent => role == UserRole.student;
  bool get isAdult => isParent || isTeacher;
  bool get hasGoogleLinked => providers.contains('google.com');
  bool get hasPasswordProvider => providers.contains('password');

  // ── Compatibilidad transicional con la UI v1 ────────────────
  // (las shells v1 usaban AppUser.id/isAdmin/avatarEmoji/username;
  //  se eliminan cuando las pantallas nuevas de F4 las reemplacen)
  String get id => uid;
  bool get isAdmin => isAdult;
  String get avatarEmoji => role.emoji;
  String get username => email ?? displayName;

  SessionUser copyWith({
    UserRole? role,
    String? displayName,
    String? email,
    bool? emailVerified,
    String? photoUrl,
    int? dobYear,
    List<String>? providers,
  }) {
    return SessionUser(
      uid: uid,
      role: role ?? this.role,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      photoUrl: photoUrl ?? this.photoUrl,
      dobYear: dobYear ?? this.dobYear,
      providers: providers ?? this.providers,
    );
  }

  // ── Doc users/{uid} en Firestore ─────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'role': role.name,
        'displayName': displayName,
        'email': email,
        'photoURL': photoUrl,
        'dobYear': dobYear,
        'providers': providers,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory SessionUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return SessionUser(
      uid: uid,
      role: UserRoleExt.fromName(data['role'] as String?),
      displayName: (data['displayName'] ?? '') as String,
      email: data['email'] as String?,
      photoUrl: data['photoURL'] as String?,
      dobYear: data['dobYear'] as int?,
      providers: (data['providers'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  List<Object?> get props =>
      [uid, role, displayName, email, emailVerified, photoUrl, dobYear, providers];
}
