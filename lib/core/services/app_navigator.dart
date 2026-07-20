import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// APP NAVIGATOR — EduTrack Family
// Key global del Navigator raíz — necesaria para navegar al tocar
// una notificación push que puede llegar con la app recién
// arrancando desde cero (terminated), antes de que exista ningún
// BuildContext de pantalla propio para usar context.push(...).
// ═══════════════════════════════════════════════════════════════

final rootNavigatorKey = GlobalKey<NavigatorState>();
