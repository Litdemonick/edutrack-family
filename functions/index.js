// ═══════════════════════════════════════════════════════════════
// CLOUD FUNCTIONS — EduTrack Family 2.0 (Node 20, Functions v2)
//
//  registerRole          callable — asigna custom claim parent|teacher
//  createLinkCode        callable — código de vinculación (hijo/profesor)
//  redeemLinkCode        callable — canjea código → custom token del niño
//                                    o vincula a un profesor
//  sendQueuedPush        trigger  — entrega push_queue vía FCM (por uid)
//  checkWellnessTimeouts schedule — cierra check-ins "¿estás bien?" vencidos
//  checkSeismicActivity  schedule — vigila sismos (feed USGS) y alerta
// ═══════════════════════════════════════════════════════════════

const admin = require('firebase-admin');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────

/** Genera un código de 6 caracteres sin ambiguos (sin 0/O/1/I/L). */
function generateCode() {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

/** Tokens FCM de una lista de uids, con referencia a su doc. */
async function tokensForUids(uids) {
  const tokens = [];
  for (const uid of uids) {
    const devices = await db.collection(`users/${uid}/devices`).get();
    for (const doc of devices.docs) {
      const token = doc.get('token');
      if (typeof token === 'string' && token.length > 0) {
        tokens.push({ token, ref: doc.ref });
      }
    }
  }
  return tokens;
}

/** Envía una multicast FCM y poda los tokens muertos. */
async function sendToTokens(tokenEntries, { title, body, data = {}, channelId = 'edutrack_system' }) {
  if (tokenEntries.length === 0) return { sent: 0, failed: 0 };

  const response = await admin.messaging().sendEachForMulticast({
    tokens: tokenEntries.map((t) => t.token),
    notification: { title, body },
    data,
    android: {
      priority: 'high',
      notification: {
        channelId,
        sound: 'edutrack_notification',
      },
    },
    apns: {
      payload: { aps: { sound: 'default', contentAvailable: true } },
    },
  });

  // Podar tokens inválidos
  const prunes = [];
  response.responses.forEach((res, i) => {
    if (!res.success) {
      const code = res.error?.code || '';
      if (
        code.includes('registration-token-not-registered') ||
        code.includes('invalid-argument')
      ) {
        prunes.push(tokenEntries[i].ref.delete().catch(() => {}));
      }
    }
  });
  await Promise.all(prunes);

  return { sent: response.successCount, failed: response.failureCount };
}

/** Encola + envía directamente una push a uids (uso interno). */
async function pushToUids(uids, payload) {
  const tokens = await tokensForUids(uids);
  return sendToTokens(tokens, payload);
}

// ─────────────────────────────────────────────────────────────
// registerRole — custom claim para adultos
// ─────────────────────────────────────────────────────────────

exports.registerRole = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión primero.');

  const role = request.data?.role;
  if (role !== 'parent' && role !== 'teacher') {
    throw new HttpsError('invalid-argument', 'Rol no permitido.');
  }

  const user = await admin.auth().getUser(uid);
  if (user.providerData.length === 0) {
    // Cuentas anónimas no pueden reclamar rol de adulto
    throw new HttpsError('failed-precondition', 'Cuenta no válida para este rol.');
  }

  const existingRole = user.customClaims?.role;
  if (existingRole && existingRole !== role) {
    throw new HttpsError(
      'failed-precondition',
      'Esta cuenta ya tiene un rol asignado.'
    );
  }

  await admin.auth().setCustomUserClaims(uid, { role });
  logger.info(`registerRole: ${uid} → ${role}`);
  return { ok: true, role };
});

// ─────────────────────────────────────────────────────────────
// createLinkCode — genera código de vinculación
// ─────────────────────────────────────────────────────────────

exports.createLinkCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión primero.');

  const { studentId, kind } = request.data || {};
  if (!studentId || !['child-device', 'teacher'].includes(kind)) {
    throw new HttpsError('invalid-argument', 'Parámetros inválidos.');
  }

  // Solo un padre del estudiante puede generar códigos
  const studentSnap = await db.doc(`students/${studentId}`).get();
  if (!studentSnap.exists) {
    throw new HttpsError('not-found', 'El estudiante no existe.');
  }
  const parentIds = studentSnap.get('parentIds') || [];
  if (!parentIds.includes(uid)) {
    throw new HttpsError('permission-denied', 'No eres tutor de este estudiante.');
  }

  // Generar código único (reintenta si colisiona)
  let code = generateCode();
  for (let i = 0; i < 5; i++) {
    const existing = await db.doc(`linkCodes/${code}`).get();
    if (!existing.exists || existing.get('used') === true) break;
    code = generateCode();
  }

  await db.doc(`linkCodes/${code}`).set({
    studentId,
    kind,
    createdBy: uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromMillis(
      Date.now() + 24 * 60 * 60 * 1000
    ),
    used: false,
  });

  logger.info(`createLinkCode: ${code} (${kind}) para ${studentId} por ${uid}`);
  return { code, expiresInHours: 24 };
});

