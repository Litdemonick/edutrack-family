# EduTrack Family — Contexto del Proyecto

## Qué es
App Flutter (Android + iOS) para organizar tareas escolares de Yordan.
App privada, solo 2 usuarios: admin (madre) y yordan (estudiante).

## Usuarios del sistema
- `admin` / `admin2024` → rol admin (madre de Yordan)
- `yordan` / `yordan2024` → rol estudiante (Yordan)
- Las contraseñas se pueden cambiar desde Ajustes; se guardan en SharedPreferences con clave `pass_<userId>`
- El login siempre pide contraseña (no hay bypass). Recuerda el último perfil usado (`last_profile_id` en SharedPreferences).

---

## Archivos principales — estado actual

### Núcleo
- `main.dart` ✅ — Firebase init, notificaciones, SharedPreferences, error handlers globales (`FlutterError.onError`, `PlatformDispatcher.instance.onError`)
- `app.dart` ✅ — GoRouter, MaterialApp, SplashScreen, auto-logout 3 min en background, status bar reactiva, `_SmoothScrollBehavior` (BouncingScrollPhysics)
- `firebase_options.dart` ✅ — generado por `flutterfire configure` con credenciales reales (proyecto: `edutrack-family`)

### Constantes
- `core/constants/app_colors.dart` ✅
- `core/constants/app_strings.dart` ✅
- `core/constants/app_routes.dart` ✅ — incluye `/permissions`
- `core/constants/themes/app_theme.dart` ✅ — tema light + dark completo
- `core/constants/utils/date_utils.dart` ✅
- `core/constants/utils/notification_utils.dart` ✅ — usa sonido por defecto del dispositivo (no custom)

### Features implementadas
- `core/features/auth/login_screen.dart` ✅ — tarjetas Admin/Estudiante, animación de contraseña, pre-selección de último perfil
- `core/features/permissions/permission_gate_screen.dart` ✅ — pantalla bloqueante al inicio si faltan permisos críticos
- `core/features/settings/settings_screen.dart` ✅ — cambiar contraseña, toggle dark/light, sync (solo admin), logout con confirmación
- `core/features/student/student_home.dart` ✅ — 4 tabs (Dashboard, Calendario, Horario, Ajustes→push)
- `core/features/student/dashboard/student_dashboard.dart` ✅ — SliverAppBar, secciones urgentes/pendientes/completadas
- `core/features/admin/admin_home.dart` ✅ — 6 tabs (Panel, Tareas, Eventos, Historial, Evidencias, Ajustes→push)
- `core/features/admin/dashboard/admin_dashboard.dart` ✅ — estadísticas, progreso, alertas urgentes, actividad reciente

### Widgets compartidos
- `core/shared/widgets/loading_widget.dart` ✅ — shimmer animado con `shimmer: ^3.0.0`
- `core/shared/widgets/offline_banner.dart` ✅ — detecta reconexión WiFi y dispara `SyncService.fullSync()` automáticamente
- `core/shared/widgets/empty_state.dart` ✅

---

## Decisiones técnicas

| Área | Decisión |
|---|---|
| Estado | flutter_riverpod ^2.6.1 |
| Navegación | go_router ^14.8.1 |
| BD local | sqflite ^2.4.2 |
| Sync WiFi | Firebase Firestore (proyecto: edutrack-family) |
| Notificaciones | flutter_local_notifications ^21.0.0 + sonido del sistema |
| Zona horaria | America/Panama |
| Fuentes | Poppins (títulos) + Nunito (cuerpo) |
| Colores base | navyBlue #0F2744, accentBlue #2196F3 |
| Semáforo tareas | verde=hecho, amarillo=≤2 días, rojo=hoy/vencido |
| Renderizador Android | Impeller activado (`EnableImpeller=true` en AndroidManifest) |
| Scroll | BouncingScrollPhysics en toda la app (iOS + Android) |
| Permisos | permission_handler ^12.0.1 |

---

## Flujo de arranque de la app

```
main() → Firebase init → Notificaciones init → SharedPreferences
         ↓
SplashScreen (2.2s animación)
         ↓
_needsCriticalPermissions()?
  SÍ → /permissions (PermissionGateScreen — BLOQUEANTE)
  NO → ¿user == null? → /login
       ¿user.isAdmin? → /admin
       else           → /student
```

---

## Permisos críticos (bloqueantes al inicio)

| Permiso | Android | iOS |
|---|---|---|
| POST_NOTIFICATIONS | API 33+ (runtime dialog) | Sistema (dialog al abrir) |
| SCHEDULE_EXACT_ALARM | API 31+ (abre Ajustes) | No aplica |
| CAMERA / READ_MEDIA_IMAGES | Solicitado por image_picker al usar | Solicitado por image_picker |

Si el usuario niega los permisos críticos (notificaciones + alarmas exactas), la pantalla `/permissions` bloquea el acceso hasta que los active. Al volver de Ajustes del sistema, re-verifica automáticamente via `didChangeAppLifecycleState`.

---

## Sincronización WiFi

- `SyncService.instance.fullSync()` se llama:
  1. Automáticamente cuando `OfflineBanner` detecta reconexión (offline→online)
  2. Manualmente desde Ajustes (solo admin)
- Flujo: local SQLite ← → Firebase Firestore
- Tareas y eventos se sincronizan bidireccionalente

---

## Auto-logout

- Si la app va a segundo plano por más de 3 minutos → logout automático
- Implementado con `WidgetsBindingObserver` en `_EduTrackAppState` (app.dart)
- El timer se cancela si la app vuelve al frente antes de los 3 minutos

---

## Status bar / barra de estado

- Iconos (batería, hora) siempre blancos: `statusBarIconBrightness: Brightness.light`
- Se actualiza reactivamente en `_EduTrackAppState.build()` al cambiar el tema
- Barra de navegación inferior cambia con el tema: oscuro=#1A1A2E, claro=blanco

---

## Android — configuración relevante

- `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true`, `desugar_jdk_libs:2.1.4`
- `android/gradle.properties`: `kotlin.incremental=false` (evita errores cross-drive T: vs C:)
- `android/app/google-services.json`: generado por flutterfire configure
- `ios/Runner/GoogleService-Info.plist`: creado manualmente (flutterfire no lo genera en Windows)

---

## Convenciones de código

- Todos los textos UI en español → `AppStrings`
- Todos los colores → `AppColors`
- Todas las rutas → `AppRoutes`
- Fechas siempre con → `EduDateUtils`
- Notificaciones siempre con → `NotificationUtils`
- Dark mode: siempre verificar `isDark = Theme.of(context).brightness == Brightness.dark`
- Cards en dark: `isDark ? const Color(0xFF1E1E2E) : Colors.white`
- Fondo de pantalla en dark: `isDark ? const Color(0xFF12121E) : AppColors.background`
