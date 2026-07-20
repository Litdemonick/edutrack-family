import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/features/family/data/family_repository.dart';
import 'package:edutrack_family/features/family/presentation/widgets/student_selector.dart';
import 'package:edutrack_family/features/location/data/location_models.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'package:edutrack_family/features/safety/wellness_check.dart';

// ═══════════════════════════════════════════════════════════════
// MAPA DEL HIJO — EduTrack Family 2.0 (padres)
// flutter_map + OpenStreetMap (gratis, sin API key).
// Posición en vivo, rastro (72h), zonas seguras editables
// (long-press para crear), botón de check-in "¿Estás bien?".
// ═══════════════════════════════════════════════════════════════

class ChildMapScreen extends ConsumerStatefulWidget {
  const ChildMapScreen({super.key});

  @override
  ConsumerState<ChildMapScreen> createState() => _ChildMapScreenState();
}

class _ChildMapScreenState extends ConsumerState<ChildMapScreen> {
  final _mapController = MapController();
  List<LocationPoint> _history = const [];
  bool _hasMoreHistory = false;
  bool _loadingMoreHistory = false;
  bool _followChild = true;
  // flutter_map no deja mover la cámara antes de su primer frame
  // (MapController.camera revienta si se llama demasiado pronto) —
  // sin esperar a onMapReady, el primer intento de centrar en el
  // hijo (justo cuando llega la primera posición) fallaba en
  // silencio y el mapa se quedaba en el fallback de Panamá hasta
  // el siguiente tick de posición.
  bool _mapReady = false;
  bool _togglingSharing = false;

  static const _panama = LatLng(8.9824, -79.5199); // fallback inicial

