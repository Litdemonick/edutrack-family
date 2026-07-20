// ═══════════════════════════════════════════════════════════════
// API CONFIG — EduTrack Family 2.0
// URL del backend en Cloudflare Workers (gratis, sin tarjeta —
// reemplaza a las Cloud Functions de Firebase, que exigían Blaze).
//
// Actualiza este valor después de `npm run deploy` en
// workers/edutrack-api/ (ver su README.md).
// ═══════════════════════════════════════════════════════════════

class ApiConfig {
  ApiConfig._();

  static const String baseUrl = 'https://edutrack-family-api.edutrack-family.workers.dev';
}
