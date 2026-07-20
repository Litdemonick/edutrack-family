# Tests de firestore.rules / storage.rules

Proyecto Node aislado (no toca la app Flutter) que corre las reglas de
seguridad reales contra el Firebase Emulator Suite — sin datos ni
cuenta real, todo vive en el emulador.

## Instalar

```
cd firestore-rules-tests
npm install
```

## Correr

Desde la raíz del repo (necesita `firebase-tools` instalado globalmente,
ya lo tenés — `firebase --version`):

```
firebase emulators:exec --project demo-edutrack-family-test --only firestore,storage "npm --prefix firestore-rules-tests test"
```

(El prefijo `demo-` en el project ID es intencional — es la convención de
Firebase para señalar "proyecto 100% de emulador, sin recursos reales
detrás". Sin él, las referencias cruzadas Storage→Firestore dentro de
`storage.rules` — `canAccessStudent()` usa `firestore.get(...)` — no
resuelven bien en el emulador.)

Esto levanta los emuladores de Firestore (puerto 8080) y Storage
(puerto 9199) definidos en `../firebase.json`, corre los tests con el
test runner nativo de Node (`node --test`), y apaga los emuladores al
terminar.

## Qué cubre

- `firestore.rules.test.mjs`: padre lee su hijo ✓, extraño denegado ✓,
  profesor sin locations ✓ (ni lectura ni escritura), solo el padre crea
  el perfil del estudiante, el estudiante solo puede tocar los campos
  de su flujo de entrega en `tasks`, y las restricciones de
  `wellnessChecks` (solo el padre lo crea, el hijo solo actualiza
  status/respondedAt).
- `storage.rules.test.mjs`: el hijo sube su propia evidencia, un
  extraño no puede leerla, el padre vinculado sí, y se rechaza un
  archivo que no sea imagen.
