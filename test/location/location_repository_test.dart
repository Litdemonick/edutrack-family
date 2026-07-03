import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_family/features/location/data/location_repository.dart';
import 'package:edutrack_family/features/location/data/location_models.dart';

void main() {
  group('LocationRepository.distanceMeters', () {
    test('same point returns ~0 meters', () {
      final d = LocationRepository.distanceMeters(8.9824, -79.5199, 8.9824, -79.5199);
      expect(d, closeTo(0, 0.01));
    });

    test('matches a known reference distance within tolerance', () {
      // Panamá City ↔ Colón (Panamá), ~68-75 km en línea recta según fuente.
      final d = LocationRepository.distanceMeters(
          8.9824, -79.5199, 9.3592, -79.9014);
      final km = d / 1000;
      expect(km, greaterThan(50));
      expect(km, lessThan(90));
    });

    test('a short walk of ~100m stays within a safe-zone radius', () {
      // ~0.0009 grados de latitud ≈ 100 m
      final d = LocationRepository.distanceMeters(
          8.9824, -79.5199, 8.98330, -79.5199);
      expect(d, closeTo(100, 15));
    });
  });

  group('LocationPoint', () {
    test('isStale is false for a fresh point and true after 10+ minutes', () {
      final fresh = LocationPoint(lat: 0, lng: 0, ts: DateTime.now());
      final stale = LocationPoint(
        lat: 0,
        lng: 0,
        ts: DateTime.now().subtract(const Duration(minutes: 11)),
      );

      expect(fresh.isStale, isFalse);
      expect(stale.isStale, isTrue);
    });
  });

  group('SafeZone', () {
    test('round-trips through Firestore map', () {
      const zone = SafeZone(
        id: 'z1',
        name: 'Escuela',
        lat: 8.98,
        lng: -79.52,
        radiusM: 250,
        notifyEnter: true,
        notifyExit: false,
      );
      final restored = SafeZone.fromFirestore(zone.toFirestore(), 'z1');

      expect(restored.name, 'Escuela');
      expect(restored.radiusM, 250);
      expect(restored.notifyExit, isFalse);
    });
  });
}
