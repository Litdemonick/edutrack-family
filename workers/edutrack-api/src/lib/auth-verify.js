import { jwtVerify, createRemoteJWKSet } from 'jose';

// ═══════════════════════════════════════════════════════════════
// AUTH VERIFY — valida el ID token de Firebase Auth que manda la
// app Flutter en el header Authorization: Bearer <token>.
// Usa el JWKS público de Google (sin secretos, cacheado por jose).
// ═══════════════════════════════════════════════════════════════

const JWKS = createRemoteJWKSet(
  new URL('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com'),
);

export class AuthError extends Error {
  constructor(message, status = 401) {
    super(message);
    this.status = status;
  }
}

/** Devuelve { uid, claims } o lanza AuthError. */
export async function verifyIdToken(request, projectId) {
  const header = request.headers.get('Authorization') || '';
  const match = header.match(/^Bearer (.+)$/);
  if (!match) throw new AuthError('Falta el header Authorization: Bearer <token>');

  let payload;
  try {
    const result = await jwtVerify(match[1], JWKS, {
      issuer: `https://securetoken.google.com/${projectId}`,
      audience: projectId,
    });
    payload = result.payload;
  } catch (e) {
    throw new AuthError(`Token inválido: ${e.message}`);
  }

  if (!payload.sub) throw new AuthError('Token sin uid');
  return { uid: payload.sub, claims: payload };
}
