# Contribuir a EduTrack Family 2.0

Somos 5 personas. Para que todos podamos trabajar en paralelo sin pisarnos, el proyecto está dividido en **5 zonas** con carpetas propias. Lee tu zona, trabaja solo ahí (más `core/` si tu zona lo necesita en modo lectura), y abre PR a `dev`.

## Las 5 zonas

| Zona | Carpetas | Qué incluye |
|---|---|---|
| **A — Núcleo, Auth y Familia** (líder) | `lib/app.dart`, `lib/core/**`, `lib/features/auth/`, `lib/features/family/`, `firestore.rules`, `storage.rules`, `workers/edutrack-api/`, `.github/` | Router, base de datos, sync, autenticación, vinculación de hijos/profesores, reglas de seguridad, backend (Cloudflare Workers) |
| **B — Tareas y Evidencias** | `lib/core/features/admin/tasks/`, `lib/core/features/admin/evidence/`, `lib/core/features/student/tasks/`, `lib/core/providers/task_provider.dart` | CRUD de tareas, flujo de revisión (rechazar/reenviar/aceptar), fotos de evidencia |
| **C — Eventos, Horario, Calendario y Stats** | `lib/core/features/admin/events/`, `lib/core/features/student/events/`, `lib/core/features/student/calendar/`, `lib/core/features/*/stats/`, `lib/core/providers/event_provider.dart`, `lib/core/providers/schedule_provider.dart`, `lib/core/providers/stats_provider.dart` | Eventos escolares, horario semanal (data-driven), calendario, estadísticas |
| **D — Ubicación y Seguridad** | `lib/features/location/**`, `lib/features/safety/**` | Mapa de ubicación del hijo, zonas seguras, tracking, check-in "¿Estás bien?", pantalla de alarma sísmica |
| **E — Notificaciones y Ajustes** | `lib/core/features/notifications/`, `lib/core/features/settings/`, `lib/core/services/fcm_service.dart`, `lib/core/services/notification_bus.dart` | Historial de notificaciones, ajustes de sonido/vibración, registro de dispositivos FCM |

**Regla de acoplamiento**: B, C, D y E nunca se importan entre sí — solo importan de `core/` (zona A) y de su propia carpeta. Si necesitas algo de otra zona, pídelo en el canal del equipo; probablemente deba vivir en `core/`.

**Regla de tamaño**: ningún archivo de pantalla debe superar ~300 líneas. Si crece, descompón en una carpeta `widgets/` junto a la pantalla (mira `lib/features/family/presentation/widgets/` como ejemplo).

## Flujo de ramas

```
main   ← rama protegida, solo releases
  ↑
 dev    ← rama de integración, protegida (PR + 1 review + CI verde)
  ↑
feature/<zona>-<tema>   ← tu rama de trabajo (ej. feature/b-evidencia-multiple)
```

1. `git checkout dev && git pull`
2. `git checkout -b feature/<zona>-<tema>`
3. Commits con mensaje claro (qué cambia y por qué, no "fix" a secas)
4. `flutter analyze` y `flutter test` en verde antes de abrir el PR
5. PR contra `dev` — CI (GitHub Actions) corre analyze+test automáticamente
6. `CODEOWNERS` pedirá review al dueño de la zona que tocaste

## Levantar el entorno

```bash
flutter pub get
flutter run                    # elige el emulador/dispositivo
```

- **Sin Android/iOS a mano**: `flutter run -d windows` sirve para iterar UI — todo lo mobile-only (GPS, biometría, FCM, foreground service) está detrás de guards de plataforma y no rompe el arranque en desktop.
- **Firebase**: ya viene configurado (`firebase_options.dart`, `google-services.json`), plan **Spark (gratis, sin tarjeta)**. Si necesitas desplegar reglas: `firebase deploy --only firestore:rules` (pide acceso al proyecto `edutrack-family` al líder).
- **Backend**: no hay Cloud Functions — la lógica de servidor vive en `workers/edutrack-api/` sobre Cloudflare Workers (gratis, sin tarjeta). Solo el líder (zona A) despliega cambios ahí; ver `workers/edutrack-api/README.md`. Nunca actives el plan Blaze de Firebase — el equipo decidió evitarlo aunque sea gratis dentro de cuota, para no tener que agregar ninguna tarjeta al proyecto.
- **Firma de release Android**: cada dev genera su propio `android/key.properties` (no se versiona) — sin él, `flutter build apk --release` cae a la firma debug automáticamente, así que no bloquea el desarrollo diario.
- **Tests**: `flutter test` corre modelos + base de datos (con `sqflite_common_ffi`, no necesita emulador) + utilidades de ubicación.

## Antes de pedir review

- [ ] `flutter analyze` sin warnings
- [ ] `flutter test` en verde
- [ ] Probaste el flujo en un dispositivo/emulador real (no solo compiló)
- [ ] Si tocaste algo de `core/` fuera de tu zona, avisaste al líder
