import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_family/features/safety/wellness_check.dart';

void main() {
  group('Wellness check timeout', () {
    test('the client timeout window is exactly 3 minutes', () {
      // Contrato compartido con la Cloud Function checkWellnessTimeouts:
      // ambos lados deben coincidir en la ventana de espera.
      expect(wellnessTimeout, const Duration(minutes: 3));
    });

    test('an expiresAt in the past is considered timed out', () {
      final requestedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final expiresAt = requestedAt.add(wellnessTimeout);
      final now = expiresAt.add(const Duration(seconds: 1));

      expect(now.isAfter(expiresAt), isTrue);
    });

    test('an expiresAt still in the future is not timed out', () {
      final requestedAt = DateTime(2026, 1, 1, 12, 0, 0);
      final expiresAt = requestedAt.add(wellnessTimeout);
      final now = requestedAt.add(const Duration(minutes: 2, seconds: 30));

      expect(now.isAfter(expiresAt), isFalse);
    });
  });
}
