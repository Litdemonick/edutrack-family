import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import 'package:edutrack_family/core/constants/app_colors.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
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
  bool _followChild = true;

  static const _panama = LatLng(8.9824, -79.5199); // fallback inicial

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
      body: StreamBuilder<({bool enabledByParent, bool deviceConfirmed})>(
        stream: LocationRepository.instance.watchConsent(student.id),
        builder: (context, consentSnap) {
          final consent = consentSnap.data;
          final sharingActive =
              (consent?.enabledByParent ?? false) &&
                  (consent?.deviceConfirmed ?? false);

          return Column(
            children: [
              _SharingBanner(
                studentName: student.name,
                consent: consent,
                onToggle: (enabled) => LocationRepository.instance
                    .setSharingEnabledByParent(student.id, enabled),
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

        if (current != null && _followChild) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _mapController.move(center, _mapController.camera.zoom);
            } catch (_) {}
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
                // Estado de la última actualización
                if (current != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _LastSeenChip(point: current),
                  ),
                // Botón de historial
                Positioned(
                  top: 10,
                  right: 10,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _loadHistory(studentId),
                    icon: const Icon(Icons.route, size: 18),
                    label: Text(_history.isEmpty
                        ? 'Ver recorrido'
                        : 'Recorrido (${_history.length})'),
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

  Future<void> _loadHistory(String studentId) async {
    final history =
        await LocationRepository.instance.getHistory(studentId, limit: 100);
    if (mounted) setState(() => _history = history);
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
  final ({bool enabledByParent, bool deviceConfirmed})? consent;
  final ValueChanged<bool> onToggle;

  const _SharingBanner({
    required this.studentName,
    required this.consent,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = consent?.enabledByParent ?? false;
    final confirmed = consent?.deviceConfirmed ?? false;

    final (text, color) = !enabled
        ? ('Compartir ubicación está apagado', Colors.grey)
        : !confirmed
            ? ('Esperando que $studentName acepte en su teléfono…',
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
            Switch(value: enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }
}

class _InactiveView extends StatelessWidget {
  final ({bool enabledByParent, bool deviceConfirmed})? consent;
  const _InactiveView({required this.consent});

  @override
  Widget build(BuildContext context) {
    final waiting = consent?.enabledByParent ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(waiting ? '⏳' : '🗺️', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text(
              waiting
                  ? 'Esperando el consentimiento en el teléfono de tu hijo/a. '
                      'Le llegó un aviso para aceptar.'
                  : 'Activa el interruptor para pedir compartir la ubicación. '
                      'Tu hijo/a debe aceptar en su teléfono y verá siempre '
                      'un indicador mientras esté activo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
