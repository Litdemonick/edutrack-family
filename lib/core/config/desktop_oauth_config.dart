// ═══════════════════════════════════════════════════════════════
// DESKTOP OAUTH CONFIG — EduTrack Family 2.0
// Client ID + secret del OAuth client tipo "Desktop app" en Google
// Cloud Console (proyecto edutrack-family).
//
// El "client secret" de un cliente tipo Desktop NO es un secreto en
// el sentido tradicional: Google lo exige en el intercambio de
// token, pero documenta explícitamente que es seguro embeberlo en
// código distribuido para apps de escritorio/instaladas — una app
// de escritorio no puede guardar secretos de verdad, y la
// protección real la da el redirect_uri (localhost/loopback) + PKCE.
// Ver: https://developers.google.com/identity/protocols/oauth2/native-app
// (distinto de un secret de servidor tipo "Web application", que
// SÍ debe permanecer privado — nunca hagas esto con ese tipo).
//
// Cómo crearlo (una sola vez, lo hace un humano en la consola):
//   Google Cloud Console → proyecto edutrack-family → APIs &
//   Services → Credentials → Create Credentials → OAuth client ID
//   → tipo "Desktop app" → copiar Client ID y Client secret aquí.
// ═══════════════════════════════════════════════════════════════

class DesktopOAuthConfig {
  DesktopOAuthConfig._();

  static const String clientId =
      '378454359271-akpomqsiq1rg1piaqb89eoh10a7lg2hf.apps.googleusercontent.com';

  static const String clientSecret = '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';

  static bool get isConfigured => clientId != 'PENDIENTE_DESKTOP_OAUTH_CLIENT_ID';
}