// ─────────────────────────────────────────────────────────────
// redeemLinkCode — canjea un código
// ─────────────────────────────────────────────────────────────

exports.redeemLinkCode = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Inicia sesión primero.');

  const code = String(request.data?.code || '').toUpperCase().trim();
  if (code.length < 6) {
    throw new HttpsError('invalid-argument', 'Código inválido.');
  }

  const result = await db.runTransaction(async (tx) => {
    const ref = db.doc(`linkCodes/${code}`);
    const snap = await tx.get(ref);

    if (!snap.exists) {
      throw new HttpsError('not-found', 'Código no válido.');
    }
    const data = snap.data();
    if (data.used === true) {
      throw new HttpsError('failed-precondition', 'El código ya fue usado.');
    }
    if (data.expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('failed-precondition', 'El código expiró.');
    }

    tx.update(ref, {
      used: true,
      usedBy: uid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { studentId: data.studentId, kind: data.kind };
  });

  if (result.kind === 'child-device') {
    // Sesión del niño: custom token con uid = studentId
    const token = await admin.auth().createCustomToken(result.studentId, {
      role: 'student',
      studentId: result.studentId,
    });
    // Asegurar claim persistente en el usuario del niño
    try {
      await admin.auth().setCustomUserClaims(result.studentId, {
        role: 'student',
        studentId: result.studentId,
      });
    } catch (_) {
      // El user record del niño se crea en el primer signInWithCustomToken;
      // el claim del token vale para esta sesión y se reintenta después.
    }
    logger.info(`redeemLinkCode: dispositivo vinculado a ${result.studentId}`);
    return { token, studentId: result.studentId };
  }

  // kind === 'teacher': el canjeador debe ser profesor
  const caller = await admin.auth().getUser(uid);
  if (caller.customClaims?.role !== 'teacher') {
    throw new HttpsError(
      'permission-denied',
      'Este código es para cuentas de profesor.'
    );
  }
  await db.doc(`students/${result.studentId}`).update({
    teacherIds: admin.firestore.FieldValue.arrayUnion(uid),
  });
  logger.info(`redeemLinkCode: profesor ${uid} vinculado a ${result.studentId}`);
  return { studentId: result.studentId };
});

// ─────────────────────────────────────────────────────────────
// sendQueuedPush — entrega la cola push_queue vía FCM
// Acepta targetUids (v2) y targetRole (compat v1, ignorado si hay uids)
// ─────────────────────────────────────────────────────────────

