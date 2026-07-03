import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:edutrack_family/core/data/local/models/schedule_block_model.dart';
import 'package:edutrack_family/core/data/local/repositories/schedule_repository.dart';
import 'package:edutrack_family/core/providers/auth_provider.dart';
import 'package:edutrack_family/core/providers/family_provider.dart';

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
    try {
      final blocks =
          scope == null ? <ScheduleBlock>[] : await _repo.getAll(scope);
      state = AsyncValue.data(blocks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
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
    await _repo.createBlock(
      studentId: scope,
      weekday: weekday,
      startMin: startMin,
      endMin: endMin,
      subject: subject,
      isBreak: isBreak,
      color: color,
    );
    await load();
  }

  Future<void> updateBlock(ScheduleBlock block) async {
    await _repo.updateBlock(block);
    await load();
  }

  Future<void> deleteBlock(ScheduleBlock block) async {
    await _repo.deleteBlock(block);
    await load();
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
