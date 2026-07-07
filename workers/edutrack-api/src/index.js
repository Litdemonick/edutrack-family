import { verifyIdToken, AuthError } from './lib/auth-verify.js';
import {
  getDoc,
  createDoc,
  updateDoc,
  setDoc,
  deleteDoc,
  arrayUnion,
  arrayRemove,
  collectionGroupQuery,
  queryCollection,
  listSubcollectionDocs,
  batchDelete,
  parentStudentPath,
} from './lib/firestore.js';
import { createCustomToken } from './lib/google-auth.js';
import {
  lookupUser,
  setCustomClaims,
  sendConfirmationEmail,
  verifyConfirmationCode,
} from './lib/identity.js';
import { pushToUids } from './lib/fcm.js';

// ═══════════════════════════════════════════════════════════════
// EDUTRACK API — Cloudflare Worker (gratis, sin tarjeta)
// Reemplaza las Cloud Functions de Firebase (que exigían Blaze).
//
// Rutas HTTP (todas requieren Authorization: Bearer <ID token Firebase>):
//   POST /register-role         { role: 'parent'|'teacher' }
//   POST /create-link-code      { studentId, kind: 'child-device'|'teacher', forceNew? }
//                                Modelo "permanente hasta revocar": una vez
//                                canjeado, el código sigue sirviendo para volver
//                                a entrar tras cerrar sesión — no vence por tiempo,
//                                solo se invalida con forceNew (regenerar), que
//                                además revoca lo ya otorgado (cierra al hijo /
//                                quita al profesor).
//   POST /link-code-status      { studentId } → { childActive, teacherActive }
//   POST /redeem-link-code      { code }
//   POST /linked-teachers       { studentId } → { teachers: [{uid, displayName, email}] }
//                                Resuelve teacherIds vía el service account —
//                                un padre no puede leer users/{otroUid} directo
//                                (firestore.rules solo permite leer el propio).
//   POST /leave-student         { studentId } — el PROFESOR se desvincula de
//                                un hijo/a por su cuenta (arrayRemove en
//                                teacherIds) — avisa por push al padre/tutor
//                                y al estudiante.
//   POST /check-cedula          { cedula, excludeStudentId? } → { available }
//                                Consulta students en TODA la app (no solo los
//                                hijos del que pregunta) — el cliente no puede
//                                hacer esa query directo (firestore.rules solo
//                                deja leer los hijos propios).
//   POST /register-device       { installId, token, platform } — reclama el
//                                token para el uid actual, borrando el
//                                registro de cualquier OTRO uid que antes
//                                tuviera esa misma instalación (mismo
//                                dispositivo, cuenta distinta) — el cliente
//                                no puede borrar el registro ajeno, solo el
//                                Worker con el service account.
//   POST /send-push             { targetUids, title, body, data?, channelId? }
//   POST /upload-profile-photo  body: bytes crudos de la imagen (Content-Type: image/*)
//                                también marca photoUpdatedAt (students o users
//                                según corresponda) — el cliente ya no lo hace.
//   POST /get-profile-photo     { uid } → responde bytes crudos (Content-Type: image/jpeg)
//   POST /delete-student        { studentId, requestId } — borra el perfil Y
//                                todo su subárbol (tareas, eventos, horario,
//                                evidencias, ubicación, zonas, check-ins,
//                                códigos) — algunas de esas subcolecciones NO
//                                se pueden borrar desde el cliente (storage.rules
//                                solo deja escribir locations al propio hijo),
//                                por eso pasa por acá con el service account,
//                                que ignora esas reglas. requestId debe venir de
//                                un /request-delete-confirmation ya confirmado
//                                (por correo) — si no, rechaza el borrado.
//   POST /request-delete-confirmation  { studentId } → { requestId, email }
//                                Manda un correo con un link de confirmación
//                                (reusa EMAIL_SIGNIN de Firebase, gratis, sin
//                                servicio de correo aparte) — hay que abrirlo
//                                antes de que /delete-student acepte el borrado.
//   POST /delete-confirmation-status  { requestId } → { confirmed }
//   GET  /confirm-delete        ?requestId=...&oobCode=... — el link del
//                                correo llega aquí, sin token (clic de
//                                navegador) — verifica el oobCode y marca el
//                                requestId como confirmado. Devuelve HTML.
//   POST /upload-task-image     ?studentId=&taskId=&kind=evidence|reference&name=
//                                body: bytes crudos de la imagen. evidence solo
//                                la sube el propio hijo; reference el padre/
//                                profesor.
//   POST /list-task-images      { studentId, taskId, kind } → { names: [...] }
//   POST /get-task-image        { studentId, taskId, kind, name } → bytes crudos
//   POST /delete-task-images    { studentId, taskId, kind } — borra todas las de
//                                ese tipo (re-subida limpia, sin acumular).
//
// Fotos de perfil Y fotos de evidencia/referencia de tareas van a
// Cloudflare R2 (no Firebase Storage — nunca se activó en la consola
// del proyecto; R2 evita esa dependencia y tiene su propio free tier
// de 10GB sin tarjeta). Fotos de perfil: un solo objeto fijo por
// usuario (profiles/{uid}/photo.jpg), cada subida sobreescribe el
// mismo archivo. Fotos de tarea: se borran todas las del mismo tipo
// antes de subir las nuevas (ver /delete-task-images), tampoco
// acumulan versiones viejas de la MISMA tarea.
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