exports.sendQueuedPush = onDocumentCreated('push_queue/{pushId}', async (event) => {
  const snap = event.data;
  if (!snap) return;

  const push = snap.data();
  const title = push.title || 'EduTrack';
  const body = push.body || '';
  const targetUids = Array.isArray(push.targetUids) ? push.targetUids : [];

  if (targetUids.length === 0 || !body) {
    await snap.ref.set(
      {
        processed: true,
        error: targetUids.length === 0 ? 'Sin targetUids' : 'Sin body',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    return;
  }

  const data = {};
  for (const [k, v] of Object.entries(push.data || {})) data[k] = String(v);
  if (push.payload) data.payload = String(push.payload);

  const { sent, failed } = await pushToUids(targetUids, {
    title,
    body,
    data,
    channelId: push.channelId || 'edutrack_system',
  });

  await snap.ref.set(
    {
      processed: true,
      sent,
      failed,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
});

// ─────────────────────────────────────────────────────────────
// checkWellnessTimeouts — cada minuto cierra check-ins vencidos
// y alerta a los padres si el niño no respondió en 3 minutos.
// ─────────────────────────────────────────────────────────────

exports.checkWellnessTimeouts = onSchedule('every 1 minutes', async () => {
  const now = admin.firestore.Timestamp.now();

  const pending = await db
    .collectionGroup('wellnessChecks')
    .where('status', '==', 'pending')
    .where('expiresAt', '<=', now)
    .limit(50)
    .get();

  for (const doc of pending.docs) {
    const studentRef = doc.ref.parent.parent;
    if (!studentRef) continue;

    await doc.ref.update({
      status: 'no_response',
      closedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const student = await studentRef.get();
    const parentIds = student.get('parentIds') || [];
    const name = student.get('name') || 'tu hijo/a';

    await pushToUids(parentIds, {
      title: '⚠️ Sin respuesta al check-in',
      body:
        `${name} no respondió "¿Estás bien?" en 3 minutos. ` +
        'Puede ser falta de conexión o batería. Revisa su última ubicación.',
      data: { type: 'wellness_timeout', studentId: studentRef.id },
      channelId: 'edutrack_urgent',
    });
    logger.info(`wellnessTimeout: ${studentRef.id} check ${doc.id}`);
  }
});

// ─────────────────────────────────────────────────────────────
// checkSeismicActivity — cada minuto consulta el feed USGS
// (M ≥ 4.5, última hora) y alerta a familias cercanas al epicentro.
// Nota: el sistema de alertas de Google no tiene API pública;
// USGS es la fuente abierta estándar. Complementa, no sustituye.
// ─────────────────────────────────────────────────────────────

const USGS_FEED =
  'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_hour.geojson';
const SEISMIC_RADIUS_KM = 300;

function haversineKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

exports.checkSeismicActivity = onSchedule('every 1 minutes', async () => {
  let feed;
  try {
    const res = await fetch(USGS_FEED);
    feed = await res.json();
  } catch (e) {
    logger.warn(`USGS feed error: ${e.message}`);
    return;
  }

  const quakes = feed.features || [];
  if (quakes.length === 0) return;

  // 1. Dedupe primero: quedarnos solo con sismos NUEVOS
  //    (así el caso típico —sin sismos nuevos— casi no lee Firestore)
  const newQuakes = [];
  for (const quake of quakes) {
    const id = quake.id;
    const [lng, lat] = quake.geometry?.coordinates || [];
    const mag = quake.properties?.mag;
    const place = quake.properties?.place || '';
    if (typeof lat !== 'number' || typeof lng !== 'number') continue;

    const seenRef = db.doc(`seismicEvents/${id}`);
    const seen = await seenRef.get();
    if (seen.exists) continue;

    await seenRef.set({
      magnitude: mag,
      lat,
      lng,
      place,
      ts: admin.firestore.FieldValue.serverTimestamp(),
      expireAt: admin.firestore.Timestamp.fromMillis(
        Date.now() + 7 * 24 * 60 * 60 * 1000
      ),
    });
    newQuakes.push({ id, lat, lng, mag, place });
  }
  if (newQuakes.length === 0) return;

  // 2. Ubicaciones actuales de estudiantes (solo si hay sismos nuevos)
  const currents = await db
    .collectionGroup('locations')
    .get()
    .catch(() => null);
  const studentLocations = [];
  if (currents) {
    for (const doc of currents.docs) {
      if (doc.id !== 'current') continue;
      const studentRef = doc.ref.parent.parent;
      if (!studentRef) continue;
      const lat = doc.get('lat');
      const lng = doc.get('lng');
      if (typeof lat === 'number' && typeof lng === 'number') {
        studentLocations.push({ studentId: studentRef.id, lat, lng });
      }
    }
  }

  for (const { id, lat, lng, mag, place } of newQuakes) {
    // ¿Alguna familia cerca del epicentro?
    for (const loc of studentLocations) {
      const dist = haversineKm(lat, lng, loc.lat, loc.lng);
      if (dist > SEISMIC_RADIUS_KM) continue;

      const student = await db.doc(`students/${loc.studentId}`).get();
      if (!student.exists) continue;

      // Respeta la configuración de la familia (activado/desactivado
      // y magnitud mínima) — activado por defecto si nunca se tocó.
      const seismicCfg = student.get('seismicAlerts') || {};
      const enabled = seismicCfg.enabled !== false;
      const minMag = typeof seismicCfg.minMagnitude === 'number'
        ? seismicCfg.minMagnitude
        : 4.5;
      if (!enabled || mag < minMag) continue;

      const parentIds = student.get('parentIds') || [];
      const targets = [loc.studentId, ...parentIds];

      await pushToUids(targets, {
        title: `🌍 Sismo M${mag} detectado`,
        body:
          `Sismo de magnitud ${mag} cerca de ${place} ` +
          `(a ~${Math.round(dist)} km). Mantén la calma, aléjate de ` +
          'ventanas y objetos que puedan caer.',
        data: { type: 'seismic', quakeId: id },
        channelId: 'edutrack_urgent',
      });
      logger.info(`seismic: alertado ${loc.studentId} — M${mag} ${place}`);
    }
  }
});
