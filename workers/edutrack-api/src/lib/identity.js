import { getAccessToken } from './google-auth.js';

// ═══════════════════════════════════════════════════════════════
// IDENTITY TOOLKIT REST — custom claims (equivalente a
// admin.auth().setCustomUserClaims / getUser).
// ═══════════════════════════════════════════════════════════════

async function callIdentityToolkit(env, method, body) {
  const token = await getAccessToken(env);
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/accounts:${method}`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) throw new Error(`Identity Toolkit ${method}: ${res.status} ${await res.text()}`);
  return res.json();
}

/** Devuelve { uid, providers: string[], customClaims: object } o null si no existe. */
export async function lookupUser(env, uid) {
  const json = await callIdentityToolkit(env, 'lookup', { localId: [uid] });
  const user = (json.users || [])[0];
  if (!user) return null;

  let customClaims = {};
  if (user.customAttributes) {
    try {
      customClaims = JSON.parse(user.customAttributes);
    } catch (_) {}
  }

  return {
    uid: user.localId,
    providers: (user.providerUserInfo || []).map((p) => p.providerId),
    customClaims,
  };
}

/** Reemplaza los custom claims del usuario (mismo comportamiento que Admin SDK). */
export async function setCustomClaims(env, uid, claims) {
  await callIdentityToolkit(env, 'update', {
    localId: uid,
    customAttributes: JSON.stringify(claims),
  });
}