// 10 caracteres (antes 6): con el código de un solo uso y 24h de
// vigencia, 6 era razonable — pero para que "regenerar" tenga sentido
// como control de seguridad real, un código más largo hace inviable
// adivinarlo por fuerza bruta en ese tiempo.
const CODE_LENGTH = 10;

function generateCode() {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789'; // sin 0/O/1/I/L
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) code += alphabet[Math.floor(Math.random() * alphabet.length)];
  return code;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: CORS_HEADERS });
    }

    const url = new URL(request.url);
    const { pathname, searchParams } = url;

    // Ruta especial: clic desde el correo de confirmación de borrado.
    // Es un GET normal de navegador (no lleva Bearer token) y devuelve
    // HTML, no JSON — se maneja antes que todo lo demás.
    if (request.method === 'GET' && pathname === '/confirm-delete') {
      return await handleConfirmDelete(env, searchParams);
    }

    if (request.method !== 'POST') {
      return errorJson('Método no permitido', 405);
    }

    try {
      const { uid } = await verifyIdToken(request, env.FIREBASE_PROJECT_ID);

      // Body crudo (bytes de imagen, no JSON) — antes de tocar
      // request.json() en cualquier otra rama, porque el body de un
      // Request solo se puede leer una vez.
      if (pathname === '/upload-profile-photo') {
        return await handleUploadProfilePhoto(env, uid, request);
      }
      if (pathname === '/upload-task-image') {
        return await handleUploadTaskImage(env, uid, request, searchParams);
      }

      const body = await request.json().catch(() => ({}));

      switch (pathname) {
        case '/register-role':
          return await handleRegisterRole(env, uid, body);
        case '/create-link-code':
          return await handleCreateLinkCode(env, uid, body);
        case '/redeem-link-code':
          return await handleRedeemLinkCode(env, uid, body);
        case '/register-device':
          return await handleRegisterDevice(env, uid, body);
        case '/send-push':
          return await handleSendPush(env, uid, body);
        case '/get-profile-photo':
          return await handleGetProfilePhoto(env, uid, body);
        case '/list-task-images':
          return await handleListTaskImages(env, uid, body);
        case '/get-task-image':
          return await handleGetTaskImage(env, uid, body);
        case '/delete-task-images':
          return await handleDeleteTaskImages(env, uid, body);
        case '/link-code-status':
          return await handleLinkCodeStatus(env, uid, body);
        case '/linked-teachers':
          return await handleLinkedTeachers(env, uid, body);
        case '/leave-student':
          return await handleLeaveStudent(env, uid, body);
        case '/check-cedula':
          return await handleCheckCedula(env, uid, body);
        case '/delete-student':
          return await handleDeleteStudent(env, uid, body);
        case '/request-delete-confirmation':
          return await handleRequestDeleteConfirmation(env, uid, body, url.origin);
        case '/delete-confirmation-status':
          return await handleDeleteConfirmationStatus(env, uid, body);
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
    ctx.waitUntil(checkStorageQuota(env));
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
  const { studentId, kind, forceNew } = body || {};
  if (!studentId || !['child-device', 'teacher'].includes(kind)) {
    return errorJson('Parámetros inválidos.');
  }

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const parentIds = student.data.parentIds || [];
  if (!parentIds.includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  // Un código, una vez canjeado la PRIMERA vez, queda vigente
  // permanentemente (para poder volver a entrar tras cerrar sesión sin
  // pedirle uno nuevo al padre cada vez) hasta que se regenere a
  // propósito — "revoked" es la única forma de matarlo antes de eso.
  // Antes del primer canje, sigue aplicando la ventana normal de 24h.
  // Filtro solo por igualdad (studentId/kind/revoked) para no
  // necesitar un índice compuesto.
  const candidates = await queryCollection(
    env,
    'linkCodes',
    [
      { field: 'studentId', op: 'EQUAL', value: studentId },
      { field: 'kind', op: 'EQUAL', value: kind },
      { field: 'revoked', op: 'EQUAL', value: false },
    ],
    10,
  ).catch((e) => {
    console.error('createLinkCode query existentes:', e.message);
    return [];
  });

  const now = Date.now();
  const stillValid = candidates.find(
    (doc) => doc.data.firstRedeemedAt || new Date(doc.data.expiresAt).getTime() > now,
  );

  if (forceNew) {
    // Regenerar de verdad: invalidar el/los código(s) vigentes y
    // revocar cualquier acceso que ya se haya otorgado con ellos.
    for (const doc of candidates) {
      await updateDoc(env, `linkCodes/${doc.id}`, { revoked: true }).catch(() => {});
    }
    if (kind === 'child-device') {
      // El hijo con sesión activa se entera solo en su próximo chequeo
      // (RevocationGate, ver auth_provider del lado de la app) y
      // cierra sesión — Firebase no ofrece un "desconectar ya mismo"
      // instantáneo vía REST, así que esto es "casi instantáneo" (unos
      // segundos), no un corte de milisegundo.
      await updateDoc(env, `students/${studentId}`, {
        childLinkVersion: (student.data.childLinkVersion || 0) + 1,
      }).catch(() => {});
    } else {
      // Profesor(es) vinculados con el código viejo pierden acceso de
      // inmediato: en cuanto dejan de estar en teacherIds, las reglas
      // de Firestore bloquean sus lecturas en tiempo real. Además de
      // eso, se les avisa por push (y al estudiante) — antes esto
      // pasaba en silencio, sin que nadie se enterara.
      const removedTeacherIds = student.data.teacherIds || [];
      await updateDoc(env, `students/${studentId}`, { teacherIds: [] }).catch(() => {});
      if (removedTeacherIds.length > 0) {
        const studentName = student.data.name || 'un estudiante';
        await pushToUids(env, removedTeacherIds, {
          title: 'Acceso removido',
          body: `El padre/tutor cambió el código de acceso — perdiste el acceso a ${studentName}.`,
          data: { type: 'teacher_access_revoked', studentId },
        }).catch(() => {});
        await pushToUids(env, [studentId], {
          title: 'Cambio en tu cuenta',
          body: 'Tu padre/tutor actualizó los profesores con acceso a tu cuenta.',
          data: { type: 'teacher_access_revoked_student', studentId },
        }).catch(() => {});
      }
    }
  } else if (stillValid) {
    const permanent = !!stillValid.data.firstRedeemedAt;
    const expiresInHours = permanent
      ? null
      : Math.max(
          1,
          Math.round((new Date(stillValid.data.expiresAt).getTime() - now) / (60 * 60 * 1000)),
        );
    return json({ code: stillValid.id, expiresInHours, permanent });
  }

  const expiresAt = new Date(now + 24 * 60 * 60 * 1000);

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
        revoked: false,
        firstRedeemedAt: null,
      });
      return json({ code, expiresInHours: 24, permanent: false });
    } catch (e) {
      if (e.status !== 409) throw e;
      // colisión de código — probar otro
    }
  }
  return errorJson('No se pudo generar un código único, intenta de nuevo.', 500);
}

