# EduTrack API — Cloudflare Workers

Reemplaza a las Cloud Functions de Firebase (que exigían el plan Blaze / tarjeta). Corre en el **free tier de Cloudflare Workers, que no pide tarjeta para crear la cuenta**. Firestore/Auth/Storage/FCM siguen siendo de Firebase (plan Spark, gratis, tampoco pide tarjeta) — este Worker solo les habla por su API REST en vez de usar el SDK de Admin (que solo corre en Node con Blaze).

## Qué hace

| Ruta / trigger | Reemplaza a |
|---|---|
| `POST /register-role` | Cloud Function `registerRole` |
| `POST /create-link-code` | Cloud Function `createLinkCode` |
| `POST /redeem-link-code` | Cloud Function `redeemLinkCode` |
| `POST /send-push` | Cloud Function `sendQueuedPush` (ahora la app llama directo en vez de escribir en `push_queue`) |
| Cron cada 1 min | `checkWellnessTimeouts` + `checkSeismicActivity` |

## Configuración (una sola vez)

### 1. Cuenta de Cloudflare (gratis, sin tarjeta)

Crea una cuenta en [cloudflare.com](https://dash.cloudflare.com/sign-up) con tu email — no pide tarjeta para el plan free de Workers.

### 2. Descargar la clave del service account de Firebase

Este paso es en la consola de Firebase (no en la terminal):

1. Ve a [console.firebase.google.com/project/edutrack-family/settings/serviceaccounts/adminsdk](https://console.firebase.google.com/project/edutrack-family/settings/serviceaccounts/adminsdk)
2. Clic en **"Generar nueva clave privada"** → descarga un archivo `.json`
3. Guárdalo en tu máquina fuera del repo (ej. `~/edutrack-service-account.json`) — **nunca lo subas a git**

### 3. Instalar wrangler y autenticar con Cloudflare

```bash
cd workers/edutrack-api
npm install
npx wrangler login          # abre el navegador, inicia sesión con tu cuenta Cloudflare
```

### 4. Cargar los secretos (nunca pasan por el chat ni por git)

Abre el `.json` que descargaste y copia dos valores: `client_email` y `private_key`. Luego, en tu terminal:

```bash
npx wrangler secret put FIREBASE_CLIENT_EMAIL
# pega el valor de client_email cuando lo pida

npx wrangler secret put FIREBASE_PRIVATE_KEY
# pega el valor completo de private_key (incluye las líneas
# -----BEGIN PRIVATE KEY----- ... -----END PRIVATE KEY-----)
```

`FIREBASE_PROJECT_ID` ya está en `wrangler.toml` (no es secreto).

### 5. Desplegar

```bash
npm run deploy
```

Te da una URL tipo `https://edutrack-family-api.<tu-usuario>.workers.dev` — esa es la que va en `lib/core/config/api_config.dart` del proyecto Flutter (`kApiBaseUrl`).

## Desarrollo local

```bash
npm run dev
```

Levanta el Worker en `http://localhost:8787` con los mismos secretos (wrangler los inyecta desde Cloudflare). Usa `curl` o Postman con un ID token real de Firebase (cópialo desde los logs de la app en modo debug) para probar cada ruta.

## Logs en producción

```bash
npm run tail
```

Muestra los `console.log`/`console.error` de las invocaciones en vivo.
