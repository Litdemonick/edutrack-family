import { verifyIdToken, AuthError } from './lib/auth-verify.js';
import {
  getDoc,
  createDoc,
  updateDoc,
  arrayUnion,
  collectionGroupQuery,
  parentStudentPath,
} from './lib/firestore.js';
import { createCustomToken } from './lib/google-auth.js';
import { lookupUser, setCustomClaims } from './lib/identity.js';
import { pushToUids } from './lib/fcm.js';

// ═══════════════════════════════════════════════════════════════
// EDUTRACK API — Cloudflare Worker (gratis, sin tarjeta)
// Reemplaza las Cloud Functions de Firebase (que exigían Blaze).
//
// Rutas HTTP (todas requieren Authorization: Bearer <ID token Firebase>):
//   POST /register-role       { role: 'parent'|'teacher' }
//   POST /create-link-code    { studentId, kind: 'child-device'|'teacher' }
//   POST /redeem-link-code    { code }
//   POST /send-push           { targetUids, title, body, data?, channelId? }
//
// Cron (cada minuto, sin HTTP):
//   checkWellnessTimeouts + checkSeismicActivity
// ═══════════════════════════════════════════════════════════════

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

function json(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

function errorJson(message, status = 400) {
  return json({ error: message }, status);
}

function generateCode() {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sin 0/O/1/I/L
  let code = '';
  for (let i = 0; i < 6; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }
    if (request.method !== 'POST') {
      return errorJson('Método no permitido', 405);
    }

    const { pathname } = new URL(request.url);

    try {
      const { uid } = await verifyIdToken(request, env.FIREBASE_PROJECT_ID);
      const body = await request.json().catch(() => ({}));

      switch (pathname) {
        case '/register-role':
          return await handleRegisterRole(env, uid, body);
        case '/create-link-code':
          return await handleCreateLinkCode(env, uid, body);
        case '/redeem-link-code':
          return await handleRedeemLinkCode(env, uid, body);
        case '/send-push':
          return await handleSendPush(env, uid, body);
        default:
          return errorJson('Ruta no encontrada', 404);
      }
    } catch (e) {
      if (e instanceof AuthError) return errorJson(e.message, e.status);
      console.error(e);
      return errorJson(e.message || 'Error interno', 500);
    }
  },

  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkWellnessTimeouts(env));
    ctx.waitUntil(checkSeismicActivity(env));
  },
};

// ─────────────────────────────────────────────────────────────
// registerRole — custom claim para adultos
// ─────────────────────────────────────────────────────────────

async function handleRegisterRole(env, uid, body) {
  const role = body?.role;
  if (role !== 'parent' && role !== 'teacher') {
    return errorJson('Rol no permitido.');
  }

  const user = await lookupUser(env, uid);
  if (!user) return errorJson('Usuario no encontrado.', 404);
  if (user.providers.length === 0) {
    return errorJson('Cuenta no válida para este rol.', 412);
  }

  const existingRole = user.customClaims?.role;
  if (existingRole && existingRole !== role) {
    return errorJson('Esta cuenta ya tiene un rol asignado.', 412);
  }

  await setCustomClaims(env, uid, { role });
  return json({ ok: true, role });
}

// ─────────────────────────────────────────────────────────────
// createLinkCode — genera código de vinculación
// ─────────────────────────────────────────────────────────────

async function handleCreateLinkCode(env, uid, body) {
  const { studentId, kind } = body || {};
  if (!studentId || !['child-device', 'teacher'].includes(kind)) {
    return errorJson('Parámetros inválidos.');
  }

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const parentIds = student.data.parentIds || [];
  if (!parentIds.includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  // Reintenta si el código ya existe (createDoc falla con 409)
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = generateCode();
    try {
      await createDoc(env, 'linkCodes', code, {
        studentId,
        kind,
        createdBy: uid,
        createdAt: new Date(),
        expiresAt,
        used: false,
      });
      return json({ code, expiresInHours: 24 });
    } catch (e) {
      if (e.status !== 409) throw e;
      // colisión de código — probar otro
    }
  }
  return errorJson('No se pudo generar un código único, intenta de nuevo.', 500);
}

// ─────────────────────────────────────────────────────────────
// redeemLinkCode — canjea un código
// ─────────────────────────────────────────────────────────────

async function handleRedeemLinkCode(env, uid, body) {
  const code = String(body?.code || '').toUpperCase().trim();
  if (code.length < 6) return errorJson('Código inválido.');

  const doc = await getDoc(env, `linkCodes/${code}`);
  if (!doc) return errorJson('Código no válido.', 404);
  if (doc.data.used === true) return errorJson('El código ya fue usado.', 412);
  if (new Date(doc.data.expiresAt).getTime() < Date.now()) {
    return errorJson('El código expiró.', 412);
  }

  // Marca como usado condicionado al updateTime leído (evita doble canje
  // en carrera — si alguien más lo canjeó justo antes, esto falla con 409).
  try {
    await updateDoc(
      env,
      `linkCodes/${code}`,
      { used: true, usedBy: uid, usedAt: new Date() },
      { ifUpdateTime: doc.updateTime },
    );
  } catch (e) {
    if (e.status === 409) return errorJson('El código ya fue usado.', 412);
    throw e;
  }

  const { studentId, kind } = doc.data;

  if (kind === 'child-device') {
    const token = await createCustomToken(env, studentId, { role: 'student', studentId });
    // Best-effort: deja el claim persistente para el uid del niño
    // (el user record se crea en el primer signInWithCustomToken).
    await setCustomClaims(env, studentId, { role: 'student', studentId }).catch(() => {});
    return json({ token, studentId });
  }

  // kind === 'teacher': el canjeador debe ser profesor
  const caller = await lookupUser(env, uid);
  if (caller?.customClaims?.role !== 'teacher') {
    return errorJson('Este código es para cuentas de profesor.', 403);
  }
  await arrayUnion(env, `students/${studentId}`, 'teacherIds', [uid]);
  return json({ studentId });
}

