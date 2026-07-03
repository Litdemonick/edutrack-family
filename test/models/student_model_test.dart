import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';

void main() {
  group('StudentProfile', () {
    final now = DateTime(2026, 1, 1);

    test('computes initials from full name', () {
      final one = StudentProfile(id: 's1', name: 'Yordan', updatedAt: now);
      final two =
          StudentProfile(id: 's2', name: 'Yordan Pérez', updatedAt: now);

      expect(one.initials, 'Y');
      expect(two.initials, 'YP');
    });

    test('round-trips through SQLite map including parent/teacher ids', () {
      final student = StudentProfile(
        id: 's1',
        name: 'Yordan',
        grade: '5° B',
        parentIds: const ['parent-1', 'parent-2'],
        teacherIds: const ['teacher-1'],
        locationSharingEnabled: true,
        locationDeviceConfirmed: false,
        seismicAlertsEnabled: false,
        seismicMinMagnitude: 5.0,
        updatedAt: now,
      );

      final restored = StudentProfile.fromMap(student.toMap());

      expect(restored.parentIds, student.parentIds);
      expect(restored.teacherIds, student.teacherIds);
      expect(restored.locationSharingEnabled, isTrue);
      expect(restored.locationDeviceConfirmed, isFalse);
      expect(restored.seismicAlertsEnabled, isFalse);
      expect(restored.seismicMinMagnitude, 5.0);
    });

    test('round-trips through Firestore map with nested locationSharing', () {
      final student = StudentProfile(
        id: 's1',
        name: 'Yordan',
        parentIds: const ['parent-1'],
        locationSharingEnabled: true,
        locationDeviceConfirmed: true,
        updatedAt: now,
      );

      final data = student.toFirestore();
      final restored = StudentProfile.fromFirestore(data, 's1');

      expect(restored.locationSharingEnabled, isTrue);
      expect(restored.locationDeviceConfirmed, isTrue);
      expect(restored.parentIds, contains('parent-1'));
    });

    test('seismic alerts default to enabled at 4.5 magnitude', () {
      final student = StudentProfile(id: 's1', name: 'Yordan', updatedAt: now);
      expect(student.seismicAlertsEnabled, isTrue);
      expect(student.seismicMinMagnitude, 4.5);
    });
  });
}
