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

/** Devuelve { uid, email, providers: string[], customClaims: object } o null si no existe. */
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
    email: user.email || null,
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

// ═══════════════════════════════════════════════════════════════
// CONFIRMACIÓN DE BORRADO POR CORREO — reusa el mecanismo gratis de
// Firebase de "inicio de sesión sin contraseña" (EMAIL_SIGNIN) solo
// como forma de "manda un link que se auto-verifica al abrirlo" —
// no nos interesa que realmente inicie sesión, solo que probar que
// el dueño de la cuenta tiene acceso a su bandeja de entrada antes de
// dejar borrar un hijo/a. Sin esto habría que pagar un servicio de
// correo transaccional aparte (Resend, SendGrid, etc.).
//
// OJO: esto NO puede pasar por callIdentityToolkit (arriba) — ese
// helper llama a la variante "admin" de la API
// (projects/{id}/accounts:sendOobCode, autenticada con el service
// account), que para sendOobCode SOLO genera el link y NO manda
// ningún correo (así se comporta admin.auth().generatePasswordResetLink
// del SDK de Admin — devuelve el link, el envío queda en tu cuenta).
// El envío real de correo con las plantillas de Firebase solo lo hace
// la API PÚBLICA (identitytoolkit.googleapis.com/v1/accounts:...
// ?key=API_KEY, sin OAuth) — la misma que ya usa la app en
// identity_toolkit_client.dart para el login por REST en Windows. La
// API key es pública a propósito (ya vive en firebase_options.dart,
// en git) — no es un secreto, solo identifica el proyecto.
// ═══════════════════════════════════════════════════════════════

const PUBLIC_API_KEY = 'AIzaSyACWMpSZGUzpT5a6bsqVRYcorXm5k3KMOs';

async function callPublicIdentityToolkit(method, body) {
  const res = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:${method}?key=${PUBLIC_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  if (!res.ok) throw new Error(`Identity Toolkit (public) ${method}: ${res.status} ${await res.text()}`);
  return res.json();
}

/** Manda el correo con el link de confirmación a esa dirección. */
export async function sendConfirmationEmail(env, email, continueUrl) {
  await callPublicIdentityToolkit('sendOobCode', {
    requestType: 'EMAIL_SIGNIN',
    email,
    continueUrl,
    canHandleCodeInApp: false,
  });
}

/** Verifica que el oobCode del link sea válido para ese correo. Lanza si no. */
export async function verifyConfirmationCode(env, email, oobCode) {
  await callPublicIdentityToolkit('signInWithEmailLink', { email, oobCode });
}
