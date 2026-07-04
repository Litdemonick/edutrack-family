import { SignJWT, importPKCS8 } from 'jose';

// ═══════════════════════════════════════════════════════════════
// GOOGLE AUTH — obtiene tokens OAuth2 firmando con el service
// account (flujo JWT-bearer), sin depender del SDK de Admin
// (que solo corre en Node/Cloud Functions con plan Blaze).
//
// Un solo access token cubre Firestore + Identity Toolkit + FCM
// porque pedimos los 3 scopes juntos.
// ═══════════════════════════════════════════════════════════════

const SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/identitytoolkit',
  'https://www.googleapis.com/auth/firebase.messaging',
].join(' ');

// Cache en memoria del isolate — ahorra una firma+request por invocación
// cuando Cloudflare reutiliza el mismo isolate entre llamadas cercanas.
let cachedToken = null;
let cachedExpiry = 0;

function normalizePrivateKey(raw) {
  // wrangler secret put no interpreta \n — llegan como texto literal
  return raw.includes('\\n') ? raw.replace(/\\n/g, '\n') : raw;
}

export async function getAccessToken(env) {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now < cachedExpiry - 60) return cachedToken;

  const privateKey = await importPKCS8(
    normalizePrivateKey(env.FIREBASE_PRIVATE_KEY),
    'RS256',
  );

  const assertion = await new SignJWT({ scope: SCOPES })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(env.FIREBASE_CLIENT_EMAIL)
    .setSubject(env.FIREBASE_CLIENT_EMAIL)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!res.ok) {
    throw new Error(`OAuth2 token exchange falló: ${res.status} ${await res.text()}`);
  }

  const json = await res.json();
  cachedToken = json.access_token;
  cachedExpiry = now + json.expires_in;
  return cachedToken;
}

/** Crea un custom token de Firebase Auth (mismo formato que admin.auth().createCustomToken). */
export async function createCustomToken(env, uid, claims) {
  const privateKey = await importPKCS8(
    normalizePrivateKey(env.FIREBASE_PRIVATE_KEY),
    'RS256',
  );
  const now = Math.floor(Date.now() / 1000);

  return new SignJWT({ uid, claims })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(env.FIREBASE_CLIENT_EMAIL)
    .setSubject(env.FIREBASE_CLIENT_EMAIL)
    .setAudience(
      'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
    )
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);
}
