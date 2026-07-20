import { before, after, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

// ═══════════════════════════════════════════════════════════════
// FIRESTORE RULES TESTS — EduTrack Family 2.0
// Corre contra el Firebase Emulator Suite (ver ../firebase.json).
// No usa la cuenta real ni datos reales — todo vive en el emulador.
//
// Cómo correr (desde la raíz del repo):
//   cd firestore-rules-tests && npm install
//   cd .. && firebase emulators:exec --only firestore,storage \
//     "npm --prefix firestore-rules-tests test"
// ═══════════════════════════════════════════════════════════════

const PARENT_UID = 'parent1';
const TEACHER_UID = 'teacher1';
const STRANGER_UID = 'stranger1';
const STUDENT_ID = 'student1';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-edutrack-family-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Seed del estudiante + una tarea + una ubicación, saltando las reglas.
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, `students/${STUDENT_ID}`), {
      name: 'Estudiante de prueba',
      parentIds: [PARENT_UID],
      teacherIds: [TEACHER_UID],
    });
    await setDoc(doc(db, `students/${STUDENT_ID}/tasks/task1`), {
      title: 'Tarea de prueba',
      status: 'pending',
    });
    await setDoc(doc(db, `students/${STUDENT_ID}/locations/current`), {
      lat: 9.0,
      lng: -79.5,
    });
  });
});

describe('students/{studentId} — perfil del estudiante', () => {
  it('el padre puede leer el perfil de su hijo', async () => {
    const ctx = testEnv.authenticatedContext(PARENT_UID, { role: 'parent' });
    await assertSucceeds(getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}`)));
  });

  it('un extraño no puede leer el perfil del estudiante', async () => {
    const ctx = testEnv.authenticatedContext(STRANGER_UID, { role: 'parent' });
    await assertFails(getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}`)));
  });

  it('el profesor vinculado puede leer el perfil del estudiante', async () => {
    const ctx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertSucceeds(getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}`)));
  });

  it('el propio estudiante puede leer su perfil', async () => {
    const ctx = testEnv.authenticatedContext(STUDENT_ID, {});
    await assertSucceeds(getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}`)));
  });

  it('solo un padre puede crear el perfil de un estudiante nuevo (el profesor no)', async () => {
    const parentCtx = testEnv.authenticatedContext(PARENT_UID, { role: 'parent' });
    await assertSucceeds(
      setDoc(doc(parentCtx.firestore(), 'students/newkid'), {
        name: 'Nuevo/a',
        parentIds: [PARENT_UID],
      }),
    );

    const teacherCtx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertFails(
      setDoc(doc(teacherCtx.firestore(), 'students/newkid2'), {
        name: 'Nuevo/a 2',
        parentIds: [TEACHER_UID],
      }),
    );
  });
});

describe('tasks — tareas', () => {
  it('el profesor puede crear tareas del estudiante vinculado', async () => {
    const ctx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertSucceeds(
      setDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/tasks/task2`), {
        title: 'Tarea asignada por el profesor',
        status: 'pending',
      }),
    );
  });

  it('un extraño no puede crear tareas del estudiante', async () => {
    const ctx = testEnv.authenticatedContext(STRANGER_UID, { role: 'parent' });
    await assertFails(
      setDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/tasks/task3`), {
        title: 'Intento ajeno',
        status: 'pending',
      }),
    );
  });

  it('el estudiante puede tocar los campos de su flujo de entrega', async () => {
    const ctx = testEnv.authenticatedContext(STUDENT_ID, {});
    await assertSucceeds(
      updateDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/tasks/task1`), {
        status: 'completed',
        completionNote: 'Listo',
        updatedAt: new Date().toISOString(),
      }),
    );
  });

  it('el estudiante NO puede editar el título de una tarea', async () => {
    const ctx = testEnv.authenticatedContext(STUDENT_ID, {});
    await assertFails(
      updateDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/tasks/task1`), {
        title: 'Cambiado por el estudiante',
      }),
    );
  });
});

describe('locations — GPS (solo padre/hijo, profesor nunca)', () => {
  it('el padre puede leer la ubicación', async () => {
    const ctx = testEnv.authenticatedContext(PARENT_UID, { role: 'parent' });
    await assertSucceeds(
      getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/locations/current`)),
    );
  });

  it('el profesor NUNCA puede leer la ubicación', async () => {
    const ctx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertFails(
      getDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/locations/current`)),
    );
  });

  it('el profesor tampoco puede escribir la ubicación', async () => {
    const ctx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertFails(
      setDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/locations/current`), {
        lat: 0,
        lng: 0,
      }),
    );
  });

  it('el padre NO puede escribir la ubicación (solo el hijo la escribe)', async () => {
    const ctx = testEnv.authenticatedContext(PARENT_UID, { role: 'parent' });
    await assertFails(
      setDoc(doc(ctx.firestore(), `students/${STUDENT_ID}/locations/current`), {
        lat: 1,
        lng: 1,
      }),
    );
  });
});

describe('wellnessChecks — check-in "¿estás bien?"', () => {
  it('solo el padre puede crear un check-in (el profesor no)', async () => {
    const parentCtx = testEnv.authenticatedContext(PARENT_UID, { role: 'parent' });
    await assertSucceeds(
      setDoc(doc(parentCtx.firestore(), `students/${STUDENT_ID}/wellnessChecks/check1`), {
        status: 'pending',
        requestedBy: PARENT_UID,
      }),
    );

    const teacherCtx = testEnv.authenticatedContext(TEACHER_UID, { role: 'teacher' });
    await assertFails(
      setDoc(doc(teacherCtx.firestore(), `students/${STUDENT_ID}/wellnessChecks/check2`), {
        status: 'pending',
        requestedBy: TEACHER_UID,
      }),
    );
  });

  it('el hijo solo puede actualizar status/respondedAt', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `students/${STUDENT_ID}/wellnessChecks/check1`), {
        status: 'pending',
        requestedBy: PARENT_UID,
      });
    });

    const studentCtx = testEnv.authenticatedContext(STUDENT_ID, {});
    await assertSucceeds(
      updateDoc(doc(studentCtx.firestore(), `students/${STUDENT_ID}/wellnessChecks/check1`), {
        status: 'ok',
        respondedAt: new Date().toISOString(),
      }),
    );
  });

  it('el hijo NO puede cambiar quién lo solicitó', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `students/${STUDENT_ID}/wellnessChecks/check1`), {
        status: 'pending',
        requestedBy: PARENT_UID,
      });
    });

    const studentCtx = testEnv.authenticatedContext(STUDENT_ID, {});
    await assertFails(
      updateDoc(doc(studentCtx.firestore(), `students/${STUDENT_ID}/wellnessChecks/check1`), {
        requestedBy: STUDENT_ID,
      }),
    );
  });
});
