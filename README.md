# EduTrack Family 2.0

Plataforma de gestión de tareas escolares para padres/tutores, profesores y estudiantes — offline-first, multi-familia, con ubicación segura y alertas de seguridad. Flutter + Firebase.

## Empezar

```bash
flutter pub get
flutter run
```

Requiere `lib/firebase_options.dart` (ya versionado) y `android/app/google-services.json` (ya versionado). Para firmar un release necesitas `android/key.properties` (no versionado — cada dev genera el suyo; ver `CONTRIBUTING.md`).

## Documentación

- **[CLAUDE.md](CLAUDE.md)** — arquitectura, modelo de datos, flujos de auth/GPS/notificaciones. Léelo antes de tocar `core/`.
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — las 5 zonas de trabajo del equipo, flujo de ramas/PR, cómo levantar el entorno.

## Stack

Flutter · Riverpod · go_router · SQLite (sqflite) offline-first · Firebase (Auth, Firestore, Storage, Functions, Messaging) · flutter_map/OpenStreetMap · flutter_foreground_task · local_auth.
