import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════
// MODELOS DE UBICACIÓN — EduTrack Family 2.0
// ═══════════════════════════════════════════════════════════════

/// Punto de ubicación del estudiante.
class LocationPoint extends Equatable {
  final double lat;
  final double lng;
  final double? accuracy;
  final double? speed;
  final int? battery;
  final DateTime ts;

  const LocationPoint({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.speed,
    this.battery,
    required this.ts,
  });

  bool get isStale => DateTime.now().difference(ts).inMinutes > 10;

  Map<String, dynamic> toFirestore({DateTime? expireAt}) => {
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'speed': speed,
        'battery': battery,
        'ts': ts.toIso8601String(),
        if (expireAt != null) 'expireAt': expireAt,
      };

  factory LocationPoint.fromFirestore(Map<String, dynamic> data) {
    return LocationPoint(
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      accuracy: (data['accuracy'] as num?)?.toDouble(),
      speed: (data['speed'] as num?)?.toDouble(),
      battery: data['battery'] as int?,
      ts: DateTime.tryParse((data['ts'] ?? '') as String) ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [lat, lng, ts];
}

/// Zona segura (geocerca circular) definida por el padre.
class SafeZone extends Equatable {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double radiusM;
  final bool notifyEnter;
  final bool notifyExit;

  const SafeZone({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.radiusM,
    this.notifyEnter = true,
    this.notifyExit = true,
  });

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'lat': lat,
        'lng': lng,
        'radiusM': radiusM,
        'notifyEnter': notifyEnter,
        'notifyExit': notifyExit,
      };

  factory SafeZone.fromFirestore(Map<String, dynamic> data, String id) {
    return SafeZone(
      id: id,
      name: (data['name'] ?? 'Zona') as String,
      lat: (data['lat'] as num).toDouble(),
      lng: (data['lng'] as num).toDouble(),
      radiusM: (data['radiusM'] as num?)?.toDouble() ?? 200,
      notifyEnter: (data['notifyEnter'] ?? true) as bool,
      notifyExit: (data['notifyExit'] ?? true) as bool,
    );
  }

  @override
  List<Object?> get props => [id, name, lat, lng, radiusM];
}
