import 'package:flutter_test/flutter_test.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

void main() {
  group('TaskModel', () {
    final now = DateTime(2026, 3, 10, 8, 0);

    TaskModel buildTask({List<String> evidence = const []}) => TaskModel(
          id: 't1',
          studentId: 'student-abc',
          assignedBy: 'parent-1',
          title: 'Tarea de matemáticas',
          subject: 'Matemáticas',
          category: 'Tarea',
          dueDate: now.add(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
          evidencePhotoPaths: evidence,
        );

    test('round-trips through SQLite map preserving studentId', () {
      final task = buildTask(evidence: ['/tmp/a.jpg', '/tmp/b.jpg']);
      final restored = TaskModel.fromMap(task.toMap());

      expect(restored.id, task.id);
      expect(restored.studentId, 'student-abc');
      expect(restored.assignedBy, 'parent-1');
      expect(restored.evidencePhotoPaths, task.evidencePhotoPaths);
      expect(restored.status, TaskStatus.pending);
    });

    test('toFirestore never leaks local file paths', () {
      final task = buildTask(evidence: ['/local/only/on/device.jpg']);
      final data = task.toFirestore();

      expect(data['evidence_photo_paths'], isEmpty);
      // El flag sí debe viajar para que el otro dispositivo sepa que hay fotos
      expect(data['has_evidence_images'], isTrue);
    });

    test('fromFirestore assigns studentId from the document path, not the payload',
        () {
      final data = buildTask().toFirestore();
      final restored =
          TaskModel.fromFirestore(data, 't1', studentId: 'student-xyz');

      expect(restored.studentId, 'student-xyz');
    });

    test('isUrgent/isDueToday reflect the due date correctly', () {
      final overdue = buildTask().copyWith(
        dueDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(overdue.isUrgent, isTrue);
      expect(overdue.isOverdueTask, isTrue);
    });

    test('conversationHistory survives JSON round-trip', () {
      final task = buildTask().copyWith(conversationHistory: [
        ConversationEntry(
          author: 'student',
          type: 'resubmit',
          text: 'Ya lo hice de nuevo',
          timestamp: now,
        ),
      ]);
      final restored = TaskModel.fromMap(task.toMap());

      expect(restored.conversationHistory, hasLength(1));
      expect(restored.conversationHistory.first.author, 'student');
      expect(restored.conversationHistory.first.isFromStudent, isTrue);
    });
  });
}