// ─────────────────────────────────────────────────────────────
// linkCodeStatus — ¿hay un código activo (hijo/profesor) para este
// estudiante ahora mismo? Lo usa la app para decidir si el botón dice
// "Vincular su celular" (no hay ninguno) o "Ver código" (ya hay uno).
// ─────────────────────────────────────────────────────────────

async function handleLinkCodeStatus(env, uid, body) {
  const { studentId } = body || {};
  if (!studentId) return errorJson('Parámetros inválidos.');

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const parentIds = student.data.parentIds || [];
  if (!parentIds.includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  const candidates = await queryCollection(
    env,
    'linkCodes',
    [
      { field: 'studentId', op: 'EQUAL', value: studentId },
      { field: 'revoked', op: 'EQUAL', value: false },
    ],
    20,
  ).catch(() => []);

  const now = Date.now();
  const isActive = (kind) =>
    candidates.some(
      (d) =>
        d.data.kind === kind &&
        (d.data.firstRedeemedAt || new Date(d.data.expiresAt).getTime() > now),
    );

  return json({
    childActive: isActive('child-device'),
    teacherActive: isActive('teacher'),
  });
}

// ─────────────────────────────────────────────────────────────
// linkedTeachers — quiénes están vinculados a este hijo/a ahora
// mismo. Pasa por acá (service account) porque firestore.rules solo
// deja a cada usuario leer su propio doc en users/{uid} — un padre
// no puede leer users/{teacherUid} directo desde el cliente.
// ─────────────────────────────────────────────────────────────

async function handleLinkedTeachers(env, uid, body) {
  const { studentId } = body || {};
  if (!studentId) return errorJson('Parámetros inválidos.');

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const parentIds = student.data.parentIds || [];
  if (!parentIds.includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  const teacherIds = student.data.teacherIds || [];
  const teachers = [];
  for (const teacherId of teacherIds) {
    const doc = await getDoc(env, `users/${teacherId}`).catch(() => null);
    teachers.push({
      uid: teacherId,
      displayName: doc?.data?.displayName || null,
      email: doc?.data?.email || null,
    });
  }
  return json({ teachers });
}

// ─────────────────────────────────────────────────────────────
// leaveStudent — el PROFESOR se desvincula por su cuenta de un
// hijo/a (a diferencia de forceNew en createLinkCode, que es el
// padre/tutor quitando a TODOS los profesores de golpe). Avisa al
// padre/tutor y al estudiante — antes no había forma de que un
// profesor dejara de ver a un estudiante sin que el padre regenerara
// el código entero.
// ─────────────────────────────────────────────────────────────

async function handleLeaveStudent(env, uid, body) {
  const studentId = body?.studentId;
  if (!studentId) return errorJson('Parámetros inválidos.');

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const teacherIds = student.data.teacherIds || [];
  if (!teacherIds.includes(uid)) {
    return errorJson('No tienes acceso a este estudiante.', 403);
  }

  await arrayRemove(env, `students/${studentId}`, 'teacherIds', [uid]);

  const teacherDoc = await getDoc(env, `users/${uid}`).catch(() => null);
  const teacherName = teacherDoc?.data?.displayName || 'Un profesor';
  const studentName = student.data.name || 'tu hijo/a';
  const parentIds = student.data.parentIds || [];

  if (parentIds.length > 0) {
    await pushToUids(env, parentIds, {
      title: 'Profesor desvinculado',
      body: `${teacherName} ya no tiene acceso a ${studentName}.`,
      data: { type: 'teacher_left', studentId },
    }).catch(() => {});
  }
  await pushToUids(env, [studentId], {
    title: 'Cambio en tu cuenta',
    body: `${teacherName} ya no tiene acceso a tu cuenta.`,
    data: { type: 'teacher_left_student', studentId },
  }).catch(() => {});

  return json({ ok: true });
}

// ─────────────────────────────────────────────────────────────
// checkCedula — ¿ya existe un hijo/a con esta cédula en TODA la
// app? (no solo entre los hijos del que pregunta — una cédula es
// un documento de identidad real, tiene que ser única globalmente).
// Pasa por acá porque firestore.rules no deja al cliente listar
// students ajenos a sus propios parentIds/teacherIds.
// ─────────────────────────────────────────────────────────────

async function handleCheckCedula(env, uid, body) {
  const cedula = String(body?.cedula || '').trim();
  if (!cedula) return errorJson('Cédula inválida.');
  if (!/^[0-9-]+$/.test(cedula)) {
    return errorJson('La cédula solo puede tener números y guiones.');
  }

  const excludeStudentId = body?.excludeStudentId || null;
  const matches = await queryCollection(
    env,
    'students',
    [{ field: 'cedula', op: 'EQUAL', value: cedula }],
    5,
  ).catch(() => []);

  const taken = matches.some((d) => d.id !== excludeStudentId);
  return json({ available: !taken });
}

// ─────────────────────────────────────────────────────────────
// redeemLinkCode — canjea un código
// ─────────────────────────────────────────────────────────────

async function handleRedeemLinkCode(env, uid, body) {
  const code = String(body?.code || '').toUpperCase().trim();
  if (code.length < 10) return errorJson('Código inválido.');

  const doc = await getDoc(env, `linkCodes/${code}`);
  if (!doc) return errorJson('Código no válido.', 404);
  if (doc.data.revoked === true) {
    return errorJson('Este código ya no es válido — pide uno nuevo.', 412);
  }
  const alreadyRedeemed = !!doc.data.firstRedeemedAt;
  if (!alreadyRedeemed && new Date(doc.data.expiresAt).getTime() < Date.now()) {
    return errorJson('El código expiró.', 412);
  }

  // Solo se marca la PRIMERA vez — de ahí en más el código queda
  // vigente indefinidamente (permite volver a entrar tras cerrar
  // sesión) hasta que el padre lo regenere.
  if (!alreadyRedeemed) {
    try {
      await updateDoc(
        env,
        `linkCodes/${code}`,
        { firstRedeemedAt: new Date() },
        { ifUpdateTime: doc.updateTime },
      );
    } catch (e) {
      // Carrera con otro canje simultáneo del mismo código: no importa,
      // ya quedó marcado por ese otro pedido — seguimos igual.
      if (e.status !== 409) throw e;
    }
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

  // Avisar a los padres/tutores y al estudiante que hay un profesor
  // nuevo con acceso — antes esto pasaba en silencio.
  const student = await getDoc(env, `students/${studentId}`).catch(() => null);
  if (student) {
    const teacherDoc = await getDoc(env, `users/${uid}`).catch(() => null);
    const teacherName = teacherDoc?.data?.displayName || 'Un profesor';
    const studentName = student.data.name || 'tu hijo/a';
    const parentIds = student.data.parentIds || [];
    if (parentIds.length > 0) {
      await pushToUids(env, parentIds, {
        title: 'Nuevo profesor vinculado',
        body: `${teacherName} ahora tiene acceso a ${studentName}.`,
        data: { type: 'teacher_linked', studentId },
      }).catch(() => {});
    }
    await pushToUids(env, [studentId], {
      title: 'Cambio en tu cuenta',
      body: `Se vinculó un nuevo profesor a tu cuenta: ${teacherName}.`,
      data: { type: 'teacher_linked_student', studentId },
    }).catch(() => {});
  }

  return json({ studentId });
}

// ─────────────────────────────────────────────────────────────
// requestDeleteConfirmation / deleteConfirmationStatus / confirmDelete
// — confirmación por correo antes de dejar borrar un hijo/a. Reusa
// el mecanismo gratis de EMAIL_SIGNIN de Firebase como forma de
// "manda un link que se auto-verifica al abrirlo" — no nos importa
// que técnicamente sea un link de inicio de sesión, solo que probar
// que el dueño de la cuenta tiene acceso a su correo antes de un
// borrado irreversible.
// ─────────────────────────────────────────────────────────────

const DELETE_CONFIRMATION_TTL_MS = 30 * 60 * 1000; // 30 min

async function handleRequestDeleteConfirmation(env, uid, body, origin) {
  const studentId = body?.studentId;
  if (!studentId) return errorJson('Parámetros inválidos.');

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  if (!(student.data.parentIds || []).includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  const caller = await lookupUser(env, uid);
  if (!caller?.email) return errorJson('No se pudo obtener tu correo.', 500);

  const requestId = generateCode();
  await createDoc(env, 'deleteConfirmations', requestId, {
    studentId,
    uid,
    email: caller.email,
    createdAt: new Date(),
    confirmed: false,
  });

  const continueUrl = `${origin}/confirm-delete?requestId=${requestId}`;
  await sendConfirmationEmail(env, caller.email, continueUrl);

  return json({ requestId, email: caller.email });
}

async function handleDeleteConfirmationStatus(env, uid, body) {
  const requestId = body?.requestId;
  if (!requestId) return errorJson('Parámetros inválidos.');

  const doc = await getDoc(env, `deleteConfirmations/${requestId}`);
  if (!doc || doc.data.uid !== uid) return errorJson('Solicitud no encontrada.', 404);

  return json({ confirmed: !!doc.data.confirmed });
}

async function handleConfirmDelete(env, searchParams) {
  const requestId = searchParams.get('requestId');
  const oobCode = searchParams.get('oobCode');
  if (!requestId || !oobCode) return htmlPage('Enlace inválido.', 400);

  const doc = await getDoc(env, `deleteConfirmations/${requestId}`);
  if (!doc) return htmlPage('Este enlace ya no es válido o expiró.', 404);
  if (doc.data.confirmed) {
    return htmlPage('Este borrado ya había sido confirmado. Puedes cerrar esta pestaña.', 200);
  }
  const age = Date.now() - new Date(doc.data.createdAt).getTime();
  if (age > DELETE_CONFIRMATION_TTL_MS) {
    return htmlPage('Este enlace expiró (30 minutos). Vuelve a la app e inténtalo de nuevo.', 410);
  }

  try {
    await verifyConfirmationCode(env, doc.data.email, oobCode);
  } catch (e) {
    return htmlPage('No se pudo verificar el enlace. Vuelve a la app e inténtalo de nuevo.', 400);
  }

  await updateDoc(env, `deleteConfirmations/${requestId}`, {
    confirmed: true,
    confirmedAt: new Date(),
  });

  return htmlPage(
    '✅ Confirmado. Ya puedes cerrar esta pestaña y volver a la app — el borrado se completará ahí.',
    200,
  );
}

function htmlPage(message, status) {
  const html = `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>EduTrack Family</title>
<style>body{font-family:sans-serif;background:#0F2744;color:#fff;display:flex;
align-items:center;justify-content:center;min-height:100vh;margin:0;padding:24px;
text-align:center}p{max-width:420px;font-size:18px;line-height:1.5}</style></head>
<body><p>${message}</p></body></html>`;
  return new Response(html, { status, headers: { 'Content-Type': 'text/html; charset=utf-8' } });
}

// ─────────────────────────────────────────────────────────────
// deleteStudent — borra el perfil y TODO su subárbol. Pasa por el
// service account (ignora storage/firestore.rules) porque algunas
// subcolecciones (locations, zoneEvents, wellnessChecks) no se
// pueden borrar desde el cliente ni siquiera siendo el guardián.
// Exige un requestId ya confirmado por correo — ver
// requestDeleteConfirmation arriba.
// ─────────────────────────────────────────────────────────────

async function handleDeleteStudent(env, uid, body) {
  const studentId = body?.studentId;
  const requestId = body?.requestId;
  if (!studentId || !requestId) return errorJson('Parámetros inválidos.');

  const confirmation = await getDoc(env, `deleteConfirmations/${requestId}`);
  if (
    !confirmation ||
    confirmation.data.uid !== uid ||
    confirmation.data.studentId !== studentId ||
    !confirmation.data.confirmed
  ) {
    return errorJson('Debes confirmar el borrado desde tu correo primero.', 412);
  }
  const age = Date.now() - new Date(confirmation.data.createdAt).getTime();
  if (age > DELETE_CONFIRMATION_TTL_MS) {
    return errorJson('La confirmación expiró — vuelve a intentarlo.', 412);
  }

  const student = await getDoc(env, `students/${studentId}`);
  if (!student) return errorJson('El estudiante no existe.', 404);
  const parentIds = student.data.parentIds || [];
  if (!parentIds.includes(uid)) {
    return errorJson('No eres tutor de este estudiante.', 403);
  }

  const base = `students/${studentId}`;
  const paths = [];

  const subcollections = [
    'tasks', 'events', 'scheduleBlocks', 'evidences', 'zones', 'zoneEvents', 'wellnessChecks',
  ];
  let taskIds = [];
  for (const col of subcollections) {
    const docs = await listSubcollectionDocs(env, base, col).catch(() => []);
    for (const d of docs) paths.push(`${base}/${col}/${d.id}`);
    if (col === 'tasks') taskIds = docs.map((d) => d.id);
  }

  // locations/current y locations/consent son docs sueltos (no hace
  // falta listarlos); locations/history/points es una subcolección
  // anidada bajo el doc "history".
  paths.push(`${base}/locations/current`, `${base}/locations/consent`);
  const historyPoints = await listSubcollectionDocs(
    env, `${base}/locations/history`, 'points',
  ).catch(() => []);
  for (const d of historyPoints) paths.push(`${base}/locations/history/points/${d.id}`);

  // Códigos de vinculación pendientes de este estudiante
  const codes = await queryCollection(env, 'linkCodes', [
    { field: 'studentId', op: 'EQUAL', value: studentId },
  ]).catch(() => []);
  for (const c of codes) paths.push(`linkCodes/${c.id}`);

  paths.push(base); // el doc del estudiante, al final

  await batchDelete(env, paths);

  // Best-effort: si el hijo tenía foto de perfil propia (dispositivo
  // con su custom token), borrarla de R2 también.
  await env.PROFILE_PHOTOS.delete(`profiles/${studentId}/photo.jpg`).catch(() => {});

  // Fotos de evidencia/referencia (R2) de cada tarea de este
  // estudiante — sin esto quedaban huérfanas para siempre, aunque
  // el hijo y sus tareas ya no existieran en ningún lado.
  for (const taskId of taskIds) {
    for (const kind of ['evidence', 'reference']) {
      const list = await env.PROFILE_PHOTOS
        .list({ prefix: `${kind}/${studentId}/${taskId}/` })
        .catch(() => null);
      if (!list) continue;
      for (const obj of list.objects) {
        await env.PROFILE_PHOTOS.delete(obj.key).catch(() => {});
      }
    }
  }

  return json({ ok: true, deletedDocs: paths.length });
}

// ─────────────────────────────────────────────────────────────
// FRENO DE CUOTA DE R2 — R2 es gratis hasta 10GB, pero pide tarjeta
// para activarse (a diferencia de Firebase Storage), así que pasarse
// del límite SÍ podría generar un cobro real. Este chequeo corre una
// vez al día (vía el cron) y guarda el resultado en
// systemConfig/storageQuota — si el uso total se acerca a 10GB
// (margen de seguridad: bloquea a partir de 9GB), las subidas nuevas
// se rechazan con un mensaje claro en vez de arriesgarse a cruzar la
// línea gratis. Nunca borra nada solo, y las fotos ya subidas se
// siguen viendo — solo se detienen las subidas NUEVAS.
// ─────────────────────────────────────────────────────────────

const STORAGE_QUOTA_DOC = 'systemConfig/storageQuota';
const STORAGE_QUOTA_CHECK_INTERVAL_MS = 24 * 60 * 60 * 1000; // 1 vez al día
const STORAGE_QUOTA_SAFETY_BYTES = 9 * 1024 * 1024 * 1024; // bloquea desde 9GB (límite gratis real: 10GB)

async function checkStorageQuota(env) {
  try {
    const config = await getDoc(env, STORAGE_QUOTA_DOC).catch(() => null);
    const lastCheckedAt = config?.data?.lastCheckedAt
      ? new Date(config.data.lastCheckedAt).getTime()
      : 0;
    if (Date.now() - lastCheckedAt < STORAGE_QUOTA_CHECK_INTERVAL_MS) return;

    let totalBytes = 0;
    let cursor;
    do {
      const list = await env.PROFILE_PHOTOS.list({ cursor, limit: 1000 });
      for (const obj of list.objects) totalBytes += obj.size;
      cursor = list.truncated ? list.cursor : undefined;
    } while (cursor);

    const blocked = totalBytes >= STORAGE_QUOTA_SAFETY_BYTES;
    await setDoc(env, STORAGE_QUOTA_DOC, {
      lastCheckedAt: new Date().toISOString(),
      totalBytes,
      blocked,
    });
    if (blocked) {
      console.error(`[Quota] R2 cerca del límite gratis: ${totalBytes} bytes — subidas nuevas bloqueadas.`);
    }
  } catch (e) {
    console.error('checkStorageQuota:', e.message);
  }
}

/** true si hay que rechazar subidas nuevas (cerca del límite gratis de R2). */
async function isStorageBlocked(env) {
  const config = await getDoc(env, STORAGE_QUOTA_DOC).catch(() => null);
  return config?.data?.blocked === true;
}

// ─────────────────────────────────────────────────────────────
// uploadProfilePhoto / getProfilePhoto — R2, un objeto fijo por
// usuario (profiles/{uid}/photo.jpg). Subir siempre sobreescribe el
// mismo objeto — nunca se acumulan versiones viejas ni se duplica
// espacio. El uid sale del token verificado, nunca del body: nadie
// puede subir a la casilla de otro usuario. La descarga sí acepta un
// uid ajeno en el body (cualquier usuario autenticado puede ver la
// foto de cualquier otro, igual que antes con storage.rules).
// ─────────────────────────────────────────────────────────────

const MAX_PHOTO_BYTES = 2 * 1024 * 1024; // 2MB

async function handleUploadProfilePhoto(env, uid, request) {
  if (await isStorageBlocked(env)) {
    return errorJson('Almacenamiento lleno por ahora — inténtalo más tarde.', 507);
  }

  const contentType = request.headers.get('Content-Type') || '';
  if (!contentType.startsWith('image/')) {
    return errorJson('Tipo de archivo inválido.');
  }

  const bytes = await request.arrayBuffer();
  if (!bytes || bytes.byteLength === 0) {
    return errorJson('Archivo vacío.');
  }
  if (bytes.byteLength > MAX_PHOTO_BYTES) {
    return errorJson('La imagen supera el límite de 2MB.', 413);
  }

  await env.PROFILE_PHOTOS.put(`profiles/${uid}/photo.jpg`, bytes, {
    httpMetadata: { contentType: 'image/jpeg' },
  });

  // Marca "cambió la foto" para que otros dispositivos se enteren
  // (watchRawDoc de la app). Un adulto tiene doc en users/{uid} y
  // puede escribirlo él mismo desde el cliente — pero un estudiante
  // (uid == studentId) NO tiene users/{uid} y storage.rules tampoco
  // lo deja tocar su propio students/{uid} (solo el guardián puede
  // actualizarlo) — por eso este marcado pasa siempre por acá, con el
  // service account, que ignora esa restricción. Un solo campo en un
  // documento que ya existe: no crea nada nuevo, no acumula espacio.
  const updatedAt = new Date().toISOString();
  const student = await getDoc(env, `students/${uid}`).catch(() => null);
  try {
    if (student) {
      await updateDoc(env, `students/${uid}`, { photoUpdatedAt: updatedAt });
    } else {
      await setDoc(env, `users/${uid}`, { photoUpdatedAt: updatedAt });
    }
  } catch (e) {
    console.error('mark photoUpdatedAt:', e.message);
    // La foto ya subió bien — que falle el aviso no debe reportarse
    // como error al usuario, solo tarda más en verse en otros lados.
  }

  return json({ ok: true, updatedAt });
}

async function handleGetProfilePhoto(env, uid, body) {
  const targetUid = String(body?.uid || uid);
  const obj = await env.PROFILE_PHOTOS.get(`profiles/${targetUid}/photo.jpg`);
  if (!obj) return errorJson('No encontrada.', 404);

  return new Response(obj.body, {
    headers: {
      'Content-Type': obj.httpMetadata?.contentType || 'image/jpeg',
      ...CORS_HEADERS,
    },
  });
}

// ─────────────────────────────────────────────────────────────
// uploadTaskImage / listTaskImages / getTaskImage / deleteTaskImages
// — evidencia (la sube el hijo) y referencia (la sube el padre/
// profesor) de una tarea, en R2 (mismo bucket que las fotos de
// perfil, prefijo distinto: evidence/{studentId}/{taskId}/... o
// reference/{studentId}/{taskId}/...) — Firebase Storage nunca se
// activó en la consola, así que estas imágenes nunca llegaban a
// otros dispositivos (solo quedaban en el que las tomó).
// ─────────────────────────────────────────────────────────────

// En Android/iOS el cliente ya comprime a ~300KB antes de subir. En
// Windows/Linux no hay compresión disponible (flutter_image_compress
// no soporta desktop) y sube el archivo tal cual — este límite es lo
// que de verdad acota el tamaño ahí, mismo tope que las fotos de
// perfil.
const MAX_TASK_IMAGE_BYTES = 2 * 1024 * 1024;

// [version] (opcional, solo se usa con kind='evidence'): cada envío a
// revisión sube sus fotos a su PROPIA carpeta (el timestamp de esa
// entrega) en vez de sobrescribir las anteriores — antes, cada
// reenvío borraba y reemplazaba el mismo archivo, así que el
// Historial de conversación no podía mostrar las fotos de envíos
// previos en ningún dispositivo que no fuera el que las tomó (el
// archivo remoto ya no existía). Sin [version] se mantiene el
// comportamiento plano de siempre (usado por 'reference', que el
// admin edita in-place, sin historial de versiones).
function taskImagePrefix(kind, studentId, taskId, version) {
  return version
    ? `${kind}/${studentId}/${taskId}/${version}/`
    : `${kind}/${studentId}/${taskId}/`;
}

/** [forWrite] evidencia: solo el propio hijo. Referencia y lectura: guardián, profesor o el propio hijo. */
async function canAccessTaskImages(env, uid, studentId, kind, forWrite) {
  if (forWrite && kind === 'evidence') return uid === studentId;
  return canReadOrGuardian(env, uid, studentId);
}

async function canReadOrGuardian(env, uid, studentId) {
  if (uid === studentId) return true;
  const student = await getDoc(env, `students/${studentId}`).catch(() => null);
  if (!student) return false;
  const parentIds = student.data.parentIds || [];
  const teacherIds = student.data.teacherIds || [];
  return parentIds.includes(uid) || teacherIds.includes(uid);
}

/** Borrar evidencia (a diferencia de SUBIRLA) sí lo puede disparar el
 * padre/tutor o profesor — al aprobar la tarea o eliminarla, para
 * limpiar el storage remoto, no solo el propio estudiante. */
async function canDeleteTaskImages(env, uid, studentId, kind) {
  if (kind === 'evidence') return canReadOrGuardian(env, uid, studentId);
  return canAccessTaskImages(env, uid, studentId, kind, true);
}

async function handleUploadTaskImage(env, uid, request, searchParams) {
  if (await isStorageBlocked(env)) {
    return errorJson('Almacenamiento lleno por ahora — inténtalo más tarde.', 507);
  }

  const studentId = searchParams.get('studentId');
  const taskId = searchParams.get('taskId');
  const kind = searchParams.get('kind');
  const name = searchParams.get('name');
  const version = searchParams.get('version') || undefined;
  if (!studentId || !taskId || !['evidence', 'reference'].includes(kind) || !name) {
    return errorJson('Parámetros inválidos.');
  }
  if (!(await canAccessTaskImages(env, uid, studentId, kind, true))) {
    return errorJson('Sin permiso.', 403);
  }

  const contentType = request.headers.get('Content-Type') || '';
  if (!contentType.startsWith('image/')) return errorJson('Tipo de archivo inválido.');

  const bytes = await request.arrayBuffer();
  if (!bytes || bytes.byteLength === 0) return errorJson('Archivo vacío.');
  if (bytes.byteLength > MAX_TASK_IMAGE_BYTES) {
    return errorJson('La imagen supera el límite permitido.', 413);
  }

  await env.PROFILE_PHOTOS.put(`${taskImagePrefix(kind, studentId, taskId, version)}${name}`, bytes, {
    httpMetadata: { contentType: 'image/jpeg' },
  });
  return json({ ok: true });
}

async function handleListTaskImages(env, uid, body) {
  const { studentId, taskId, kind, version } = body || {};
  if (!studentId || !taskId || !['evidence', 'reference'].includes(kind)) {
    return errorJson('Parámetros inválidos.');
  }
  if (!(await canAccessTaskImages(env, uid, studentId, kind, false))) {
    return errorJson('Sin permiso.', 403);
  }
  const list = await env.PROFILE_PHOTOS.list({ prefix: taskImagePrefix(kind, studentId, taskId, version) });
  const names = list.objects.map((o) => o.key.split('/').pop());
  return json({ names });
}

async function handleGetTaskImage(env, uid, body) {
  const { studentId, taskId, kind, name, version } = body || {};
  if (!studentId || !taskId || !['evidence', 'reference'].includes(kind) || !name) {
    return errorJson('Parámetros inválidos.');
  }
  if (!(await canAccessTaskImages(env, uid, studentId, kind, false))) {
    return errorJson('Sin permiso.', 403);
  }
  const obj = await env.PROFILE_PHOTOS.get(`${taskImagePrefix(kind, studentId, taskId, version)}${name}`);
  if (!obj) return errorJson('No encontrada.', 404);
  return new Response(obj.body, {
    headers: { 'Content-Type': obj.httpMetadata?.contentType || 'image/jpeg', ...CORS_HEADERS },
  });
}

async function handleDeleteTaskImages(env, uid, body) {
  const { studentId, taskId, kind } = body || {};
  if (!studentId || !taskId || !['evidence', 'reference'].includes(kind)) {
    return errorJson('Parámetros inválidos.');
  }
  if (!(await canDeleteTaskImages(env, uid, studentId, kind))) {
    return errorJson('Sin permiso.', 403);
  }
  const list = await env.PROFILE_PHOTOS.list({ prefix: taskImagePrefix(kind, studentId, taskId) });
  for (const obj of list.objects) {
    await env.PROFILE_PHOTOS.delete(obj.key).catch(() => {});
  }
  return json({ ok: true, deleted: list.objects.length });
}

// ─────────────────────────────────────────────────────────────
// registerDevice — registra el token FCM de este instalación,
// reclamándolo exclusivamente para [uid]. Antes esto lo escribía el
// cliente directo (SDK), pero las reglas de Firestore no le dejan
// borrar el registro de OTRO usuario — así que si el mismo
// dispositivo se usó antes con otra cuenta (padre/profesor/
// estudiante) y esa sesión no cerró "limpio" (crash, force-quit),
// el token viejo quedaba activo bajo el uid anterior, y esa cuenta
// seguía recibiendo push destinadas a ella aunque el dispositivo ya
// esté en otra sesión. Con el service account sí se puede borrar el
// registro ajeno, así que esto pasa por acá: deviceOwners/{installId}
// guarda quién es el dueño ACTUAL de cada instalación; si cambia,
// se borra el registro del dueño anterior antes de escribir el nuevo.
// ─────────────────────────────────────────────────────────────

async function handleRegisterDevice(env, uid, body) {
  const { installId, token, platform } = body || {};
  if (!installId || !token) return errorJson('Parámetros inválidos.');

  const owner = await getDoc(env, `deviceOwners/${installId}`).catch(() => null);
  const previousUid = owner?.data?.uid;
  if (previousUid && previousUid !== uid) {
    await deleteDoc(env, `users/${previousUid}/devices/${installId}`).catch(() => {});
  }

  await setDoc(env, `users/${uid}/devices/${installId}`, {
    token,
    platform: platform || 'unknown',
    lastSeen: new Date(),
  });
  await setDoc(env, `deviceOwners/${installId}`, { uid, updatedAt: new Date() });

  return json({ ok: true });
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
        channelId: 'edutrack_safety',
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

const PANAMA_REF = { lat: 8.9824, lng: -79.5199 }; // Ciudad de Panamá — referencia de país cuando no hay GPS activo

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

  // TODOS los estudiantes (no solo los que tienen GPS activo en este
  // momento) — un sismo real debe avisar a toda la familia vinculada
  // (padre/tutor, profesor Y el propio estudiante), no solo a quien
  // resulta tener el rastreo de ubicación encendido justo ahora.
  const students = await queryCollection(env, 'students', [], 500).catch((e) => {
    console.error('checkSeismicActivity students query:', e.message);
    return [];
  });
  if (students.length === 0) return;

  // Ubicación en vivo conocida por estudiante, si existe, para medir
  // distancia real; si no hay GPS activo se usa Panamá como
  // referencia (la app es de un solo país) — así el sismo igual
  // dispara la alerta aunque nadie esté compartiendo ubicación.
  const currents = await collectionGroupQuery(env, 'locations', [], 200).catch(() => []);
  const locByStudent = {};
  for (const doc of currents) {
    if (doc.id !== 'current') continue;
    const studentId = parentStudentPath(doc.path).split('/')[1];
    const { lat, lng } = doc.data;
    if (typeof lat === 'number' && typeof lng === 'number') {
      locByStudent[studentId] = { lat, lng };
    }
  }

  for (const { id, lat, lng, mag, place } of newQuakes) {
    for (const student of students) {
      const loc = locByStudent[student.id] || PANAMA_REF;
      const dist = haversineKm(lat, lng, loc.lat, loc.lng);
      if (dist > SEISMIC_RADIUS_KM) continue;

      const seismicCfg = student.data.seismicAlerts || {};
      const enabled = seismicCfg.enabled !== false;
      const minMag = typeof seismicCfg.minMagnitude === 'number' ? seismicCfg.minMagnitude : 4.5;
      if (!enabled || mag < minMag) continue;

      const parentIds = student.data.parentIds || [];
      const teacherIds = student.data.teacherIds || [];
      const title = `🌍 Sismo M${mag} detectado`;
      const body =
        `Sismo de magnitud ${mag} cerca de ${place} (a ~${Math.round(dist)} km). ` +
        'Ponte en un lugar seguro, mantén la calma y espera instrucciones.';

      // Bitácora por estudiante — Windows/Linux no tiene FCM, así que
      // el cliente de escritorio la lee por polling (mientras la app
      // esté abierta) en vez de recibir push; TTL 24h vía expireAt.
      await setDoc(env, `students/${student.id}/seismicAlertsLog/${id}`, {
        title,
        body,
        magnitude: mag,
        ts: new Date(),
        expireAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
      }).catch((e) => console.error('seismicAlertsLog set:', e.message));

      await pushToUids(env, [student.id, ...parentIds, ...teacherIds], {
        title,
        body,
        data: { type: 'seismic', quakeId: id },
        channelId: 'edutrack_safety',
      });
    }
  }
}
