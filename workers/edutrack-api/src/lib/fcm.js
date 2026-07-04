import { getAccessToken } from './google-auth.js';
import { deleteDoc, fromFields } from './firestore.js';

// ═══════════════════════════════════════════════════════════════
// FCM HTTP v1 — envío de push por uid, con poda de tokens muertos.
// Reemplaza admin.messaging().sendEachForMulticast(...).
// ═══════════════════════════════════════════════════════════════

/** Tokens de dispositivo registrados para una lista de uids. */
async function tokensForUids(env, uids) {
  const entries = [];
  for (const uid of uids) {
    const devices = await listUserDevices(env, uid);
    for (const d of devices) entries.push({ uid, installId: d.id, token: d.data.token });
  }
  return entries.filter((e) => typeof e.token === 'string' && e.token.length > 0);
}

/** Lista users/{uid}/devices vía Firestore REST (listDocuments simple, sin filtros). */
async function listUserDevices(env, uid) {
  const url =
    `https://firestore.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}` +
    `/databases/(default)/documents/users/${uid}/devices`;
  const token = await getAccessToken(env);
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) return []; // 404 = sin dispositivos registrados

  const json = await res.json();
  const docs = json.documents || [];
  return docs.map((doc) => ({
    id: doc.name.split('/').pop(),
    data: fromFields(doc.fields),
  }));
}

/** Envía a un token individual vía FCM HTTP v1. */
async function sendOne(env, { token, title, body, data, channelId }) {
  const accessToken = await getAccessToken(env);
  const stringData = {};
  for (const [k, v] of Object.entries(data || {})) stringData[k] = String(v);

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${env.FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data: stringData,
          android: {
            priority: 'high',
            notification: { channel_id: channelId || 'edutrack_system', sound: 'edutrack_notification' },
          },
          apns: {
            payload: { aps: { sound: 'default', 'content-available': 1 } },
          },
        },
      }),
    },
  );

  if (res.ok) return { ok: true };

  const errJson = await res.json().catch(() => ({}));
  const status = errJson?.error?.status || '';
  const shouldPrune = status === 'UNREGISTERED' || status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT';
  return { ok: false, shouldPrune, status };
}

/**
 * Envía una notificación a todos los dispositivos de una lista de uids.
 * Poda automáticamente los tokens que FCM reporta como muertos.
 */
export async function pushToUids(env, uids, { title, body, data, channelId }) {
  if (!uids || uids.length === 0) return { sent: 0, failed: 0 };

  const tokens = await tokensForUids(env, uids);
  let sent = 0;
  let failed = 0;

  for (const entry of tokens) {
    const result = await sendOne(env, { token: entry.token, title, body, data, channelId });
    if (result.ok) {
      sent++;
    } else {
      failed++;
      if (result.shouldPrune) {
        await deleteDoc(env, `users/${entry.uid}/devices/${entry.installId}`).catch(() => {});
      }
    }
  }
  return { sent, failed };
}
