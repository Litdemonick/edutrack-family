import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';

void main() {
  group('ScheduleBlock', () {
    test('formats time range in 12h with AM/PM', () {
      final block = ScheduleBlock(
        id: 'b1',
        studentId: 's1',
        weekday: DateTime.monday,
        startMin: 7 * 60,
        endMin: 7 * 60 + 45,
        subject: 'Matemáticas',
        updatedAt: DateTime.now(),
      );

      expect(block.startLabel, '7:00 AM');
      expect(block.endLabel, '7:45 AM');
      expect(block.timeRange, '7:00 AM – 7:45 AM');
    });

    test('isCurrentAt only matches the right weekday and time window', () {
      final monday830 = ScheduleBlock(
        id: 'b1',
        studentId: 's1',
        weekday: DateTime.monday,
        startMin: 8 * 60,
        endMin: 9 * 60,
        subject: 'Ciencias',
        updatedAt: DateTime.now(),
      );

      final duringClassOnMonday = DateTime(2026, 3, 9, 8, 30); // lunes
      final afterClassOnMonday = DateTime(2026, 3, 9, 9, 30);
      final duringClassOnTuesday = DateTime(2026, 3, 10, 8, 30);

      expect(monday830.isCurrentAt(duringClassOnMonday), isTrue);
      expect(monday830.isCurrentAt(afterClassOnMonday), isFalse);
      expect(monday830.isCurrentAt(duringClassOnTuesday), isFalse);
    });

    test('round-trips through SQLite map', () {
      final block = ScheduleBlock(
        id: 'b1',
        studentId: 's1',
        weekday: 3,
        startMin: 600,
        endMin: 660,
        subject: 'Recreo',
        isBreak: true,
        updatedAt: DateTime(2026, 1, 1),
      );
      final restored = ScheduleBlock.fromMap(block.toMap());

      expect(restored.weekday, 3);
      expect(restored.isBreak, isTrue);
      expect(restored.subject, 'Recreo');
    });
  });
}
