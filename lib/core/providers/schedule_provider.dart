import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/data/local/models/notification_model.dart';
import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/data/local/repositories/schedule_repository.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';
import 'package:edutrack_family/core/services/notification_bus.dart';

// ═══════════════════════════════════════════════════════════════
// SCHEDULE PROVIDER — EduTrack Family 2.0
// Horario semanal del estudiante activo (data-driven).
// ═══════════════════════════════════════════════════════════════

class ScheduleNotifier extends StateNotifier<AsyncValue<List<ScheduleBlock>>> {
  ScheduleNotifier(this._ref) : super(const AsyncValue.loading()) {
    load();
  }

  final Ref _ref;
  final _repo = ScheduleRepository.instance;

  String? get _scopeStudentId {
    final user = _ref.read(authProvider);
    if (user == null) return null;
    if (user.isStudent) return user.uid;
    return _ref.read(activeStudentProvider)?.id;
  }

  Future<void> load() async {
    final scope = _scopeStudentId;

    // Mismo resguardo que taskProvider/eventProvider: no vaciar el
    // horario ya visible por un scope momentáneamente null.
    if (scope == null && state.hasValue) return;

    try {
      final blocks =
          scope == null ? <ScheduleBlock>[] : await _repo.getAll(scope);
      // Mismo contenido exacto que ya está en pantalla → no reemplazar
      // el estado (evita parpadeos por syncs que no trajeron cambios).
      if (state.hasValue && _sameBlocks(state.value!, blocks)) return;
      state = AsyncValue.data(blocks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  bool _sameBlocks(List<ScheduleBlock> a, List<ScheduleBlock> b) {
    if (a.length != b.length) return false;
    final byId = {for (final blk in a) blk.id: blk.updatedAt};
    for (final blk in b) {
      final prevUpdatedAt = byId[blk.id];
      if (prevUpdatedAt == null || prevUpdatedAt != blk.updatedAt) return false;
    }
    return true;
  }

  List<ScheduleBlock> forDay(int weekday) {
    return state.maybeWhen(
      data: (blocks) => blocks.where((b) => b.weekday == weekday).toList()
        ..sort((a, b) => a.startMin.compareTo(b.startMin)),
      orElse: () => const [],
    );
  }

  ScheduleBlock? get currentClass {
    final now = DateTime.now();
    for (final b in forDay(now.weekday)) {
      if (b.isCurrentAt(now)) return b;
    }
    return null;
  }

  ScheduleBlock? get nextClass {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    for (final b in forDay(now.weekday)) {
      if (b.startMin > nowMin) return b;
    }
    return null;
  }

  /// uids a avisar por push cuando un adulto cambia el horario: el
  /// propio estudiante + el resto de padres/profesores (sin volver a
  /// avisarse a sí mismo — su propio cambio ya le queda en su
  /// campana al llamar a NotificationBus, capa 1 "siempre").
  Future<List<String>> _notifyTargets(String studentId, String? actorUid) async {
    final guardians = await NotificationBus.guardianTargets(studentId);
    return [
      studentId,
      ...guardians.where((uid) => uid != actorUid),
    ];
  }

  Future<void> createBlock({
    required int weekday,
    required int startMin,
    required int endMin,
    required String subject,
    bool isBreak = false,
    int? color,
  }) async {
    final scope = _scopeStudentId;
    if (scope == null) return;
    final user = _ref.read(authProvider);
    final studentName = _ref.read(activeStudentProvider)?.name ?? 'el estudiante';
    await _repo.createBlock(
      studentId: scope,
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
      subject: subject,
      isBreak: isBreak,
      color: color,
      assignedBy: user?.uid,
      assignedByRole: user?.role.name,
      assignedByName: user?.displayName,
    );
    await load();
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📅 Nueva clase en el horario',
      body: '"$subject" se agregó al horario de $studentName.',
      internalType: NotificationType.general,
      targetUids: await _notifyTargets(scope, user?.uid),
    );
  }

  Future<void> updateBlock(ScheduleBlock block) async {
    final user = _ref.read(authProvider);
    final studentName = _ref.read(activeStudentProvider)?.name ?? 'el estudiante';
    await _repo.updateBlock(block.copyWith(
      assignedBy: user?.uid,
      assignedByRole: user?.role.name,
      assignedByName: user?.displayName,
    ));
    await load();
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '📝 Horario actualizado',
      body: '"${block.subject}" fue modificada en el horario de $studentName.',
      internalType: NotificationType.general,
      targetUids: await _notifyTargets(block.studentId, user?.uid),
    );
  }

  Future<void> deleteBlock(ScheduleBlock block) async {
    final user = _ref.read(authProvider);
    final studentName = _ref.read(activeStudentProvider)?.name ?? 'el estudiante';
    final stamped = block.copyWith(
      isDeleted: true,
      assignedBy: user?.uid,
      assignedByRole: user?.role.name,
      assignedByName: user?.displayName,
    );
    await _repo.updateBlock(stamped);
    await load();
    await NotificationBus.dispatchFromProvider(
      ref: _ref,
      title: '🗑️ Clase eliminada',
      body: '"${block.subject}" se quitó del horario de $studentName.',
      internalType: NotificationType.general,
      targetUids: await _notifyTargets(block.studentId, user?.uid),
    );
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, AsyncValue<List<ScheduleBlock>>>(
        (ref) {
  final notifier = ScheduleNotifier(ref);
  ref.listen(activeStudentIdProvider, (_, _) => notifier.load());
  ref.listen(linkedStudentsProvider, (_, _) => notifier.load());
  ref.listen(authProvider, (_, _) => notifier.load());
  return notifier;
});
