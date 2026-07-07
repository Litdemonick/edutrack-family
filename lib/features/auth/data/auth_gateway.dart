import 'package:edutrack_family/core/data/local/models/app_user_model.dart';

// ═══════════════════════════════════════════════════════════════
// AUTH GATEWAY — EduTrack Family 2.0
// Interfaz neutral de plataforma para autenticación. Android/iOS
// usan FirebaseAuthRepository (SDK nativo, ver
// firebase_auth_repository.dart); Windows/Linux usan
// DesktopAuthSession (REST a Identity Toolkit, ver
// core/firebase/rest/desktop_auth_session.dart) porque
// firebase_auth no tiene implementación nativa ahí.
//
// AuthUser reemplaza a firebase_auth.User como moneda compartida
// entre ambas implementaciones (User no es construible fuera del
// plugin, y el plugin no existe en desktop).
// ═══════════════════════════════════════════════════════════════

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final bool isAnonymous;
  final List<String> providerIds;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
    this.isAnonymous = false,
    this.providerIds = const [],
  });
}

/// Resultado de una operación de auth con mensaje en español.
class AuthResult {
  final bool ok;
  final String? error;
  const AuthResult.success()
      : ok = true,
        error = null;
  const AuthResult.fail(this.error) : ok = false;
}

abstract class AuthGateway {
  AuthUser? get currentUser;
  Stream<AuthUser?> get userChanges;

  /// ID token actual (con refresco automático si aplica) — lo usa
  /// ApiClient para el Bearer del Worker de Cloudflare.
  Future<String?> currentIdToken();

  Future<AuthResult> registerAdult({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required int dobYear,
  });

  Future<AuthResult> completeProfile({
    required UserRole role,
    required int dobYear,
    String? displayName,
  });

  Future<AuthResult> signInWithEmail(String email, String password);
  Future<AuthResult> signInWithGoogle();
  Future<AuthResult> linkWithGoogle();
  Future<AuthResult> signInWithCustomToken(String token);

  /// Sesión anónima temporal — bootstrap para llamar al Worker antes
  /// de tener una identidad real (ej. canjear código de vinculación).
  Future<AuthResult> signInAnonymously();

  Future<AuthResult> sendPasswordReset(String email);
  Future<void> resendVerification();
  Future<bool> reloadAndCheckVerified();

  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  /// Confirma que la sesión sigue siendo válida en el servidor
  /// (fuerza el refresh en vez de esperar a que expire pasivamente)
  /// y cierra la sesión localmente si ya no lo es — usado tras pedir
  /// un restablecimiento de contraseña por correo, ya que Firebase
  /// invalida el refresh token en cuanto se completa el cambio.
  Future<void> validateSession();

  Future<SessionUser?> loadProfile(AuthUser user);
}