  Future<void> _toggleSharing(String studentId, bool enabled) async {
    setState(() => _togglingSharing = true);
    try {
      await LocationRepository.instance
          .setSharingEnabledByParent(studentId, enabled);
    } finally {
      if (mounted) setState(() => _togglingSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(activeStudentProvider);

    if (student == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ubicación')),
        body: const Center(
            child: Text('Agrega un hijo/a para usar la ubicación')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación'),
        actions: const [StudentSelector(), SizedBox(width: 12)],
      ),
      body: StreamBuilder<
          ({bool enabledByParent, bool deviceConfirmed, String? permissionError})>(
        stream: LocationRepository.instance.watchConsent(student.id),
        builder: (context, consentSnap) {
          final consent = consentSnap.data;
          final sharingActive =
              (consent?.enabledByParent ?? false) &&
                  (consent?.deviceConfirmed ?? false) &&
                  consent?.permissionError == null;

          return Column(
            children: [
              _SharingBanner(
                studentName: student.name,
                consent: consent,
                busy: _togglingSharing,
                onToggle: (enabled) => _toggleSharing(student.id, enabled),
              ),
              Expanded(
                child: sharingActive
                    ? _buildMap(student.id)
                    : _InactiveView(consent: consent),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'seismic',
            backgroundColor: Colors.deepOrange,
            tooltip: 'Alerta sísmica',
            onPressed: () => _showSeismicSettings(student),
            child: const Icon(Icons.public, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'wellness',
            backgroundColor: Colors.orange,
            tooltip: '¿Estás bien?',
            onPressed: () =>
                startWellnessCheck(context, ref, student.id, student.name),
            child: const Icon(Icons.health_and_safety, color: Colors.white),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'center',
            tooltip: 'Centrar en el hijo',
            onPressed: () => setState(() => _followChild = true),
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(String studentId) {
    return StreamBuilder<LocationPoint?>(
      stream: LocationRepository.instance.watchCurrent(studentId),
      builder: (context, posSnap) {
        final current = posSnap.data;
        final center = current != null
            ? LatLng(current.lat, current.lng)
            : _panama;

        if (current != null && _followChild && _mapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _mapController.move(center, _mapController.camera.zoom);
          });
        }

        return StreamBuilder<List<SafeZone>>(
          stream: LocationRepository.instance.watchZones(studentId),
          builder: (context, zonesSnap) {
            final zones = zonesSnap.data ?? const <SafeZone>[];

            return Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16,
                    onMapReady: () {
                      _mapReady = true;
                      // Si la primera posición ya había llegado antes
                      // de que el mapa terminara de montarse, esta es
                      // la única oportunidad de centrar en ella — la
                      // próxima posición puede tardar (polling en
                      // escritorio), y sin esto se veía el fallback
                      // de Panamá hasta ese momento.
                      if (current != null && _followChild) {
                        _mapController.move(
                            center, _mapController.camera.zoom);
                      }
                    },
                    onPositionChanged: (_, hasGesture) {
                      if (hasGesture && _followChild) {
                        setState(() => _followChild = false);
                      }
                    },
                    onLongPress: (_, point) =>
                        _createZone(studentId, point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // Requerido por la política de uso de OSM
                      userAgentPackageName: 'com.edutrack.family',
                    ),
                    // Zonas seguras
                    CircleLayer(
                      circles: [
                        for (final zone in zones)
                          CircleMarker(
                            point: LatLng(zone.lat, zone.lng),
                            radius: zone.radiusM,
                            useRadiusInMeter: true,
                            color: AppColors.accentBlue
                                .withValues(alpha: 0.15),
                            borderColor: AppColors.accentBlue,
                            borderStrokeWidth: 2,
                          ),
                      ],
                    ),
                    // Rastro (breadcrumbs)
                    if (_history.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [
                              for (final p in _history)
                                LatLng(p.lat, p.lng)
                            ],
                            strokeWidth: 3,
                            color: AppColors.accentBlue
                                .withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                    // Marcadores de zonas (nombre, tap para editar)
                    MarkerLayer(
                      markers: [
                        for (final zone in zones)
                          Marker(
                            point: LatLng(zone.lat, zone.lng),
                            width: 120,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _editZone(studentId, zone),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: const [
                                    BoxShadow(
                                        blurRadius: 4,
                                        color: Colors.black26)
                                  ],
                                ),
                                child: Text(
                                  zone.name,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                        // Marcador del hijo
                        if (current != null)
                          Marker(
                            point: LatLng(current.lat, current.lng),
                            width: 46,
                            height: 46,
                            child: _ChildMarker(stale: current.isStale),
                          ),
                      ],
                    ),
                  ],
                ),
                // Estado de la última actualización + compartir
                if (current != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LastSeenChip(point: current),
                        const SizedBox(width: 6),
                        _ShareLocationButton(
                          point: current,
                          studentName:
                              ref.read(activeStudentProvider)?.name ??
                                  'tu hijo/a',
                        ),
                      ],
                    ),
                  ),
                // Botón de historial
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _loadHistory(studentId),
                        icon: const Icon(Icons.route, size: 18),
                        label: Text(_history.isEmpty
                            ? 'Ver recorrido'
                            : 'Recorrido (${_history.length})'),
                      ),
                      if (_history.isNotEmpty && _hasMoreHistory) ...[
                        const SizedBox(height: 6),
                        FilledButton.tonalIcon(
                          onPressed: _loadingMoreHistory
                              ? null
                              : () => _loadMoreHistory(studentId),
                          icon: _loadingMoreHistory
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.history, size: 18),
                          label: const Text('Cargar más antiguo'),
                        ),
                      ],
                    ],
                  ),
                ),
                // Ayuda de zonas
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Mantén presionado el mapa para crear una zona',
                      style: TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSeismicSettings(StudentProfile student) async {
    var enabled = student.seismicAlertsEnabled;
    var minMag = student.seismicMinMagnitude;

    final result = await showModalBottomSheet<(bool, double)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🌍', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text(
                'Alerta sísmica',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'EduTrack revisa cada minuto el reporte público de '
                'terremotos (USGS) y avisa a tu familia si hay uno '
                'cerca. Esto complementa — no reemplaza — las alertas '
                'oficiales de tu teléfono.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: enabled,
                onChanged: (v) => setSheetState(() => enabled = v),
                title: const Text('Activar alerta sísmica'),
                contentPadding: EdgeInsets.zero,
              ),
              if (enabled) ...[
                Text('Magnitud mínima: ${minMag.toStringAsFixed(1)}'),
                Slider(
                  value: minMag,
                  min: 3.5,
                  max: 6.5,
                  divisions: 6,
                  label: minMag.toStringAsFixed(1),
                  onChanged: (v) => setSheetState(() => minMag = v),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, (enabled, minMag)),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null) return;

    final updated = student.copyWith(
      seismicAlertsEnabled: result.$1,
      seismicMinMagnitude: result.$2,
    );
    await FamilyRepository.instance.updateChild(updated);
    if (mounted) {
      await ref.read(linkedStudentsProvider.notifier).upsertLocal(updated);
    }
  }

  static const _historyPageSize = 100;

  Future<void> _loadHistory(String studentId) async {
    final history = await LocationRepository.instance
        .getHistory(studentId, limit: _historyPageSize);
    if (mounted) {
      setState(() {
        _history = history;
        _hasMoreHistory = history.length == _historyPageSize;
      });
    }
  }

  /// Trae la página anterior (puntos más antiguos que los ya cargados).
  Future<void> _loadMoreHistory(String studentId) async {
    if (_history.isEmpty || _loadingMoreHistory) return;
    setState(() => _loadingMoreHistory = true);
    final older = await LocationRepository.instance.getHistory(
      studentId,
      limit: _historyPageSize,
      before: _history.first.ts,
    );
    if (mounted) {
      setState(() {
        _history = [...older, ..._history];
        _hasMoreHistory = older.length == _historyPageSize;
        _loadingMoreHistory = false;
      });
    }
  }

  Future<void> _createZone(String studentId, LatLng point) async {
    final result = await _showZoneSheet(name: '', radius: 200);
    if (result == null) return;
    await LocationRepository.instance.upsertZone(
      studentId,
      SafeZone(
        id: const Uuid().v4(),
        name: result.$1,
        lat: point.latitude,
        lng: point.longitude,
        radiusM: result.$2,
      ),
    );
  }

  Future<void> _editZone(String studentId, SafeZone zone) async {
    final result = await _showZoneSheet(
        name: zone.name, radius: zone.radiusM, canDelete: true);
    if (result == null) return;
    if (result.$1 == '__DELETE__') {
      await LocationRepository.instance.deleteZone(studentId, zone.id);
    } else {
      await LocationRepository.instance.upsertZone(
        studentId,
        SafeZone(
          id: zone.id,
          name: result.$1,
          lat: zone.lat,
          lng: zone.lng,
          radiusM: result.$2,
        ),
      );
    }
  }

  Future<(String, double)?> _showZoneSheet({
    required String name,
    required double radius,
    bool canDelete = false,
  }) {
    final nameCtrl = TextEditingController(text: name);
    var currentRadius = radius;

    return showModalBottomSheet<(String, double)>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                canDelete ? 'Editar zona' : 'Nueva zona segura',
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                autofocus: !canDelete,
                decoration: InputDecoration(
                  labelText: 'Nombre (ej. Escuela, Casa)',
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 14),
              Text('Radio: ${currentRadius.round()} m'),
              Slider(
                value: currentRadius.clamp(50, 1000),
                min: 50,
                max: 1000,
                divisions: 19,
                label: '${currentRadius.round()} m',
                onChanged: (v) => setSheetState(() => currentRadius = v),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () {
                  final n = nameCtrl.text.trim();
                  if (n.isEmpty) return;
                  Navigator.pop(ctx, (n, currentRadius));
                },
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                child: const Text('Guardar zona'),
              ),
              if (canDelete)
                TextButton.icon(
                  onPressed: () =>
                      Navigator.pop(ctx, ('__DELETE__', currentRadius)),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Eliminar zona',
                      style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────

class _ChildMarker extends StatelessWidget {
  final bool stale;
  const _ChildMarker({required this.stale});

  @override
  Widget build(BuildContext context) {
    final color = stale ? Colors.grey : AppColors.accentBlue;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 24),
    );
  }
}

// Comparte la ubicación actual por WhatsApp/SMS/etc. vía la hoja de
// compartir del sistema — un link de Google Maps abre bien desde
// cualquier app que lo reciba, sin depender de tener Maps instalado.
class _ShareLocationButton extends StatelessWidget {
  final LocationPoint point;
  final String studentName;
  const _ShareLocationButton({required this.point, required this.studentName});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          final mapsUrl =
              'https://www.google.com/maps?q=${point.lat},${point.lng}';
          SharePlus.instance.share(ShareParams(
            text: '📍 Ubicación de $studentName: $mapsUrl',
          ));
        },
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.share_rounded, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _LastSeenChip extends StatelessWidget {
  final LocationPoint point;
  const _LastSeenChip({required this.point});

  @override
  Widget build(BuildContext context) {
    final mins = DateTime.now().difference(point.ts).inMinutes;
    final label = mins < 1
        ? 'Ahora mismo'
        : mins < 60
            ? 'Hace $mins min'
            : 'Hace ${(mins / 60).floor()} h';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: point.isStale ? Colors.grey.shade700 : Colors.green.shade700,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(point.isStale ? Icons.schedule : Icons.gps_fixed,
              size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (point.battery != null) ...[
            const SizedBox(width: 8),
            const Icon(Icons.battery_std, size: 14, color: Colors.white),
            Text('${point.battery}%',
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _SharingBanner extends StatelessWidget {
  final String studentName;
  final ({bool enabledByParent, bool deviceConfirmed, String? permissionError})? consent;
  final bool busy;
  final ValueChanged<bool> onToggle;

  const _SharingBanner({
    required this.studentName,
    required this.consent,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = consent?.enabledByParent ?? false;
    final confirmed = consent?.deviceConfirmed ?? false;
    final permissionError = consent?.permissionError;

    final (text, color) = busy
        ? ('Actualizando…', Colors.blueGrey)
        : !enabled
            ? ('Compartir ubicación está apagado', Colors.grey)
            // Sin este aviso, un permiso faltante en el celular del
            // hijo se veía IGUAL que todo bien — el padre nunca se
            // enteraba de por qué no llegaba ninguna posición.
            : permissionError != null
                ? ('$studentName: falta un permiso — $permissionError',
                    Colors.red)
                : !confirmed
                    // Transitorio (un instante mientras se
                    // auto-confirma en el celular del hijo) o porque
                    // el hijo lo apagó desde su Ajustes — ya no
                    // espera que "acepte" nada.
                    ? ('Activando en el teléfono de $studentName…',
                        Colors.orange)
                    : ('Compartiendo ubicación', Colors.green);

    return Material(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.location_on, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
                child: Text(text, style: const TextStyle(fontSize: 13))),
            // Antes el switch cambiaba de estado recién cuando el
            // stream de consentimiento se enteraba (podía tardar) —
            // sin ningún indicio de que el toque sí se había
            // registrado. Con [busy] se ve un spinner de inmediato y
            // el switch queda bloqueado hasta que la escritura
            // termina, en vez de parecer que "no hizo nada".
            busy
                ? const SizedBox(
                    width: 40,
                    height: 24,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : Switch(value: enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _InactiveView extends StatelessWidget {
  final ({bool enabledByParent, bool deviceConfirmed, String? permissionError})? consent;
  const _InactiveView({required this.consent});

  @override
  Widget build(BuildContext context) {
    final waiting = consent?.enabledByParent ?? false;
    final permissionError = consent?.permissionError;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              permissionError != null
                  ? '⚠️'
                  : waiting
                      ? '⏳'
                      : '🗺️',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 16),
            Text(
              permissionError != null
                  ? 'Le falta un permiso a tu hijo/a en su celular: '
                      '$permissionError\n\nPídele que abra la app y toque '
                      '"Compartir ubicación" en Ajustes → Ubicación para '
                      'terminar de activarlo.'
                  : waiting
                      ? 'Activando en el teléfono de tu hijo/a — esto toma unos '
                          'segundos. Verá siempre un aviso mientras esté activo, '
                          'y puede apagarlo él mismo desde Ajustes si quiere.'
                      : 'Activa el interruptor para compartir la ubicación — '
                          'empieza directo, sin que tu hijo/a tenga que aceptar '
                          'nada. Verá siempre un indicador mientras esté activo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: permissionError != null
                    ? Colors.red.shade700
                    : Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
