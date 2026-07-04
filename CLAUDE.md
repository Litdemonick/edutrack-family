# EduTrack Family 2.0 — Contexto del proyecto

App Flutter multi-familia (offline-first) para gestionar tareas escolares. Roles: **parent** (padre/tutor), **teacher** (profesor), **student** (hijo). Un adulto puede tener varios hijos; un hijo puede tener varios padres y profesores vinculados.

Zona horaria: `America/Panama`. Firebase project: `edutrack-family` (cuenta `diosdelsol266@gmail.com`, plan **Spark/gratis** — nunca Blaze, ver más abajo). Repo GitHub bajo la cuenta `Litdemonick`.

**Backend**: no hay Cloud Functions de Firebase (exigen el plan Blaze, que pide tarjeta). La lógica de servidor vive en `workers/edutrack-api/` sobre **Cloudflare Workers** (gratis, sin tarjeta, cron cada 1 min). Firestore/Auth/Storage/FCM siguen siendo Firebase normal (Spark), el Worker solo les habla por REST con un service account en vez de usar el SDK de Admin.

## Arquitectura de datos

Todo lo de un estudiante vive bajo `students/{studentId}/...` en Firestore (subcolecciones `tasks`, `events`, `scheduleBlocks`, `evidences`, `locations`, `zones`, `zoneEvents`, `wellnessChecks`). Un solo `get()` del doc `students/{id}` (con `parentIds[]`/`teacherIds[]`) autoriza el subárbol completo en las reglas — ver `firestore.rules`.

SQLite local (`lib/core/database/database_helper.dart`, `edutrack_v2.db`) espeja esa estructura: todas las tablas tienen `student_id` + `is_dirty` (offline-first: se escribe local primero, `is_dirty=1` marca lo pendiente de subir, `SyncService` lo sube y limpia el flag).

Rutas de Firestore **siempre** salen de `lib/core/firebase/firestore_paths.dart` — nunca hardcodear una ruta.

## Autenticación

- Adultos: email+password (con verificación obligatoria) o Google Sign-In. El rol (`parent`/`teacher`) se guarda como **custom claim** (para que las reglas lo lean sin lecturas extra) + espejo en `users/{uid}`. La ruta `/register-role` del Worker pone el claim (vía Identity Toolkit REST).
- Estudiantes **nunca se registran solos**: el padre genera un código de 6 caracteres (`/create-link-code`), el niño lo canjea (`/redeem-link-code`) y recibe un **custom token con `uid == studentId`** (firmado con `jose` usando la clave del service account) — así las reglas colapsan a `uid == studentId` sin necesitar un mapeo aparte.
- Biometría (`local_auth`) como gate de re-entrada rápida, no como reemplazo de la sesión Firebase.
- `lib/core/providers/auth_provider.dart` expone `SessionUser?` (`lib/core/data/local/models/app_user_model.dart`).
- `lib/core/services/api_client.dart` es el cliente HTTP hacia el Worker: adjunta el ID token de Firebase en cada llamada, el Worker lo verifica contra el JWKS público de Google antes de hacer nada.

## GPS y seguridad

- `lib/features/location/` — el hijo comparte ubicación solo con doble consentimiento (padre activa + hijo confirma en su teléfono, ver `location_consent.dart`). Tracking vía `flutter_foreground_task` (servicio con notificación persistente — es el indicador visible legal + lo que evita que Doze mate el proceso). Geocercas evaluadas **en el dispositivo del hijo** (no en el Worker) para no gastar invocaciones.
- `lib/features/safety/wellness_check.dart` — check-in "¿Estás bien?": el padre dispara, el hijo responde con dos botones grandes, timeout de 3 min lo cierra el cron del Worker (`checkWellnessTimeouts`, corre aunque el padre cierre su app).
- Alerta sísmica: el cron del Worker (`checkSeismicActivity`) sondea el feed público de USGS cada minuto (Google no tiene API de sismos) y alerta si hay un sismo cerca de la última ubicación conocida de un estudiante. Configurable por familia (`StudentProfile.seismicAlertsEnabled/seismicMinMagnitude`).

## Push

FCM puro (se quitó OneSignal — tenía la REST key filtrada en el código v1). `lib/core/services/fcm_service.dart` registra el token en `users/{uid}/devices/{installId}`. Toda push la manda la app llamando directo a `/send-push` en el Worker (ver `push_queue_service.dart`), que hace el fan-out por FCM HTTP v1 con poda de tokens muertos. `NotificationBus` (`lib/core/services/notification_bus.dart`) sigue siendo el único punto de entrada — nunca dispares una notificación sin pasar por él.

## Backend (Cloudflare Workers, no Cloud Functions)

`workers/edutrack-api/` — ver su `README.md` para desplegar. Motivo: las Cloud Functions de Firebase exigen el plan Blaze (pide tarjeta, aunque el costo real sea $0 dentro de la cuota gratis) — el equipo prefirió evitarlo por completo. El Worker cubre las mismas 6 operaciones que antes eran Cloud Functions (`registerRole`, `createLinkCode`, `redeemLinkCode`, `sendQueuedPush`, `checkWellnessTimeouts`, `checkSeismicActivity`), hablando con Firestore/Identity Toolkit/FCM por REST con un service account (`workers/edutrack-api/src/lib/`), en vez del SDK de Admin (que solo corre en Node/Cloud Functions). La URL del Worker desplegado vive en `lib/core/config/api_config.dart`.

## Reglas de oro

- **Nunca** escribas una ruta de Firestore a mano — usa `FirestorePaths`.
- **Nunca** dispares una notificación sin pasar por `NotificationBus`.
- Todo modelo de datos nuevo lleva `studentId` y sigue el patrón `toMap/fromMap` (SQLite) + `toFirestore/fromFirestore` (nube) que ya usan `TaskModel`/`EventModel`/`ScheduleBlock`.
- APIs solo-móvil (GPS, biometría, FCM, foreground service) siempre detrás de un guard de plataforma — el equipo también desarrolla apuntando a `flutter run -d windows` para iterar UI rápido.
- Toda tarea/evento/bloque de horario se crea con `is_dirty=1`; el `SyncService` es quien lo baja a 0 tras subir.

## Dónde mirar primero

- `lib/app.dart` — router y su cadena de guards (perfil incompleto → verificación de email → gate biométrico → shell por rol).
- `lib/core/providers/family_provider.dart` — estudiante activo / lista de vinculados, la usan casi todos los providers de contenido.
- `workers/edutrack-api/src/index.js` — las 6 operaciones de servidor (roles, códigos, push, timeouts de check-in, sismos) sobre Cloudflare Workers.
- `firestore.rules` / `storage.rules` — quién puede leer/escribir qué; cualquier feature nueva empieza revisando si necesita una regla nueva.
