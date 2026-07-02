import 'package:edutrack_family/core/data/local/database_helper.dart';
import 'package:edutrack_family/core/data/local/models/event_model.dart';
import 'package:edutrack_family/core/constants/utils/date_utils.dart';

// ═══════════════════════════════════════════════════════════════
// EVENT REPOSITORY — EduTrack Family
// Operaciones CRUD sobre eventos en SQLite.
// ═══════════════════════════════════════════════════════════════

class EventRepository {
  EventRepository._();
  static final EventRepository instance = EventRepository._();

  final _db = DatabaseHelper.instance;
  static const _table = DatabaseHelper.tableEvent;

  Future<void> createEvent(EventModel event) async {
    await _db.insert(_table, event.toMap());
  }

  Future<List<EventModel>> getAllEvents() async {
    final rows = await _db.queryAll(
      _table,
      where: 'is_deleted = 0',
      orderBy: 'date ASC',
    );
    return rows.map(EventModel.fromMap).toList();
  }

  Future<List<EventModel>> getUpcomingEvents() async {
    final now = EduDateUtils.toIso(DateTime.now());
    final rows = await _db.queryAll(
      _table,
      where: 'date >= ? AND is_deleted = 0',
      whereArgs: [now],
      orderBy: 'date ASC',
    );
    return rows.map(EventModel.fromMap).toList();
  }

  Future<List<EventModel>> getEventsForDate(DateTime date) async {
    final dateStr = EduDateUtils.toDateOnly(date);
    final rows = await _db.queryAll(
      _table,
      where: "date LIKE ? AND is_deleted = 0",
      whereArgs: ['$dateStr%'],
      orderBy: 'date ASC',
    );
    return rows.map(EventModel.fromMap).toList();
  }

  Future<EventModel?> getEventById(String id) async {
    final row = await _db.queryById(_table, id);
    return row != null ? EventModel.fromMap(row) : null;
  }

  Future<void> updateEvent(EventModel event) async {
    await _db.update(_table, event.toMap(), event.id);
  }

  Future<void> deleteEvent(String id) async {
    final event = await getEventById(id);
    if (event == null) return;
    final updated = event.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now(),
    );
    await updateEvent(updated);
  }
}
