import { getAccessToken } from './google-auth.js';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE REST — reemplazo mínimo del SDK de Admin para lo que
// necesitan nuestras 6 funciones. Formato de valores "Value" de
// la API de Firestore (https://firebase.google.com/docs/firestore/reference/rest/v1/Value).
// ═══════════════════════════════════════════════════════════════

const BASE = (projectId) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

async function authFetch(env, url, options = {}) {
  const token = await getAccessToken(env);
  const res = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  return res;
}

// ── Conversión Firestore Value ↔ JS ─────────────────────────────

function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (Array.isArray(v)) {
    return { arrayValue: { values: v.map(toValue) } };
  }
  if (typeof v === 'object') {
    const fields = {};
    for (const [k, val] of Object.entries(v)) fields[k] = toValue(val);
    return { mapValue: { fields } };
  }
  return { stringValue: String(v) };
}

function fromValue(value) {
  if (!value) return null;
  if ('nullValue' in value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(fromValue);
  if ('mapValue' in value) return fromFields(value.mapValue.fields || {});
  return null;
}

function fromFields(fields) {
  const out = {};
  for (const [k, v] of Object.entries(fields || {})) out[k] = fromValue(v);
  return out;
}

function toFields(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) fields[k] = toValue(v);
  return fields;
}

/** Convierte un doc de la respuesta REST a { id, data, updateTime, path }. */
function parseDoc(doc) {
  const id = doc.name.split('/').pop();
  return { id, path: doc.name, data: fromFields(doc.fields), updateTime: doc.updateTime };
}

// ── API ──────────────────────────────────────────────────────

/** GET de un documento por ruta relativa (ej. 'students/abc'). Null si no existe. */
export async function getDoc(env, relPath) {
  const res = await authFetch(env, `${BASE(env.FIREBASE_PROJECT_ID)}/${relPath}`);
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`Firestore GET ${relPath}: ${res.status} ${await res.text()}`);
  return parseDoc(await res.json());
}

/**
 * Crea un documento con un ID elegido por nosotros.
 * Falla con status 409 (lanzamos ese error) si ya existe — útil
 * para dedupe atómico (códigos de vinculación, eventos sísmicos).
 */
export async function createDoc(env, collectionRelPath, documentId, data) {
  const url =
    `${BASE(env.FIREBASE_PROJECT_ID)}/${collectionRelPath}?documentId=${encodeURIComponent(documentId)}`;
  const res = await authFetch(env, url, {
    method: 'POST',
    body: JSON.stringify({ fields: toFields(data) }),
  });
  if (res.status === 409) {
    const err = new Error('ALREADY_EXISTS');
    err.status = 409;
    throw err;
  }
  if (!res.ok) throw new Error(`Firestore CREATE ${collectionRelPath}: ${res.status} ${await res.text()}`);
  return parseDoc(await res.json());
}

/** PATCH de campos concretos (no pisa el resto del documento). */
export async function updateDoc(env, relPath, data, { ifUpdateTime } = {}) {
  const mask = Object.keys(data).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  let url = `${BASE(env.FIREBASE_PROJECT_ID)}/${relPath}?${mask}`;
  if (ifUpdateTime) {
    url += `&currentDocument.updateTime=${encodeURIComponent(ifUpdateTime)}`;
  }
  const res = await authFetch(env, url, {
    method: 'PATCH',
    body: JSON.stringify({ fields: toFields(data) }),
  });
  if (res.status === 409 || res.status === 400) {
    const err = new Error('PRECONDITION_FAILED');
    err.status = 409;
    throw err;
  }
  if (!res.ok) throw new Error(`Firestore PATCH ${relPath}: ${res.status} ${await res.text()}`);
  return parseDoc(await res.json());
}

/** set con merge: crea si no existe, o mezcla campos si existe. */
export async function setDoc(env, relPath, data) {
  const mask = Object.keys(data).map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`).join('&');
  const res = await authFetch(env, `${BASE(env.FIREBASE_PROJECT_ID)}/${relPath}?${mask}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields: toFields(data) }),
  });
  if (!res.ok) throw new Error(`Firestore SET ${relPath}: ${res.status} ${await res.text()}`);
  return parseDoc(await res.json());
}

/** DELETE de un documento. */
export async function deleteDoc(env, relPath) {
  const res = await authFetch(env, `${BASE(env.FIREBASE_PROJECT_ID)}/${relPath}`, { method: 'DELETE' });
  if (!res.ok && res.status !== 404) {
    throw new Error(`Firestore DELETE ${relPath}: ${res.status} ${await res.text()}`);
  }
}

/** arrayUnion atómico vía :commit (equivalente a FieldValue.arrayUnion). */
export async function arrayUnion(env, relPath, field, values) {
  const res = await authFetch(env, `${BASE(env.FIREBASE_PROJECT_ID)}:commit`, {
    method: 'POST',
    body: JSON.stringify({
      writes: [
        {
          transform: {
            document: `${BASE(env.FIREBASE_PROJECT_ID)}/${relPath}`,
            fieldTransforms: [
              { fieldPath: field, appendMissingElements: { values: values.map(toValue) } },
            ],
          },
        },
      ],
    }),
  });
  if (!res.ok) throw new Error(`Firestore arrayUnion ${relPath}: ${res.status} ${await res.text()}`);
}

/**
 * collectionGroup query (equivalente a db.collectionGroup(id).where(...)).
 * [wheres] = [{ field, op: 'EQUAL'|'LESS_THAN_OR_EQUAL', value }]
 */
export async function collectionGroupQuery(env, collectionId, wheres = [], limit = 100) {
  const filters = wheres.map((w) => ({
    fieldFilter: { field: { fieldPath: w.field }, op: w.op, value: toValue(w.value) },
  }));

  const where =
    filters.length === 0
      ? undefined
      : filters.length === 1
        ? filters[0]
        : { compositeFilter: { op: 'AND', filters } };

  const body = {
    structuredQuery: {
      from: [{ collectionId, allDescendants: true }],
      ...(where ? { where } : {}),
      limit,
    },
  };

  const res = await authFetch(env, `${BASE(env.FIREBASE_PROJECT_ID)}:runQuery`, {
    method: 'POST',
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`Firestore query ${collectionId}: ${res.status} ${await res.text()}`);

  const rows = await res.json();
  return rows.filter((r) => r.document).map((r) => parseDoc(r.document));
}

/** Ruta relativa del documento padre (students/{id}) a partir de la ruta de un hijo. */
export function parentStudentPath(childDocPath) {
  // childDocPath ej: 'projects/x/databases/(default)/documents/students/abc/wellnessChecks/def'
  const idx = childDocPath.indexOf('/students/');
  const rest = childDocPath.slice(idx + 1); // 'students/abc/wellnessChecks/def'
  const parts = rest.split('/');
  return `${parts[0]}/${parts[1]}`; // 'students/abc'
}

export { toValue, fromValue, fromFields };
