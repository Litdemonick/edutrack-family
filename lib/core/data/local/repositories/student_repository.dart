import 'package:edutrack_family/core/database/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/student_model.dart';

// ═══════════════════════════════════════════════════════════════
// STUDENT REPOSITORY — EduTrack Family 2.0
// CRUD local (SQLite) de perfiles de estudiantes vinculados.
// El espejo remoto vive en students/{id} (FirestoreService).
// ═══════════════════════════════════════════════════════════════

class StudentRepository {
  StudentRepository._();
  static final StudentRepository instance = StudentRepository._();

  final _db = DatabaseHelper.instance;

  Future<List<StudentProfile>> getAll() async {
    final rows = await _db.queryAll(
      DatabaseHelper.tableStudent,
      orderBy: 'name ASC',
    );
    return rows.map(StudentProfile.fromMap).toList();
  }

  Future<StudentProfile?> getById(String id) async {
    final row = await _db.queryById(DatabaseHelper.tableStudent, id);
    return row == null ? null : StudentProfile.fromMap(row);
  }

  Future<void> upsert(StudentProfile student, {bool dirty = false}) async {
    final map = student.toMap();
    map['is_dirty'] = dirty ? 1 : 0;
    await _db.insert(DatabaseHelper.tableStudent, map);
  }

  Future<void> delete(String id) async {
    await _db.delete(DatabaseHelper.tableStudent, id);
  }

  Future<void> replaceAll(List<StudentProfile> students) async {
    await _db.deleteAll(DatabaseHelper.tableStudent);
    for (final s in students) {
      await upsert(s);
    }
  }
}