// ─────────────────────────────────────────────────────────────
// sendPush — la app llama esto directo en vez de escribir push_queue
// ─────────────────────────────────────────────────────────────

async function handleSendPush(env, uid, body) {
  const { targetUids, title, body: message, data, channelId } = body || {};
  if (!Array.isArray(targetUids) || targetUids.length === 0 || !title || !message) {
    return errorJson('Parámetros inválidos.');
  }
  const result = await pushToUids(env, targetUids, { title, body: message, data, channelId });
  return json(result);
}

// ─────────────────────────────────────────────────────────────
// checkWellnessTimeouts — cierra check-ins vencidos y alerta a padres
// ─────────────────────────────────────────────────────────────

async function checkWellnessTimeouts(env) {
  const pending = await collectionGroupQuery(
    env,
    'wellnessChecks',
    [
      { field: 'status', op: 'EQUAL', value: 'pending' },
      { field: 'expiresAt', op: 'LESS_THAN_OR_EQUAL', value: new Date() },
    ],
    50,
  ).catch((e) => {
    console.error('checkWellnessTimeouts query:', e.message);
    return [];
  });

  for (const doc of pending) {
    try {
      const studentRelPath = parentStudentPath(doc.path);
      await updateDoc(env, doc.path.split('/documents/')[1], {
        status: 'no_response',
        closedAt: new Date(),
      });

      const student = await getDoc(env, studentRelPath);
      if (!student) continue;
      const parentIds = student.data.parentIds || [];
      const name = student.data.name || 'tu hijo/a';

      await pushToUids(env, parentIds, {
        title: '⚠️ Sin respuesta al check-in',
        body:
          `${name} no respondió "¿Estás bien?" en 3 minutos. ` +
          'Puede ser falta de conexión o batería. Revisa su última ubicación.',
        data: { type: 'wellness_timeout', studentId: student.id },
        channelId: 'edutrack_urgent',
      });
    } catch (e) {
      console.error('wellnessTimeout doc:', e.message);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// checkSeismicActivity — feed USGS cada minuto (Google no expone
// una API pública de sismos; USGS es la fuente abierta estándar).
// ─────────────────────────────────────────────────────────────

const USGS_FEED = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_hour.geojson';
const SEISMIC_RADIUS_KM = 300;

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) * Math.cos((lat2 * Math.PI) / 180) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

async function checkSeismicActivity(env) {
  let feed;
  try {
    const res = await fetch(USGS_FEED);
    feed = await res.json();
  } catch (e) {
    console.warn('USGS feed error:', e.message);
    return;
  }

  const quakes = feed.features || [];
  if (quakes.length === 0) return;

  // Dedupe primero: createDoc falla con 409 si ya vimos este sismo,
  // así el caso típico (sin sismos nuevos) casi no toca Firestore.
  const newQuakes = [];
  for (const quake of quakes) {
    const id = quake.id;
    const [lng, lat] = quake.geometry?.coordinates || [];
    const mag = quake.properties?.mag;
    const place = quake.properties?.place || '';
    if (typeof lat !== 'number' || typeof lng !== 'number') continue;

    try {
      await createDoc(env, 'seismicEvents', id, {
        magnitude: mag,
        lat,
        lng,
        place,
        ts: new Date(),
        expireAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      });
      newQuakes.push({ id, lat, lng, mag, place });
    } catch (e) {
      if (e.status !== 409) console.error('seismicEvents create:', e.message);
      // 409 = ya procesado, ignorar
    }
  }
  if (newQuakes.length === 0) return;

  // Ubicaciones actuales de estudiantes (solo si hay sismos nuevos)
  const currents = await collectionGroupQuery(env, 'locations', [], 200).catch(() => []);
  const studentLocations = [];
  for (const doc of currents) {
    if (doc.id !== 'current') continue;
    const studentId = parentStudentPath(doc.path).split('/')[1];
    const { lat, lng } = doc.data;
    if (typeof lat === 'number' && typeof lng === 'number') {
      studentLocations.push({ studentId, lat, lng });
    }
  }

  for (const { id, lat, lng, mag, place } of newQuakes) {
    for (const loc of studentLocations) {
      const dist = haversineKm(lat, lng, loc.lat, loc.lng);
      if (dist > SEISMIC_RADIUS_KM) continue;

      const student = await getDoc(env, `students/${loc.studentId}`);
      if (!student) continue;

      const seismicCfg = student.data.seismicAlerts || {};
      const enabled = seismicCfg.enabled !== false;
      const minMag = typeof seismicCfg.minMagnitude === 'number' ? seismicCfg.minMagnitude : 4.5;
      if (!enabled || mag < minMag) continue;

      const parentIds = student.data.parentIds || [];
      await pushToUids(env, [loc.studentId, ...parentIds], {
        title: `🌍 Sismo M${mag} detectado`,
        body:
          `Sismo de magnitud ${mag} cerca de ${place} (a ~${Math.round(dist)} km). ` +
          'Mantén la calma, aléjate de ventanas y objetos que puedan caer.',
        data: { type: 'seismic', quakeId: id },
        channelId: 'edutrack_urgent',
      });
    }
  }
}
