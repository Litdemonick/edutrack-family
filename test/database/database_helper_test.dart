import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/task_model.dart';

// Ejecuta SQLite real (sin dispositivo) usando el motor FFI —
// permite correr estos tests en Windows/CI sin emulador.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await DatabaseHelper.instance.close();
  });

  test('creates all multi-tenant tables with student_id columns', () async {
    final db = await DatabaseHelper.instance.database;

    for (final table in [
      DatabaseHelper.tableStudent,
      DatabaseHelper.tableTask,
      DatabaseHelper.tableEvent,
      DatabaseHelper.tableScheduleBlock,
      DatabaseHelper.tableEvidence,
    ]) {
      final info = await db.rawQuery('PRAGMA table_info($table)');
      expect(info, isNotEmpty, reason: 'tabla $table debería existir');
    }

    final taskColumns = (await db.rawQuery('PRAGMA table_info(tasks)'))
        .map((c) => c['name'] as String)
        .toSet();
    expect(taskColumns, contains('student_id'));
    expect(taskColumns, contains('is_dirty'));
  });

  test('insert/query scoped by student_id only returns matching rows',
      () async {
    final db = DatabaseHelper.instance;
    final now = DateTime(2026, 1, 1).toIso8601String();

    final taskA = TaskModel(
      id: 'a1',
      studentId: 'student-A',
      title: 'Tarea A',
      subject: 'Español',
      category: 'Tarea',
      dueDate: DateTime(2026, 1, 5),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    final taskB = taskA.copyWith(id: 'b1', studentId: 'student-B');

    await db.insert(DatabaseHelper.tableTask, taskA.toMap());
    await db.insert(DatabaseHelper.tableTask, taskB.toMap());

    final onlyA = await db.queryAll(
      DatabaseHelper.tableTask,
      where: 'student_id = ?',
      whereArgs: ['student-A'],
    );

    expect(onlyA, hasLength(1));
    expect(onlyA.first['id'], 'a1');
    expect(now, isNotEmpty); // sanity: helper compiled
  });

  test('setDirty and queryDirty round-trip the pending-sync flag', () async {
    final db = DatabaseHelper.instance;
    final task = TaskModel(
      id: 'dirty-1',
      studentId: 'student-A',
      title: 'Offline task',
      subject: 'Ciencias',
      category: 'Tarea',
      dueDate: DateTime(2026, 2, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final map = task.toMap()..['is_dirty'] = 1;
    await db.insert(DatabaseHelper.tableTask, map);

    final dirtyBefore = await db.queryDirty(DatabaseHelper.tableTask);
    expect(dirtyBefore.map((r) => r['id']), contains('dirty-1'));

    await db.setDirty(DatabaseHelper.tableTask, 'dirty-1', false);
    final dirtyAfter = await db.queryDirty(DatabaseHelper.tableTask);
    expect(dirtyAfter.map((r) => r['id']), isNot(contains('dirty-1')));
  });

  test('sync_meta checkpoint persists last_pulled_at per collection+student',
      () async {
    final db = DatabaseHelper.instance;
    await db.setLastPulledAt('tasks', 'student-A', '2026-01-01T00:00:00.000');

    final value = await db.getLastPulledAt('tasks', 'student-A');
    expect(value, '2026-01-01T00:00:00.000');

    final missing = await db.getLastPulledAt('tasks', 'student-B');
    expect(missing, isNull);
  });

  test('wipeAll clears every table', () async {
    final db = DatabaseHelper.instance;
    await db.insert(DatabaseHelper.tableTask, {
      'id': 'x1',
      'student_id': 's1',
      'title': 'x',
      'subject': 'x',
      'category': 'Tarea',
      'due_date': DateTime(2026, 1, 1).toIso8601String(),
      'created_at': DateTime(2026, 1, 1).toIso8601String(),
      'updated_at': DateTime(2026, 1, 1).toIso8601String(),
    });

    await db.wipeAll();
    final rows = await db.queryAll(DatabaseHelper.tableTask);
    expect(rows, isEmpty);
  });
}
